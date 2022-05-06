package de.samply.adt2fhir;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Base64;
import javax.xml.transform.*;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import net.sf.saxon.TransformerFactoryImpl;
import net.sf.saxon.s9api.Processor;
import org.apache.http.HttpHeaders;
import org.apache.http.HttpResponse;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.FileEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;


public class Adt2fhir {

    private static final String INPUT_ADT="/InputADT";
    private static final String ADT_PATIENTS="/ADT_Patients";
    private static final String FHIR_PATIENTS="/FHIR_Patients";

    public static final String ANSI_RESET = "\u001B[0m";
    public static final String ANSI_RED = "\u001B[31m";
    public static final String ANSI_GREEN = "\u001B[32m";

    public static void main(String[] args) throws TransformerConfigurationException, IOException {
        System.out.print("load configuration... ");
        ConfigReader configReader = new ConfigReader();
        try {
            configReader.init();
        } catch (IOException e) {
            System.out.println(" failed");
            e.printStackTrace();
        }
        System.out.println(ANSI_GREEN+"...done"+ANSI_RESET);

        System.out.print("initialize transformers... ");
        final TransformerFactoryImpl factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);
        net.sf.saxon.Configuration saxonConfig = factory.getConfiguration();
        PatientPseudonymizer patientPseudonymizer = new PatientPseudonymizer();
        patientPseudonymizer.initialize(configReader);
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(patientPseudonymizer);
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(new UniqueIdGenerator());

        final Transformer ADT2singleADTtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("toSinglePatients.xsl")));
        ADT2singleADTtransformer.setParameter("filepath", configReader.getFile_path());
        final Transformer ADT2MDStransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("ADT2MDS_FHIR.xsl")));
        final Transformer MDS2FHIRtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("MDS2FHIR.xsl")));
        MDS2FHIRtransformer.setParameter("filepath", configReader.getFile_path());
        MDS2FHIRtransformer.setParameter("identifier_system", configReader.getIdentifier_system());
        System.out.println(ANSI_GREEN+"...done"+ANSI_RESET);

        long startTime = System.nanoTime();
        System.out.println("Transforming to single Patients... \n");
        processXmlFiles(INPUT_ADT, ADT2singleADTtransformer, configReader);
        long stopTime = System.nanoTime();
        System.out.println(ANSI_GREEN+"...done "+ANSI_RESET+(stopTime - startTime)/1000000000+ " seconds");


        startTime = System.nanoTime();
        System.out.println("Transforming to FHIR... \n");
        processXmlFiles(ADT_PATIENTS, ADT2MDStransformer, configReader, MDS2FHIRtransformer, true);
        stopTime = System.nanoTime();
        System.out.println(ANSI_GREEN+"...done "+ANSI_RESET+(stopTime - startTime)/1000000000+ " seconds");

        HttpPost httppost = new HttpPost(configReader.getStore_path());
        RequestConfig requestConfig = RequestConfig.copy(RequestConfig.DEFAULT).build();
        httppost.setConfig(requestConfig);
        httppost.addHeader("content-type", "application/xml+fhir");

        startTime = System.nanoTime();
        System.out.println("posting fhir resources to blaze store...\n");
        processXmlFiles(FHIR_PATIENTS, null, configReader, httppost);
        stopTime = System.nanoTime();
        System.out.println(ANSI_GREEN+"...done "+ANSI_RESET+(stopTime - startTime)/1000000000+ " seconds");

    }


    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader){
        processXmlFiles (inputData, transformer, configReader, null, false, null);
    }

    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader, Transformer transformer2, Boolean transformWrittenResults){
        processXmlFiles (inputData, transformer, configReader, transformer2, transformWrittenResults, null);
    }

    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader, HttpPost httppost){
        processXmlFiles (inputData, transformer, configReader, null, false, httppost);
    }
    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader, Transformer transformer2, Boolean transformWrittenResults, HttpPost httppost ){
        //System.out.print("load "+ filetype + " files...");
        File fileDir = new File(configReader.getFile_path() + inputData);
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
                    System.out.println("\u001B[AFile "+counter+" of "+(listOfFiles.length-1));
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
                        String inputXml = null;
                        try {
                            inputXml = new String(Files.readAllBytes(Paths.get(String.valueOf(inputFile))), StandardCharsets.UTF_8);
                        } catch (IOException e) {
                            counter-=1;
                            System.out.print("ERROR - reading: problem with file " + inputFile);
                            e.printStackTrace();
                        }
                        try {
                            transformer.setParameter("customPrefix", counter);
                            String xmlResult = applyXslt(inputXml, transformer);
                            if(transformWrittenResults){
                                transformer2.setParameter("customPrefix", inputFile.getName());
                                applyXslt(xmlResult, transformer2);
                                inputFile.deleteOnExit();
                            }
                        } catch (UnsupportedEncodingException | TransformerException | RuntimeException e) {
                            counter-=1;
                            System.out.print("ERROR - transformation: problem with file " + inputFile);
                            //e.printStackTrace();
                        }
                    }
                }
                else if (inputFile.isFile() & inputFile.getName().toLowerCase().endsWith(".gitignore")) {}
                else {
                    System.out.print("\n\t\u001B[31m" + "skipping file:" + "\u001B[0m" + " '" + inputFile.getName() + "' - not a valid xml file");
                }
            }
        }
    }

    private static void postToFhirStore(File inputFile, HttpPost httppost) throws IOException {
        CloseableHttpClient httpclient = HttpClients.createDefault();
        File file = new File(inputFile.toString());

        FileEntity entity = new FileEntity(file);

        httppost.setEntity(entity);

        //System.out.println("executing request " + httppost.getRequestLine() + httppost.getConfig());
        HttpResponse response = httpclient.execute(httppost);
        //HttpEntity resEntity = response.getEntity();

        //System.out.println(response.getStatusLine());
        if (!response.getStatusLine().getReasonPhrase().equals("OK")) {;
            System.out.println("Error - FHIR import: could not import file"+ inputFile.getName());
        }
        else {
            inputFile.deleteOnExit();
        }

        httpclient.close();

        /*
        final Client client = ClientBuilder.newBuilder().register(MultiPartFeature.class).build();
        WebTarget target = client.target("http://localhost:8080/resource/mydoc");

        Response response = target.request().post(Entity.xml(inputFile));
         */
    }


    private static String applyXslt(String xmlString, Transformer transformer) throws UnsupportedEncodingException, TransformerException {
        Source xmlSource = new StreamSource(new ByteArrayInputStream(xmlString.getBytes(StandardCharsets.UTF_8.name())));
        Writer outputWriter = new StringWriter();
        StreamResult transformed = new StreamResult(outputWriter);
        transformer.transform(xmlSource, transformed);
        String output = outputWriter.toString();
            return output;
    }

}
