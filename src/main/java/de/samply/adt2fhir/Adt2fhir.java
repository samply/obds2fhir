package de.samply.adt2fhir;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.concurrent.TimeUnit;
import javax.xml.transform.*;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import net.sf.saxon.TransformerFactoryImpl;
import net.sf.saxon.s9api.Processor;
import org.apache.http.HttpResponse;
import org.apache.http.NoHttpResponseException;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.conn.ssl.NoopHostnameVerifier;
import org.apache.http.conn.ssl.SSLContextBuilder;
import org.apache.http.conn.ssl.TrustAllStrategy;
import org.apache.http.entity.FileEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;


public class Adt2fhir {

    private static final String INPUT_ADT="/InputADT/";
    private static final String ADT_PATIENTS="/tmp/ADT_Patients/";
    private static final String FHIR_PATIENTS="/tmp/FHIR_Patients/";
    private static final String ERRONEOUS="/tmp/erroneous";
    private static final String PROCESSED="/Processed/";

    private static final String ANSI_RESET = "\u001B[0m";
    private static final String ANSI_RED = "\u001B[31m";
    private static final String ANSI_GREEN = "\u001B[32m";
    private static final String DONE = ANSI_GREEN+"...done "+ANSI_RESET;

    public static void main(String[] args) {
        boolean pseudonymize = false;
        if (!System.getenv().getOrDefault("MAINZELLISTE_APIKEY","").isEmpty()){
            pseudonymize = checkConnections("Mainzelliste", System.getenv().getOrDefault("MAINZELLISTE_URL",""), Boolean.parseBoolean(System.getenv().getOrDefault("WAIT_FOR_CONNECTION","false")));
        } else {
            System.out.println("missing Mainzelliste Apikey - Skipping relevant processes");
        }
        boolean FHIRimport = checkConnections("Blaze FHIR Server", System.getenv().getOrDefault("STORE_PATH","") + "?_count=0", Boolean.parseBoolean(System.getenv().getOrDefault("WAIT_FOR_CONNECTION","false")));

        System.out.print("initialize transformers... ");
        final TransformerFactoryImpl factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);
        net.sf.saxon.Configuration saxonConfig = factory.getConfiguration();
        PatientPseudonymizer patientPseudonymizer = new PatientPseudonymizer();
        patientPseudonymizer.initialize(pseudonymize);
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(patientPseudonymizer);
        UniqueIdGenerator uniqueIdGenerator = new UniqueIdGenerator();
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(uniqueIdGenerator);

        Transformer ADT2singleADTtransformer = null;
        Transformer ADT2MDStransformer = null;
        Transformer MDS2FHIRtransformer = null;
        try {
            ADT2singleADTtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("toSinglePatients.xsl")));
            ADT2singleADTtransformer.setParameter("filepath", System.getenv().getOrDefault("FILE_PATH",""));
            ADT2MDStransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("ADT2MDS_FHIR.xsl")));
            ADT2MDStransformer.setParameter("add_department", System.getenv().getOrDefault("ADD_DEPARTMENTS",""));
            MDS2FHIRtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("MDS2FHIR.xsl")));
            MDS2FHIRtransformer.setParameter("filepath", System.getenv().getOrDefault("FILE_PATH",""));
            MDS2FHIRtransformer.setParameter("identifier_system", System.getenv().getOrDefault("IDENTIFIER_SYSTEM",""));
        } catch (TransformerConfigurationException e) {
            System.out.print("Transformer configuration error");
        }
        System.out.println(DONE);

        long startTime = System.nanoTime();
        System.out.println("Transforming to single Patients... \n");
        processXmlFiles(INPUT_ADT, ADT2singleADTtransformer);
        long stopTime = System.nanoTime();
        System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");


        startTime = System.nanoTime();
        System.out.println("Transforming to FHIR... \n");
        processXmlFiles(ADT_PATIENTS, ADT2MDStransformer, MDS2FHIRtransformer, true);
        stopTime = System.nanoTime();
        System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");

        if (FHIRimport){
            HttpPost httppost = new HttpPost(System.getenv().getOrDefault("STORE_PATH",""));
            RequestConfig requestConfig = RequestConfig.copy(RequestConfig.DEFAULT).build();
            httppost.setConfig(requestConfig);
            String encoding = Base64.getEncoder().encodeToString((System.getenv().getOrDefault("STORE_AUTH","")).getBytes());
            httppost.addHeader("content-type", "application/xml+fhir");
            httppost.addHeader("Authorization", "Basic " + encoding);

            startTime = System.nanoTime();
            System.out.println("posting fhir resources to blaze store...\n");
            processXmlFiles(FHIR_PATIENTS, null, httppost);
            stopTime = System.nanoTime();
            System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");
        }
    }


    public static void processXmlFiles (String inputData, Transformer transformer){
        processXmlFiles (inputData, transformer, null, false, null);
    }

    public static void processXmlFiles (String inputData, Transformer transformer, Transformer transformer2, Boolean transformWrittenResults){
        processXmlFiles (inputData, transformer, transformer2, transformWrittenResults, null);
    }

    public static void processXmlFiles (String inputData, Transformer transformer, HttpPost httppost){
        processXmlFiles (inputData, transformer, null, false, httppost);
    }
    public static void processXmlFiles (String inputData, Transformer transformer, Transformer transformer2, Boolean transformWrittenResults, HttpPost httppost ){
        //System.out.print("load "+ filetype + " files...");
        File fileDir = new File(System.getenv().getOrDefault("FILE_PATH","") + inputData);
        File[] listOfFiles = fileDir.listFiles();
        if (listOfFiles==null){
            System.out.println("ABORTING: empty "+ fileDir +" dir");
        }
        else {
            int counter=0;
            for (File inputFile : listOfFiles) {
                //System.out.println(inputFile);
                if (inputFile.isFile() & inputFile.getName().toLowerCase().endsWith(".xml")) {
                    counter+=1;
                    System.out.println("\u001B[AFile " + counter + " of " + (listOfFiles.length) + " / Filename: " + inputFile);
                    if (transformer ==null){
                        try {
                            postToFhirStore(inputFile, httppost);
                        } catch (IOException e) {
                            counter-=1;
                            System.out.print("ERROR - FHIR import: problem with file " + inputFile);
                            e.printStackTrace();
                        }
                    }
                    else {
                        //System.out.print("processing file " + inputFile.getName() + "...");
                        String inputFileString = null;
                        try {
                            inputFileString = Files.readString(Paths.get(String.valueOf(inputFile)));
                        } catch (IOException e) {
                            counter-=1;
                            System.out.print("ERROR - reading: problem with file " + inputFile);
                            e.printStackTrace();
                        }
                        try {
                            transformer.setParameter("customPrefix", counter);
                            String xmlResult = applyXslt(inputFileString, transformer);
                            if(transformWrittenResults){
                                transformer2.setParameter("customPrefix", inputFile.getName());
                                applyXslt(xmlResult, transformer2);
                                inputFile.delete();
                            }
                            else {
                                inputFile.renameTo(new File(System.getenv().getOrDefault("FILE_PATH","") + PROCESSED + inputFile.getName()));
                            }
                        } catch (UnsupportedEncodingException | TransformerException | RuntimeException e) {
                            counter-=1;
                            System.out.print("ERROR - transformation: problem with file " + inputFile);
                            //e.printStackTrace();
                        }
                    }
                }
                else if (inputFile.isFile() & inputFile.getName().toLowerCase().endsWith(".gitignore")) {
                    //do nothing
                }
                else {
                    System.out.print("\n\t\u001B[31m" + "skipping file:" + "\u001B[0m" + " '" + inputFile.getName() + "' - not a valid xml file");
                }
            }
        }
    }

    private static void postToFhirStore(File inputFile, HttpPost httppost) throws IOException {
        CloseableHttpClient httpclient = null;
        try {
            httpclient = getHttpClient(Boolean.parseBoolean(System.getenv().getOrDefault("SSL_CERTIFICATE_VALIDATION","")));
        } catch (NoSuchAlgorithmException | KeyStoreException | KeyManagementException e) {
            throw new RuntimeException(e);
        }
        File file = new File(inputFile.toString());
        FileEntity entity = new FileEntity(file);
        httppost.setEntity(entity);
        HttpResponse response = httpclient.execute(httppost);
        if (!response.getStatusLine().getReasonPhrase().equals("OK")) {
            System.out.println("Error - FHIR import: could not import file"+ inputFile.getName());
            System.out.println(EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8));
            inputFile.renameTo(new File(System.getenv().getOrDefault("FILE_PATH","") + ERRONEOUS));
        }
        else {
            inputFile.delete();
        }
        httpclient.close();
    }


    private static String applyXslt(String xmlString, Transformer transformer) throws UnsupportedEncodingException, TransformerException {
        Source xmlSource = new StreamSource(new ByteArrayInputStream(xmlString.getBytes(StandardCharsets.UTF_8.name())));
        Writer outputWriter = new StringWriter();
        StreamResult transformed = new StreamResult(outputWriter);
        transformer.transform(xmlSource, transformed);
        return outputWriter.toString();
    }

    private static CloseableHttpClient getHttpClient(Boolean sslVerification) throws NoSuchAlgorithmException, KeyStoreException, KeyManagementException {
        CloseableHttpClient httpclient = null;
        if (!sslVerification){//experimental feature, do not set ssl_certificate_validation=false
            httpclient = HttpClients.custom()
                    .setSSLContext(new SSLContextBuilder().loadTrustMaterial(null, TrustAllStrategy.INSTANCE).build())
                    .setSSLHostnameVerifier(NoopHostnameVerifier.INSTANCE).build();
        }
        else {
            httpclient = HttpClients.createDefault();
        }
        return httpclient;
    }

    private static boolean checkConnections(String servicename, String URL, boolean waitForConnection) {
        boolean serviceAvailable = false;
        CloseableHttpClient httpclient = null;
        try {
            httpclient = getHttpClient(Boolean.parseBoolean(System.getenv().getOrDefault("SSL_CERTIFICATE_VALIDATION","")));
        } catch (NoSuchAlgorithmException | KeyStoreException | KeyManagementException e) {
            throw new RuntimeException(e);
        }
        HttpResponse httpResponse;
        HttpGet httpGetRequest;
        if (URL != null && !URL.isEmpty()) {
            httpGetRequest = new HttpGet(URL);
            String encoding = Base64.getEncoder().encodeToString(System.getenv().getOrDefault("STORE_AUTH","").getBytes());
            httpGetRequest.addHeader("Authorization", "Basic " + encoding);
            try {
                httpResponse = httpclient.execute(httpGetRequest);
                if (httpResponse.getStatusLine().getReasonPhrase().equals("OK") || httpResponse.getStatusLine().getStatusCode()==200) {
                    System.out.println(servicename + " is accessible: " + URL);
                    serviceAvailable = true;
                }
                else {
                    if (waitForConnection){//if true, then recursively execute again
                        System.out.println("Waiting for service, trying again...");
                        checkConnections(servicename,URL,waitForConnection);
                    }
                    System.out.println(servicename + " is NOT accessible: " + URL + httpResponse.getStatusLine());
                }
                httpclient.close();
            } catch (IOException e) {
                System.out.println("Error: RuntimeException while trying to access " + servicename + " at " + URL + " - Skipping relevant processes");
                if (waitForConnection){//if true, then recursively execute again
                    System.out.println("Waiting for service, trying again...");
                    try {
                        TimeUnit.SECONDS.sleep(5);
                    } catch (InterruptedException ex) {
                        throw new RuntimeException(ex);
                    }
                    checkConnections(servicename,URL,waitForConnection);
                }
            }
        }
        else {
            System.out.println(servicename + " url not specified. Skipping relevant processes");
        }
        return serviceAvailable;
    }
}
