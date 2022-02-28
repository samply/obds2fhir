package de.samply.adt2fhir;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import javax.xml.transform.*;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import net.sf.saxon.TransformerFactoryImpl;


public class Adt2fhir {

    private static final String INPUT_ADT="/InputADT";
    private static final String ADT_PATIENTS="/ADT_Patients";
    private static final String FHIR_PATIENTS="/FHIR_Patients";

    public static void main(String[] args) throws TransformerConfigurationException {
        System.out.print("initialize transformers... ");
        final TransformerFactoryImpl factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);

        final Transformer ADT2singleADTtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("toSinglePatients.xsl")));
        final Transformer ADT2MDStransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("ADT2MDS_FHIR.xsl")));
        final Transformer MDS2FHIRtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("MDS2FHIR.xsl")));
        System.out.println("...done");

        System.out.print("load configReader... ");
        ConfigReader configReader = new ConfigReader();
        try {
            configReader.init();
        } catch (IOException e) {
            System.out.println(" failed");
            e.printStackTrace();
        }
        System.out.println("...done");

        System.out.print("Transforming to single Patients... ");
        processXmlInput(INPUT_ADT, ADT2singleADTtransformer, "ADT", configReader);
        System.out.println("...done");
        System.out.print("Transforming to FHIR... ");
        processXmlInput(ADT_PATIENTS, ADT2MDStransformer, "singleADT", configReader, MDS2FHIRtransformer, true);
        System.out.println("...done");
        //System.out.println("deleting temp file: " + singleADTFile.getAbsolutePath());
        //singleADTFile.deleteOnExit();
    }


    private static void processXmlInput (String inputData, Transformer transformer, String filetype, ConfigReader configReader){
        processXmlInput (inputData, transformer, filetype, configReader, null, false);
    }

    private static void processXmlInput (String inputData, Transformer transformer, String filetype, ConfigReader configReader, Transformer transformer2, Boolean transformWrittenResults){
        //System.out.print("load "+ filetype + " files...");
        File fileFolder = new File(configReader.getFile_path() + inputData);
        File[] listOfFiles = fileFolder.listFiles();
        if (listOfFiles==null){
            System.out.println(" ABORTING: empty 'InputADT' folder");
        }
        else {
            for (File inputFile : listOfFiles) {
                if (inputFile.isFile() & inputFile.getName().toLowerCase().endsWith(".xml")) {
                    //System.out.print("processing file " + inputFile.getName() + "...");
                    String combinedADTfile = null;
                    try {
                        combinedADTfile = new String(Files.readAllBytes(Paths.get(String.valueOf(inputFile))), StandardCharsets.UTF_8);
                    } catch (IOException e) {
                        System.out.print("ERROR: problem with file " + inputFile);
                        e.printStackTrace();
                    }
                    try {
                        String xmlResult = applyXslt(combinedADTfile, transformer);
                        if(transformWrittenResults){
                            applyXslt(xmlResult, transformer2);
                            inputFile.deleteOnExit();
                        }
                    } catch (TransformerException | UnsupportedEncodingException e) {
                        System.out.print("ERROR: problem with file " + inputFile);
                        e.printStackTrace();
                    }
                }
                else {
                    System.out.print("\n\t\u001B[31m" + "skipping file:" + "\u001B[0m" + " '" + inputFile.getName() + "' - not a valid ADT/GEKID.xml");
                }
            }
        }
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
