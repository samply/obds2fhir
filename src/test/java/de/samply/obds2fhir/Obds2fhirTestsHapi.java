package de.samply.obds2fhir;

import ca.uhn.fhir.context.FhirContext;
import ca.uhn.fhir.parser.IParser;
import org.hl7.fhir.r4.model.Bundle;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.nio.file.Files;
import java.nio.file.Paths;

import static org.junit.jupiter.api.Assertions.assertTrue;

class Obds2fhirTestsHapi {

    private FhirContext fhirContext;

    @BeforeEach
    public void setUp() {
        // Initialize the FHIR context for the FHIR version (R4 in this example)
        fhirContext = FhirContext.forR4();  // Choose the correct FHIR version here
    }

    @Test
    void testETLTransformationWithXml() throws Exception {
        // Load input XML as a string
        String inputXml = new String(Files.readAllBytes(Paths.get("src/test/resources/input.xml")));

        // Perform the transformation using your ETL tool to generate a FHIR Bundle
        Bundle actualBundle = transformXmlToFhirBundle(inputXml);

        // Load the expected FHIR Bundle XML
        String expectedXml = new String(Files.readAllBytes(Paths.get("src/test/resources/expectedOutput.xml")));

        // Parse the expected XML to a FHIR Bundle
        IParser xmlParser = fhirContext.newXmlParser();
        Bundle expectedBundle = xmlParser.parseResource(Bundle.class, expectedXml);

        // Use equalsDeep to compare actual and expected FHIR Bundles
        assertTrue(actualBundle.equalsDeep(expectedBundle), "The FHIR Bundles do not match!");
    }

    private Bundle transformXmlToFhirBundle(String inputXml) {
        // Implement the logic to transform input XML to FHIR Bundle
        // This would typically call your ETL tool's logic
        // Example:
        return ETLTool.transformToBundle(inputXml);  // Replace this with your actual transformation logic
    }
}
