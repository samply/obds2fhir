package de.samply.obds2fhir;

import org.apache.commons.codec.digest.DigestUtils;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import uk.org.webcompere.systemstubs.environment.EnvironmentVariables;
import uk.org.webcompere.systemstubs.jupiter.SystemStub;
import uk.org.webcompere.systemstubs.jupiter.SystemStubsExtension;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;

import static org.junit.jupiter.api.Assertions.assertTrue;

@ExtendWith(SystemStubsExtension.class)
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
public class Obds2fhirTests {
    String pathWithFile=this.getClass().getClassLoader().getResource("clinical_data/InputData/File-1-ADT2_Testpatient.xml").getPath();
    @SystemStub
    private EnvironmentVariables environmentVariables =
            new EnvironmentVariables("FILE_PATH", pathWithFile.substring(0, pathWithFile.indexOf("InputData")));
    @Test
    @Order(1)
    public void applyTransformation(){
        Obds2fhir obds2fhir = new Obds2fhir();
        obds2fhir.initializeTransformers(false);
        obds2fhir.processXmlFiles("/InputData/",1);
        obds2fhir.processXmlFiles("/tmp/oBDS_Patients/", 2);
        obds2fhir.processXmlFiles("/tmp/ADT_Patients/", 2);
        assertTrue(new File(System.getenv("FILE_PATH")).exists());
    }
    @Test
    @Order(2)
    public void comparePatient () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient-ADT-1"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_Patient_"+filename+"_ADT_1.xml";
        String expected = "FHIR_ADT_Expected-File-1.xml";
        assertTrue(compare(result, expected));
    }
    @Test
    @Order(3)
    public void compareErrorPatient () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient-ADT-2"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_Patient_"+filename+"_ADT_2.xml";
        String expected = "FHIR_ADT_Expected-File-2-MissingDate.xml";
        assertTrue(compare(result, expected));
    }
    @Test
    @Order(4)
    public void compareBatchADT () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient-ADT-1"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_batch_Patient_"+filename+"_ADT_1.xml";
        String expected = "FHIR_batch_ADT_Expected-File-1.xml";
        assertTrue(compare(result, expected));
    }
    @Test
    @Order(5)
    public void compareBatchOBDS () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient-oBDS-1"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_batch_Patient_"+filename+"_oBDS_4.xml";
        String expected = "FHIR_batch_oBDS_Expected-File-1.xml";
        assertTrue(compare(result, expected));
    }
    @Test
    @Order(6)
    public void comparePatientSyntheticADT () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient-ADT-3"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_Patient_"+filename+"_ADT_3.xml";
        String expected = "FHIR_ADT_Expected-File-3.xml";
        assertTrue(compare(result, expected));
    }
    @Test
    @Order(7)
    public void comparePatientSyntheticOBDS () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient-oBDS-1"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_Patient_"+filename+"_oBDS_4.xml";
        String expected = "FHIR_oBDS_Expected-File-4.xml";
        assertTrue(compare(result, expected));
    }
    @Test
    @Order(8)
    public void compareSampleOBDS () throws IOException {
        String filename = DigestUtils.sha256Hex("testpatient-oBDS-1"+System.getenv().getOrDefault("SALT","")).substring(48);
        String result = "tmp/FHIR_Patients/FHIR_Patient_"+filename+"_oBDS_5.xml";
        String expected = "FHIR_oBDS-Sample_Expected-File-5.xml";
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
        String result = bundle.replaceAll("([/\"])([a-z0-9]{16,23}[ADToBDS-]{0,5}[-0-9]{0,2})(\")","$1replaced-id$3");
        //replace pseudonym
        result = result.replaceAll("(<value value=\")(.{1,32})\"","$1replaced-pseudonym\"");
        //replace separator
        result = result.replaceAll("\r","");
        //replace artefacts
        result = result.replaceAll("<id value=\"tpatient.xml\"/>","<id value=\"replaced-id\"/>");
        return result;
    }
}
