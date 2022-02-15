package de.samply.adt2fhir;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import javax.xml.transform.*;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import net.sf.saxon.TransformerFactoryImpl;


public class Main {


    private static final String INPUT_ADT="/InputADT";
    private static final String ADT_PATIENTS="/ADT_Patients";
    private static final String FHIR_PATIENTS="/FHIR_Patients";

    public static void main(String[] args)
        throws IOException, TransformerException {

        final TransformerFactoryImpl factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);

        final Transformer ADT2singleADTtransformer = factory.newTransformer(new StreamSource(Main.class.getClassLoader().getResourceAsStream("toSinglePatients.xsl")));
        final Transformer ADT2MDStransformer = factory.newTransformer(new StreamSource(Main.class.getClassLoader().getResourceAsStream("ADT2MDS_FHIR.xsl")));
        final Transformer MDS2FHIRtransformer = factory.newTransformer(new StreamSource(Main.class.getClassLoader().getResourceAsStream("MDS2FHIR.xsl")));

        ConfigReader configReader = new ConfigReader();
        configReader.init();
        File inputADTFolder = new File(configReader.getFile_path()+INPUT_ADT);
        File[] listOfInputADTFiles = inputADTFolder.listFiles();
        for (File inputADTFile : listOfInputADTFiles) {
            if (inputADTFile.isFile() & inputADTFile.getName().toLowerCase().endsWith(".xml") ) {
                System.out.println("processing file " + inputADTFile.toString());
                String combinedADTfile = new String(Files.readAllBytes(Paths.get(String.valueOf(inputADTFile))), StandardCharsets.UTF_8);

                applyXslt(combinedADTfile, ADT2singleADTtransformer);
                System.out.println("succesfully splitted ADT to single patients");

                System.out.println("loading single patients");
                File singleADTFolder = new File(configReader.getFile_path()+ADT_PATIENTS);
                File[] listOfSingleADTFiles = singleADTFolder.listFiles();
                for (File singleADTFile : listOfSingleADTFiles) {
                    System.out.println("processing file " + singleADTFile.toString());
                    String singleADTPatient = new String(Files.readAllBytes(Paths.get(String.valueOf(singleADTFile))), StandardCharsets.UTF_8);
                    System.out.println("transforming single patients to MDS");
                    String MDSPatient = applyXslt(singleADTPatient, ADT2MDStransformer);
                    System.out.println("succesfully transformed to MDS");
                    System.out.println("Transform to FHIR");
                    applyXslt(MDSPatient, MDS2FHIRtransformer);
                    System.out.println("succesfully transformed to FHIR");
                    System.out.println("FHIR bundle(s) stored in " + configReader.getFile_path()+FHIR_PATIENTS);

                    System.out.println("deleting temp file: " + singleADTFile.getAbsolutePath());
                    singleADTFile.deleteOnExit();

                }
            }
        }
    }



    private static String applyXslt(String xmlString, Transformer adtPrime) throws TransformerException, FileNotFoundException, UnsupportedEncodingException {

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
