package de.samply.obds2fhir;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.FileEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.util.EntityUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class FhirBatchImporter {

    private static final Logger logger = LoggerFactory.getLogger(FhirBatchImporter.class);
    private static final Pattern PATIENT_ID = Pattern.compile("^FHIR_Patient_([^_]+)_");

    public static void importFiles(File directory, HttpPost httpPost) {
        File[] files = directory.listFiles((dir, name) -> name.toLowerCase().endsWith(".xml"));
        if (files == null) {
            logger.warn("ABORTING: empty " + directory + " dir");
            return;
        }
        Arrays.sort(files);
        // Files of the same patient are imported one after another and in order,
        // so a later report still overwrites an earlier one
        Map<String, List<File>> filesByPatient = new LinkedHashMap<>();
        for (File file : files) {
            Matcher matcher = PATIENT_ID.matcher(file.getName());
            String patientId = matcher.find() ? matcher.group(1) : file.getName();
            filesByPatient.computeIfAbsent(patientId, id -> new ArrayList<>()).add(file);
        }
        try (CloseableHttpClient httpClient = Util.getHttpClient(Boolean.parseBoolean(System.getenv().getOrDefault("SSL_CERTIFICATE_VALIDATION","true")))) {
            AtomicInteger counter = new AtomicInteger();
            ExecutorService executor = Executors.newFixedThreadPool(Util.MAX_CONNECTIONS);
            for (List<File> patientFiles : filesByPatient.values()) {
                executor.execute(() -> {
                    for (File file : patientFiles) {
                        logger.info("File " + counter.incrementAndGet() + " of " + files.length + " / Filename: " + file);
                        importFileOrMoveToErroneous(file, httpClient, httpPost);
                    }
                });
            }
            executor.shutdown();
            try {
                executor.awaitTermination(Long.MAX_VALUE, TimeUnit.NANOSECONDS);
            } catch (InterruptedException e) {
                executor.shutdownNow();
                Thread.currentThread().interrupt();
            }
        } catch (IOException e) {
            logger.error("IOException while closing the HTTP client " + e);
        }
    }

    private static void importFileOrMoveToErroneous(File inputFile, CloseableHttpClient httpClient, HttpPost httpPost) {
        try {
            importFile(inputFile, httpClient, httpPost);
        } catch (IOException | RuntimeException e) {
            inputFile.renameTo(new File(System.getenv().getOrDefault("FILE_PATH","") + Obds2fhir.ERRONEOUS + inputFile.getName()));
            logger.error(e.getClass().getSimpleName() + " with file " + inputFile + e);
        }
    }

    public static void importFile(File inputFile, CloseableHttpClient httpClient, HttpPost httpPost) throws IOException {
        // A request of our own, as the given one is shared between threads
        HttpPost request = new HttpPost(httpPost.getURI());
        request.setHeaders(httpPost.getAllHeaders());
        request.setConfig(httpPost.getConfig());
        request.setEntity(new FileEntity(inputFile));
        HttpResponse response = httpClient.execute(request);
        int statusCode = response.getStatusLine().getStatusCode();
        String responseBody = EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8);

        boolean hasCriticalErrors = statusCode != 200 && statusCode != 201;;
        if (!hasCriticalErrors) {
            JsonNode root = new ObjectMapper().readTree(responseBody);
            int index = 0;
            for (JsonNode entry : root.path("entry")) {
                String status = entry.path("response").path("status").asText();
                if (!(status.startsWith("200") || status.startsWith("201") || status.startsWith("412"))) {
                    hasCriticalErrors = true;
                    String diagnostics = entry.path("response").path("outcome").path("issue").get(0).path("diagnostics").asText();
                    logger.error("Error in entry[" + index + "]: " + status + " — " + diagnostics);
                }
                index++;
            }
        }
        if (hasCriticalErrors) {
            logger.error("FHIR import: could not import file"+ inputFile.getName());
            logger.error(responseBody+"\n");
            inputFile.renameTo(new File(System.getenv().getOrDefault("FILE_PATH","") + Obds2fhir.ERRONEOUS + inputFile.getName()));
        } else {
            logger.debug("Import successful for: " + inputFile.getName());
            inputFile.delete();
        }
    }
}
