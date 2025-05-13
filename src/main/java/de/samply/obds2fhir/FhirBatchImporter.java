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

public class FhirBatchImporter {

    private static final Logger logger = LoggerFactory.getLogger(FhirBatchImporter.class);

    public static void importFile(File inputFile, HttpPost httpPost) throws IOException {
        try (CloseableHttpClient httpClient = Util.getHttpClient(Boolean.parseBoolean(System.getenv().getOrDefault("SSL_CERTIFICATE_VALIDATION","true")));) {
            importFile(inputFile, httpClient, httpPost);
        }
    }
    public static void importFile(File inputFile, CloseableHttpClient httpClient, HttpPost httpPost) throws IOException {
        httpPost.setEntity(new FileEntity(inputFile));
        HttpResponse response = httpClient.execute(httpPost);
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
        }
    }
}
