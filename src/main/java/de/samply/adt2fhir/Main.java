package de.samply.adt2fhir;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.io.UnsupportedEncodingException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.NoSuchElementException;
import java.util.Scanner;
import javax.xml.transform.Source;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;

import net.sf.saxon.TransformerFactoryImpl;

public class Main {

    public static void main(String[] args)
        throws IOException, TransformerException {

      String ADT2MDS ="ADT2MDS_FHIR.xsl";
      String MDS2FHIR = "MDS2FHIR.xsl";

      String ADTfile = null;
      /*if (0 < args.length) {
        String filename = args[0];
        ADTfile = new String(Files.readAllBytes(Paths.get(filename)));
      }*/


        Scanner scanner = new Scanner(System.in);
        try {
            while (true) {
                System.out.println("Please input an ADT/GEKID XML");
                long then = System.currentTimeMillis();
                ADTfile = new String(Files.readAllBytes(Paths.get(scanner.nextLine())), StandardCharsets.UTF_8);
                long now = System.currentTimeMillis();
                System.out.println("Transform to MDS");

                String MDS = importData(ADTfile, ADT2MDS);
                System.out.println("succesfully transformed to MDS");
                System.out.println("Transform to FHIR");
                //System.out.println(MDS);
                String FHIR =importData(MDS, MDS2FHIR);
                //System.out.println(FHIR);
                System.out.println("succesfully transformed to FHIR");
                System.out.println("FHIR bundle(s) stored in "+System.getProperty("user.dir"));
            }
        } catch(IllegalStateException | NoSuchElementException e) {
            // System.in has been closed
            System.out.println("System.in was closed; exiting");
        }
    }



    private static String importData(String xmlString, String transformation)
        throws UnsupportedEncodingException, TransformerException {

      InputStream xmlStream = new ByteArrayInputStream(xmlString.getBytes(StandardCharsets.UTF_8.name()));

      InputStream xsltStream = Main.class.getClassLoader().getResourceAsStream(transformation);

      String xslTransformation = applyXslt(xsltStream, xmlStream);

      return xslTransformation;
    }

    private static String applyXslt(InputStream xsltStream, InputStream xmlStream) throws TransformerException {

      Source xslt = new StreamSource(xsltStream);
      Writer outputWriter = new StringWriter();
      StreamResult transformed = new StreamResult(outputWriter);
      Source adtSource = new StreamSource(xmlStream);
      TransformerFactoryImpl factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);
      Transformer adtPrime = factory.newTransformer(xslt);
      adtPrime.transform(adtSource, transformed);
      String output = outputWriter.toString();
      return output;
    }

}
