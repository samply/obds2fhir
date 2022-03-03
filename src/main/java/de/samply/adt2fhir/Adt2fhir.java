package de.samply.adt2fhir;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
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
import org.apache.http.impl.client.HttpClients;


public class Adt2fhir {

    private static final String INPUT_ADT="/InputADT";
    private static final String ADT_PATIENTS="/ADT_Patients";
    private static final String FHIR_PATIENTS="/FHIR_Patients";

    public static void main(String[] args) throws TransformerConfigurationException {
        System.out.print("load configReader... ");
        ConfigReader configReader = new ConfigReader();
        try {
            configReader.init();
        } catch (IOException e) {
            System.out.println(" failed");
            e.printStackTrace();
        }
        System.out.println("...done");

        System.out.print("initialize transformers... ");
        final TransformerFactoryImpl factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);
        net.sf.saxon.Configuration saxonConfig = factory.getConfiguration();
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(new PatientPseudonymizer());
        final Transformer ADT2singleADTtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("toSinglePatients.xsl")));
        ADT2singleADTtransformer.setParameter("filepath", configReader.getFile_path());
        final Transformer ADT2MDStransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("ADT2MDS_FHIR.xsl")));
        final Transformer MDS2FHIRtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("MDS2FHIR.xsl")));
        MDS2FHIRtransformer.setParameter("filepath", configReader.getFile_path());
        System.out.println("...done");


        System.out.print("Transforming to single Patients... ");
        processXmlFiles(INPUT_ADT, ADT2singleADTtransformer, configReader);
        System.out.println("...done");

        System.out.print("Transforming to FHIR... ");
        processXmlFiles(ADT_PATIENTS, ADT2MDStransformer, configReader, MDS2FHIRtransformer, true);
        System.out.println("...done");

        System.out.print("posting fhir resources to blaze store...");
        processXmlFiles(FHIR_PATIENTS, null, configReader);
        System.out.println("...done");
    }


    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader){
        processXmlFiles (inputData, transformer, configReader, null, false);
    }

    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader, Transformer transformer2, Boolean transformWrittenResults){
        //System.out.print("load "+ filetype + " files...");
        File fileFolder = new File(configReader.getFile_path() + inputData);
        File[] listOfFiles = fileFolder.listFiles();
        if (listOfFiles==null){
            System.out.println("ABORTING: empty 'InputADT' folder");
        }
        else {
            for (File inputFile : listOfFiles) {
                if (inputFile.isFile() & inputFile.getName().toLowerCase().endsWith(".xml")) {
                    if (transformer ==null){
                        try {
                            postToFhirStore(inputFile, configReader);
                        } catch (IOException e) {
                            System.out.print("ERROR - FHIR import: problem with file " + inputFile);
                            e.printStackTrace();
                        }
                    }
                    else {
                        //System.out.print("processing file " + inputFile.getName() + "...");
                        String combinedADTfile = null;
                        try {
                            combinedADTfile = new String(Files.readAllBytes(Paths.get(String.valueOf(inputFile))), StandardCharsets.UTF_8);
                        } catch (IOException e) {
                            System.out.print("ERROR - reading: problem with file " + inputFile);
                            e.printStackTrace();
                        }
                        try {
                            String xmlResult = applyXslt(combinedADTfile, transformer);
                            if(transformWrittenResults){
                                applyXslt(xmlResult, transformer2);
                                inputFile.deleteOnExit();
                            }
                        } catch (TransformerException | UnsupportedEncodingException e) {
                            System.out.print("ERROR - transformation: problem with file " + inputFile);
                            e.printStackTrace();
                        }
                    }
                }
                else {
                    System.out.print("\n\t\u001B[31m" + "skipping file:" + "\u001B[0m" + " '" + inputFile.getName() + "' - not a valid xml file");
                }
            }
        }
    }

    private static void postToFhirStore(File inputFile, ConfigReader configReader) throws IOException {
        CloseableHttpClient httpclient = HttpClients.createDefault();
        HttpPost httppost = new HttpPost(configReader.getStore_path());

        RequestConfig requestConfig = RequestConfig.copy(RequestConfig.DEFAULT)
                //.setProxy(new HttpHost("XXX.XXX.XXX.XXX", 8080))
                .build();
        httppost.setConfig(requestConfig);

        httppost.addHeader("content-type", "application/xml+fhir");

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


    private static String applyXslt(String xmlString, Transformer adtPrime) throws TransformerException, UnsupportedEncodingException {
            Source xmlSource = new StreamSource(new ByteArrayInputStream(xmlString.getBytes(StandardCharsets.UTF_8.name())));
            Writer outputWriter = new StringWriter();
            StreamResult transformed = new StreamResult(outputWriter);

            /*ZipOutputStream zipOut = new ZipOutputStream(new FileOutputStream("file.zip"));
            factory.setAttribute("http://saxon.sf.net/feature/outputURIResolver", new ZipOutputURIReslover(zipOut))
            MemoryOutputURIResolver mem=new MemoryOutputURIResolver();*/
            /*factory.setAttribute("http://saxon.sf.net/feature/outputURIResolver", mem);
            factory.setAttribute("http://saxon.sf.net/feature/allow-external-functions", new Boolean(true));*/
            adtPrime.transform(xmlSource, transformed);
            String output = outputWriter.toString();

            return output;
    }

}
