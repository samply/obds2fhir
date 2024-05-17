package de.samply.obds2fhir;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.Base64;
import javax.xml.transform.*;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import net.sf.saxon.TransformerFactoryImpl;
import net.sf.saxon.s9api.Processor;
import org.apache.http.HttpResponse;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.FileEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.util.EntityUtils;


public class Obds2fhir {
    private static final String INPUT_DATA ="/InputData/";
    private static final String oBDS_PATIENTS ="/tmp/oBDS_Patients/";
    private static final String ADT_PATIENTS ="/tmp/ADT_Patients/";
    private static final String FHIR_PATIENTS="/tmp/FHIR_Patients/";
    private static final String ERRONEOUS="/tmp/erroneous";
    private static final String PROCESSED="/Processed/";

    private static final String ANSI_RESET = "\u001B[0m";
    private static final String ANSI_RED = "\u001B[31m";
    private static final String ANSI_GREEN = "\u001B[32m";
    private static final String DONE = ANSI_GREEN+"...done "+ANSI_RESET;
    private static TransformerFactoryImpl factory = null;
    public static Transformer oBDS2SinglePatientTransformer = null;
    public static Transformer ADT2SinglePatientTransformer = null;
    public static Transformer oBDS2MDSTransformer = null;
    public static Transformer ADT2MDSTransformer = null;
    public static Transformer MDS2FHIRTransformer = null;

    public static void main(String[] args) {
        boolean pseudonymizeFlag = false;
        if (!System.getenv().getOrDefault("MAINZELLISTE_APIKEY","").isEmpty()){
            pseudonymizeFlag = Util.checkConnections("Mainzelliste", System.getenv().getOrDefault("MAINZELLISTE_URL",""), Boolean.parseBoolean(System.getenv().getOrDefault("WAIT_FOR_CONNECTION","false")));
        } else {
            System.out.println("missing Mainzelliste Apikey - Skipping relevant processes");
        }
        boolean importFhirFlag = Util.checkConnections("Blaze FHIR Server", System.getenv().getOrDefault("STORE_PATH","") + "?_count=0", Boolean.parseBoolean(System.getenv().getOrDefault("WAIT_FOR_CONNECTION","false")));

        initializeTransformers(pseudonymizeFlag);

        long startTime = System.nanoTime();
        System.out.println("Transforming to single Patients... \n");
        processXmlFiles(INPUT_DATA,1);
        long stopTime = System.nanoTime();
        System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");

        startTime = System.nanoTime();
        System.out.println("Transforming to FHIR... \n");
        processXmlFiles(oBDS_PATIENTS, 2);
        processXmlFiles(ADT_PATIENTS, 2);
        stopTime = System.nanoTime();
        System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");

        if (importFhirFlag){
            HttpPost httppost = new HttpPost(System.getenv().getOrDefault("STORE_PATH",""));
            RequestConfig requestConfig = RequestConfig.copy(RequestConfig.DEFAULT).build();
            httppost.setConfig(requestConfig);
            String encoding = Base64.getEncoder().encodeToString((System.getenv().getOrDefault("STORE_AUTH","")).getBytes());
            httppost.addHeader("content-type", "application/xml+fhir");
            httppost.addHeader("Authorization", "Basic " + encoding);

            startTime = System.nanoTime();
            System.out.println("posting fhir resources to blaze store...\n");
            processXmlFiles(FHIR_PATIENTS, httppost,3);
            stopTime = System.nanoTime();
            System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");
        }
    }


    public static void processXmlFiles(String inputData, int step){
        processXmlFiles (inputData, null,step);
    }

    public static void processXmlFiles(String inputDir, HttpPost httppost, int step){
        //System.out.print("load "+ filetype + " files...");
        File absoluteInputDir = new File(System.getenv().getOrDefault("FILE_PATH","") + inputDir);
        File[] listOfFiles = absoluteInputDir.listFiles();
        if (listOfFiles==null){
            System.out.println("ABORTING: empty "+ absoluteInputDir +" dir");
        }
        else {
            int counter=0;
            Arrays.sort(listOfFiles);
            for (File inputFile : listOfFiles) {
                //System.out.println(inputFile);
                if (inputFile.isFile() & inputFile.getName().toLowerCase().endsWith(".xml")) {
                    counter+=1;
                    System.out.println("\u001B[AFile " + counter + " of " + (listOfFiles.length) + " / Filename: " + inputFile);
                    try {
                        String inputFileString = Files.readString(Paths.get(String.valueOf(inputFile)));
                        if (step==1){
                            Transformer transformer = identifyTransformer(inputFileString);
                            transformer.setParameter("customPrefix", counter);
                            applyXslt(inputFileString, transformer);
                            inputFile.renameTo(new File(System.getenv().getOrDefault("FILE_PATH","/obds2fhir/clinical_data") + PROCESSED + inputFile.getName()));
                        } else if (step==2){
                            Transformer transformer= inputDir.equals(oBDS_PATIENTS) ? oBDS2MDSTransformer : ADT2MDSTransformer;
                            transformer.setParameter("customPrefix", counter);
                            String xmlResult = applyXslt(inputFileString, transformer);
                            MDS2FHIRTransformer.setParameter("customPrefix", inputFile.getName());
                            applyXslt(xmlResult, MDS2FHIRTransformer);
                            inputFile.delete();
                        } else if (step==3){
                            postToFhirStore(inputFile, httppost);
                        }
                        else {
                            inputFile.renameTo(new File(System.getenv().getOrDefault("FILE_PATH","") + PROCESSED + inputFile.getName()));
                        }
                    } catch (IOException e) {
                        counter-=1;
                        System.out.print("ERROR - IOException with file " + inputFile);
                        e.printStackTrace();
                    } catch (TransformerException e) {
                        counter-=1;
                        System.out.print("ERROR - TransformerException with file " + inputFile+"\n\n"+inputDir+"\n"+oBDS_PATIENTS+"\n");
                        e.printStackTrace();
                    } catch (RuntimeException e) {
                        counter-=1;
                        System.out.print("ERROR - RuntimeException with file " + inputFile);
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

    private static Transformer identifyTransformer(String file) {
        int fileVersion = Util.getFileVersion(file);
        return fileVersion==3 ? oBDS2SinglePatientTransformer : ADT2SinglePatientTransformer;
    }


    private static void postToFhirStore(File inputFile, HttpPost httppost) throws IOException {
        CloseableHttpClient httpclient = null;
        httpclient = Util.getHttpClient(Boolean.parseBoolean(System.getenv().getOrDefault("SSL_CERTIFICATE_VALIDATION","")));
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

    public static void initializeTransformers(boolean pseudonymizeFlag) {
        System.out.print("initialize transformers... ");
        factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);
        net.sf.saxon.Configuration saxonConfig = factory.getConfiguration();
        PatientPseudonymizer patientPseudonymizer = new PatientPseudonymizer();
        patientPseudonymizer.initialize(pseudonymizeFlag);
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(patientPseudonymizer);
        UniqueIdGenerator uniqueIdGenerator = new UniqueIdGenerator();
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(uniqueIdGenerator);
        try {
            oBDS2SinglePatientTransformer = factory.newTransformer(new StreamSource(Obds2fhir.class.getClassLoader().getResourceAsStream("oBDS2SinglePatient.xsl")));
            oBDS2SinglePatientTransformer.setParameter("filepath", System.getenv().getOrDefault("FILE_PATH",""));
            ADT2SinglePatientTransformer = factory.newTransformer(new StreamSource(Obds2fhir.class.getClassLoader().getResourceAsStream("ADT2SinglePatient.xsl")));
            ADT2SinglePatientTransformer.setParameter("filepath", System.getenv().getOrDefault("FILE_PATH",""));
            oBDS2MDSTransformer = factory.newTransformer(new StreamSource(Obds2fhir.class.getClassLoader().getResourceAsStream("oBDS2MDS_FHIR.xsl")));
            oBDS2MDSTransformer.setParameter("add_department", System.getenv().getOrDefault("ADD_DEPARTMENTS","false"));
            oBDS2MDSTransformer.setParameter("keep_internal_id", System.getenv().getOrDefault("KEEP_INTERNAL_ID","false"));
            ADT2MDSTransformer = factory.newTransformer(new StreamSource(Obds2fhir.class.getClassLoader().getResourceAsStream("ADT2MDS_FHIR.xsl")));
            ADT2MDSTransformer.setParameter("add_department", System.getenv().getOrDefault("ADD_DEPARTMENTS","false"));
            ADT2MDSTransformer.setParameter("keep_internal_id", System.getenv().getOrDefault("KEEP_INTERNAL_ID","false"));
            MDS2FHIRTransformer = factory.newTransformer(new StreamSource(Obds2fhir.class.getClassLoader().getResourceAsStream("MDS2FHIR.xsl")));
            MDS2FHIRTransformer.setParameter("filepath", System.getenv().getOrDefault("FILE_PATH",""));
            MDS2FHIRTransformer.setParameter("identifier_system", System.getenv().getOrDefault("IDENTIFIER_SYSTEM","http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS"));
        } catch (TransformerConfigurationException e) {
            System.out.print("Transformer configuration error");
        }
        System.out.println(DONE);
    }
}
