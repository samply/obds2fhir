package de.samply.obds2fhir;

import net.sf.saxon.TransformerFactoryImpl;
import net.sf.saxon.s9api.Processor;
import org.apache.commons.codec.digest.DigestUtils;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import uk.org.webcompere.systemstubs.environment.EnvironmentVariables;
import uk.org.webcompere.systemstubs.jupiter.SystemStub;
import uk.org.webcompere.systemstubs.jupiter.SystemStubsExtension;

import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerConfigurationException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.stream.StreamSource;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import static de.samply.obds2fhir.Obds2fhir.processXmlFiles;
import static org.junit.jupiter.api.Assertions.assertTrue;

@ExtendWith(SystemStubsExtension.class)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
public class Obds2fhirTests {


    String pathWithFile=this.getClass().getClassLoader().getResource("clinical_data/InputADT/File-1-ADT2_Testpatient.xml").getPath();
    @SystemStub
    private EnvironmentVariables environmentVariables =
            new EnvironmentVariables("FILE_PATH", pathWithFile.substring(0, pathWithFile.indexOf("InputADT")));

    @Test
    @Order(1)
    public void applyTransformation(){
        final TransformerFactoryImpl factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);
        net.sf.saxon.Configuration saxonConfig = factory.getConfiguration();
        PatientPseudonymizer patientPseudonymizer = new PatientPseudonymizer();
        patientPseudonymizer.initialize(false);
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(patientPseudonymizer);
        UniqueIdGenerator uniqueIdGenerator = new UniqueIdGenerator();
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(uniqueIdGenerator);

        Transformer ADT2SinglePatientTransformer = null;
        Transformer ADT2MDStransformer = null;
        Transformer MDS2FHIRtransformer = null;
        try {
            ADT2SinglePatientTransformer = factory.newTransformer(new StreamSource(Obds2fhir.class.getClassLoader().getResourceAsStream("ADT2SinglePatient.xsl")));
            ADT2SinglePatientTransformer.setParameter("filepath", System.getenv("FILE_PATH"));
            ADT2MDStransformer = factory.newTransformer(new StreamSource(Obds2fhir.class.getClassLoader().getResourceAsStream("ADT2MDS_FHIR.xsl")));
            ADT2MDStransformer.setParameter("add_department", false);//TODO test departments
            MDS2FHIRtransformer = factory.newTransformer(new StreamSource(Obds2fhir.class.getClassLoader().getResourceAsStream("MDS2FHIR.xsl")));
            MDS2FHIRtransformer.setParameter("filepath", System.getenv("FILE_PATH"));
            MDS2FHIRtransformer.setParameter("identifier_system", "http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS");
        } catch (TransformerConfigurationException e) {
            System.out.print("Transformer configuration error");
        }
        processXmlFiles("InputADT", ADT2SinglePatientTransformer);
        processXmlFiles("tmp/ADT_Patients", ADT2MDStransformer, MDS2FHIRtransformer, true);
        assertTrue(new File(System.getenv("FILE_PATH")).exists());
    }

    @Test
    @Order(2)
    public void comparePatient () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient1"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_Patient_"+filename+"_1.xml";
        String expected = "FHIR_ADT2_ExpectedPatient.xml";
        assertTrue(compare(result, expected));
    }
    @Test
    @Order(3)
    public void compareErrorPatient () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient2"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_Patient_"+filename+"_2.xml";
        String expected = "FHIR_ADT2_ExpectedPatientMissingDate.xml";
        assertTrue(compare(result, expected));
    }

    @Test
    @Order(4)
    public void compareBatch () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient1"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_batch_Patient_"+filename+"_1.xml";
        String expected = "FHIR_batch_ADT2_ExpectedPatient.xml";
        assertTrue(compare(result, expected));
    }
    private Boolean compare(String resultvar, String expectedvar) throws IOException {
        String result = System.getenv("FILE_PATH")+resultvar;
        String expected = this.getClass().getClassLoader().getResource(expectedvar).getPath();
        String resultString = Files.readString(Paths.get(String.valueOf(new File(result))));
        String expectedString = Files.readString(Paths.get(String.valueOf(new File(expected))));
        resultString=replaceAllIds(resultString);
        expectedString=replaceAllIds(expectedString);
        return (resultString.equals(expectedString));
    }

    private String replaceAllIds(String bundle){
        //repalce ids
        String result = bundle.replaceAll("([/\"])([a-z0-9]{16,21}[-0-9]{0,2})(\")","$1repalced-id$3");
        //replace pseudonym
        result = result.replaceAll("(<value value=\")(.{1,32})\"","$1repalced-pseudonym\"");
        //replace separator
        result = result.replaceAll("\r","");
        //replace artefacts
        result = result.replaceAll("<id value=\"tpatient.xml\"/>","<id value=\"repalced-id\"/>");
        return result;
    }
}
