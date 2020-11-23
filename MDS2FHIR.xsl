<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xsl:stylesheet xmlns="http://schema.samply.de/store" xmlns:mds2fhir="https://github.com/samply/repoTODO" xmlns:dktk="http://dktk.dkfz.de" xmlns:saxon="http://saxon.sf.net" xmlns:xalan="http://xml.apache.org/xalan" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" exclude-result-prefixes="xs xsi dktk saxon xalan #default" version="2.0" xpath-default-namespace="http://www.mds.de/namespace">

    <xsl:output encoding="UTF-8" indent="yes" method="xml" />
    <xsl:output omit-xml-declaration="yes" indent="yes" />
    <xsl:strip-space elements="*" />

    <xsl:template match="/">

        <xsl:param name="Patient_ID" select="Patienten/@Patient_ID" />
        <Bundle xmlns="http://hl7.org/fhir">
            <id value="{generate-id()}" />
            <type value="transaction" />
            <xsl:variable name="root" select="/" />
            <xsl:apply-templates select="Patienten/Patient" mode="patient" />
        </Bundle>
    </xsl:template>


    <xsl:template match="Sample" mode="sample">
        <xsl:param name="Patient_ID" select="../@Patient_ID" />
        <xsl:variable name="Sample_ID" select="@Sample_ID" />
        <entry>
            <fullUrl value="http://example.com/Specimen/{$Sample_ID}"/>
            <resource>
              <Specimen>
                <id value="{$Sample_ID}"/>
                <meta>
                  <profile value="https://fhir.bbmri.de/StructureDefinition/Specimen"/>
                </meta>
                <type>
                  <coding>
                    <system value="https://fhir.bbmri.de/CodeSystem/SampleMaterialType"/>
                    <code>
                        <xsl:choose>
                            <xsl:when test="./Probentyp='Gewebeprobe'">
                            <xsl:choose>
                                <xsl:when test="./Fixierungsart='Kryo/Frisch (FF)'">
                                <xsl:choose>
                                    <xsl:when test="./Probenart='Tumorgewebe'">
                                        <xsl:attribute name="value">tumor-tissue-frozen</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./Probenart='Normalgewebe'">
                                        <xsl:attribute name="value">normal-tissue-frozen</xsl:attribute>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:attribute name="value">other-tissue-frozen</xsl:attribute>
                                    </xsl:otherwise>
                                </xsl:choose>
                                </xsl:when>
                                <xsl:when test="./Fixierungsart='Paraffin (FFPE)'">
                                <xsl:choose>
                                    <xsl:when test="./Probenart='Tumorgewebe'">
                                        <xsl:attribute name="value">tumor-tissue-ffpe</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./Probenart='Normalgewebe'">
                                        <xsl:attribute name="value">normal-tissue-ffpe</xsl:attribute>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:attribute name="value">other-tissue-ffpe</xsl:attribute>
                                    </xsl:otherwise>
                                </xsl:choose>
                                </xsl:when>
                            </xsl:choose>
                            </xsl:when>
                            <xsl:when test="./Probentyp='Flüssigprobe'">
                            <xsl:choose>
                                <xsl:when test="./Probenart='Vollblut'">
                                    <xsl:attribute name="value">whole-blood</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Serum'">
                                    <xsl:attribute name="value">blood-serum</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Plasma'">
                                    <xsl:attribute name="value">blood-plasma</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Urin'">
                                    <xsl:attribute name="value">urine</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Liquor'">
                                    <xsl:attribute name="value">csf-liquor</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Knochenmark'">
                                    <xsl:attribute name="value">bone-marrow</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='DNA'">
                                <xsl:attribute name="value">dna</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='RNA'">
                                    <xsl:attribute name="value">rna</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Protein'">
                                    <xsl:attribute name="value">derivative-other</xsl:attribute>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:attribute name="value">liquid-other</xsl:attribute>
                                </xsl:otherwise>
                            </xsl:choose>
                            </xsl:when>
                        </xsl:choose>
                    </code>
                  </coding>
                </type>
                <subject>
                  <reference value="Patient/{$Patient_ID}"/>
                </subject>
                <collection>
                  <collectedDateTime value="{mds2fhir:transformDate(./Entnahmedatum)}"/>
                </collection>
              </Specimen>
            </resource>
            <request>
              <method value="PUT"/>
              <url value="Specimen/{$Sample_ID}"/>
            </request>
          </entry>
    </xsl:template>

    <xsl:template match="Diagnosis" mode="diagnosis">
        <xsl:param name="Patient_ID" select="../@Patient_ID" />
        <xsl:variable name="Diagnosis_ID" select="./@Diagnosis_ID" />

        <!-- Menge_Patient > Patient > Menge_Meldung > Menge_OP > OP -->
        <xsl:apply-templates select="./Tumor" mode="tumor">
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>
        

        <entry>
            <fullUrl value="http://example.com/Condition/{$Diagnosis_ID}" />
            <resource>
        <Condition xmlns="http://hl7.org/fhir">
            <id value="{$Diagnosis_ID}" />
            <meta>
                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Condition-Primaerdiagnose" />
            </meta>
            <!-- Alter bei Erstdiagnode -->
            <code>
                <coding>
                    <!-- Kann auch WHO sein, TODO-->
                    <system value="http://fhir.de/CodeSystem/dimdi/icd-10-gm" />
                    <version value="{mds2fhir:getVersionYear(./ICD-Katalog_Version)}" />
                    <code value="{./Diagnose}" />
                </coding>
            </code>
            <bodySite>
                <coding>
                    <system value="urn:oid:2.16.840.1.113883.6.43.1" />
                    <version value="{./Tumor/ICD-O_Katalog_Topographie_Version}" />
                    <code value="{./Tumor/Lokalisation}" />
                </coding>
                <coding>
                    <system value="urn:oid:2.16.840.1.113883.2.6.60.7.1.1" />
                    <code value="{./Tumor/Seitenlokalisation}" />
                </coding>
            </bodySite>
            <subject>
                <reference value="Patient/{$Patient_ID}" />
            </subject>
            <recordedDate value="{mds2fhir:transformDate(./Tumor_Diagnosedatum)}" />
            <stage>
                <assessment>
                    <reference value="Observation/Observation-TNMc-example-1" />
                </assessment>
            </stage>
            <evidence>
                <detail>
                    <!-- Loop über alle kind-histo und ids generieren-->
                    <xsl:for-each select="./Diagnose/Tumor/Histology" >
                    <reference value="Observation/{./@Histology_ID}" />
                    </xsl:for-each>
                </detail>
            </evidence>
        </Condition>
    </resource>
    <request>
      <method value="PUT"/>
      <url value="Condition/{$Diagnosis_ID}"/>
    </request>
  </entry>

    </xsl:template>


    <xsl:template match="System_Therapy">
        <xsl:param name="Progress_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="System_Therapy_ID" select="dktk:getID(./@System_Therapy_ID, $Progress_ID, 'System_Therapy', generate-id())" as="xs:string" />
        <!-- Noch nicht fertig, offene Fragen und fehlende felder -->
        <entry>
            <fullUrl value="http://example.com/MedicationStatement/{$System_Therapy_ID}" />
            <resource>
                <MedicationStatement>
                    <id value="{$System_Therapy_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-MedicationStatement-Systemtherapie" />
                    </meta>
                    <xsl:if test="../Systemische_Therapie_Stellung_zu_operativer_Therapie">
                    <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS" />
                                <code value="{../Systemische_Therapie_Stellung_zu_operativer_Therapie}" />
                            </coding>
                        </valueCodeableConcept>
                    </extension>
                    </xsl:if>
                    <status value="completed" />
                    <category>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                            <code value="????" />
                        </coding>
                    </category>
                    <medicationCodeableConcept>
                        <text value="{./Systemische_Therapie_Substanzen}" />
                    </medicationCodeableConcept>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <reasonReference value="Condition/{$Diagnosis_ID}" />"
                </MedicationStatement>
            </resource>
            <request>
                <method value="PUT" />
                <url value="MedicationStatement/{$System_Therapy_ID}" />
            </request>
        </entry>

    </xsl:template>

    <xsl:template match="Radiation_Therapy">
        <xsl:param name="Progress_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="Radiation_Therapy_ID" select="dktk:getID(./@Radiation_Therapy_ID, $Progress_ID, 'Radiation_Therapy', generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/Procedure/{$Radiation_Therapy_ID}" />
            <resource>
                <Procedure>
                    <id value="{$Radiation_Therapy_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Strahlentherapie" />
                    </meta>
                    <xsl:if test="../Strahlentherapie_Stellung_zu_operativer_Therapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS" />
                                    <code value="{../Strahlentherapie_Stellung_zu_operativer_Therapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:if test="../Intention_Strahlentherapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SYSTIntention">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTIntentionCS" />
                                    <code value="{../Intention_Strahlentherapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <status value="completed" />
                    <category>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                            <code value="ST" />
                            <display value="Strahlentherapie" />
                        </coding>
                    </category>
                    <code>
                        <coding>
                            <system value="http://fhir.de/CodeSystem/dimdi/ops"/>
                            <code value="8-52"/>
                            <display value="Strahlentherapie"/>
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <xsl:if test="./Strahlentherapie_Beginn or ./Strahlentherapie_Ende">
                        <performedPeriod>
                            <xsl:if test="./Strahlentherapie_Beginn">
                                <start value="{mds2fhir:transformDate(./Strahlentherapie_Beginn)}" />
                            </xsl:if>
                            <xsl:if test="./Strahlentherapie_Ende">
                                <end value="{mds2fhir:transformDate(./Strahlentherapie_Ende)}" />
                            </xsl:if>
                        </performedPeriod>
                    </xsl:if>
                    <reasonReference value="Condition/{$Diagnosis_ID}" />"
                </Procedure>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Procedure/{$Radiation_Therapy_ID}" />
            </request>
        </entry>
    </xsl:template>

    <xsl:template match="Surgery">
        <xsl:param name="Progress_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="Surgery_ID" select="dktk:getID(./@Surgery_ID, $Progress_ID, 'Surgery', generate-id())" as="xs:string" />
        
        <entry>
            <fullUrl value="http://example.com/Procedure/{$Surgery_ID}" />
            <resource>
                <Procedure>
                    <id value="{$Surgery_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Operation" />
                    </meta>
                    <xsl:if test="../Intention_OP">
                    <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-OPIntention">
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/OPIntentionCS" />
                                <code value="{../Intention_OP}" />
                            </coding>
                        </valueCodeableConcept>
                    </extension>
                </xsl:if>
                    <status value="completed" />
                    <category>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                            <code value="OP" />
                            <display value="Operation" />
                        </coding>
                    </category>
                    <!--Maybe find some SCT code to have at least something to encode? -->
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <reasonReference value="Condition/{$Diagnosis_ID}" />"
                    <outcome>
                        <xsl:if test="./Lokale_Beurteilung_Resttumor">
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/LokaleBeurteilungResidualstatusCS" />
                            <code value="{./Lokale_Beurteilung_Resttumor}" />
                        </coding>
                    </xsl:if>
                    <xsl:if test="./Gesamtbeurteilung_Resttumor">
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungResidualstatusCS" />
                            <code value="{./Gesamtbeurteilung_Resttumor}" />
                        </coding>
                    </xsl:if>
                    </outcome>
                </Procedure>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Procedure/{$Surgery_ID}" />
            </request>
        </entry>

    </xsl:template>

    <xsl:template match="Progress">
        <xsl:param name="Tumor_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="Progress_ID" select="dktk:getID(./@Progress_ID, $Tumor_ID, 'Progress', generate-id())" as="xs:string" />



        <entry>
            <fullUrl value="http://example.com/ClinicalImpression/{$Progress_ID}" />
            <resource>
                <ClinicalImpression xmlns="http://hl7.org/fhir">
                    <id value="{$Progress_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-ClinicalImpression-Verlauf" />
                    </meta>
                    <status value="completed" />
                    <subject>
                        <reference value="Patient/{Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="2018-01-01" />
                    <problem>
                        <reference value="Condition/{Diagnosis_ID}" />
                    </problem>
                    <!-- TODO for each entry in progress link to coressponding observation-->
                    <finding>
                        <itemReference>
                            <reference value="Observation/Observation-Fernmetastasen-example-1" />
                        </itemReference>
                    </finding>
                </ClinicalImpression>
            </resource>
            <request>
                <method value="PUT" />
                <url value="ClinicalImpression/{$Progress_ID}" />
            </request>
        </entry>





        <xsl:apply-templates select="./Surgery">
            <xsl:with-param name="Progress_ID" select="$Progress_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./Radiation_Therapy">
            <xsl:with-param name="Progress_ID" select="$Progress_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./System_Therapy">
            <xsl:with-param name="Progress_ID" select="$Progress_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>
    </xsl:template>


    <xsl:template match="TNM">
        <xsl:param name="Tumor_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:variable name="TNM_ID" select="dktk:getID(./@TNM_ID, $Tumor_ID, 'TNM', generate-id())" as="xs:string" />

        <entry>
            <fullUrl value="http://example.com/Observation/{$TNM_ID}" />
            <resource>
                <Observation>
                    <id value="{$TNM_ID}" />
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code>
                                <xsl:choose>
                                    <xsl:when test="./c-p-u-Präfix_T='c' and ./c-p-u-Präfix_N='c' and ./c-p-u-Präfix_M='c'">
                                        <xsl:attribute name="value">21908-9</xsl:attribute>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:attribute name="value">21902-2</xsl:attribute>
                                    </xsl:otherwise>
                                </xsl:choose>
                            </code>
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <issued value="{mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund)}" />
                    <xsl:if test="./UICC_Stadium">
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/UiccstadiumCS" />
                                <code value="{./UICC_Stadium}" />
                            </coding>
                        </valueCodeableConcept>
                    </xsl:if>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code>
                                    <xsl:choose>
                                    <xsl:when test="./c-p-u-Präfix_T='c'">
                                        <xsl:attribute name="value">21905-5</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./c-p-u-Präfix_T='p'">
                                        <xsl:attribute name="value">21899-0</xsl:attribute>
                                    </xsl:when>
                                </xsl:choose>
                                </code> 
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMTCS" />
                                <code value="{./TNM-T}" />
                            </coding>
                        </valueCodeableConcept>
                    </component>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code>
                                    <xsl:choose>
                                    <xsl:when test="./c-p-u-Präfix_N='c'">
                                        <xsl:attribute name="value">201906-3</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./c-p-u-Präfix_N='p'">
                                        <xsl:attribute name="value">21900-6</xsl:attribute>
                                    </xsl:when>
                                </xsl:choose>
                                </code> 
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMNCS" />
                                <code value="{./TNM-N}" />
                            </coding>
                        </valueCodeableConcept>
                    </component>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code>
                                    <xsl:choose>
                                    <xsl:when test="./c-p-u-Präfix_M='c'">
                                        <xsl:attribute name="value">21907-1</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./c-p-u-Präfix_M='p'">
                                        <xsl:attribute name="value">21901-4</xsl:attribute>
                                    </xsl:when>
                                </xsl:choose>
                                </code> 
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMMCS" />
                                <code value="{./TNM-M}" />
                            </coding>
                        </valueCodeableConcept>
                    </component>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="59479-6" />
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMySymbolCS" />
                                <code>
                                    <xsl:choose>
                                        <xsl:when test="./TNM-y-Symbol='y'">
                                            <xsl:attribute name="value">y</xsl:attribute>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:attribute name="value">9</xsl:attribute>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </code>
                            </coding>
                        </valueCodeableConcept>
                    </component>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="21983-2" />
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMrSymbolCS" />
                                <code>
                                    <xsl:choose>
                                        <xsl:when test="./TNM-r-Symbol='r'">
                                            <xsl:attribute name="value">r</xsl:attribute>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:attribute name="value">9</xsl:attribute>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </code>
                            </coding>
                        </valueCodeableConcept>
                    </component>
                <xsl:if test="./TNM-m-Symbol">
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="42030-7" />
                            </coding>
                        </code>
                        <valueString value="{./TNM-m-Symbol}" />
                    </component>
                </xsl:if>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$TNM_ID}" />
            </request>
        </entry>


    </xsl:template>


    <xsl:template match="Metastasis">
        <xsl:param name="Tumor_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:variable name="Metastasis_ID" select="dktk:getID(./@Metastasis_ID, $Tumor_ID, 'Metastasis', generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/Observation/{$Metastasis_ID}" />
            <resource>
                <Observation>
                    <id value="{$Metastasis_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Fernmetastasen" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="21907-1" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./Datum_diagnostische_Sicherung)}" />
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/JNUCS" />
                            <code value="J" />
                        </coding>
                    </valueCodeableConcept>
                    <bodySite>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/FMLokalisationCS" />
                            <code value="{./Lokalisation_Fernmetastasen}" />
                        </coding>
                    </bodySite>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Metastasis_ID}" />
            </request>
        </entry>
    </xsl:template>


    <xsl:template match="Histology">
        <xsl:param name="Tumor_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:variable name="Histology_ID" select="dktk:getID(./@Histology_ID, $Tumor_ID, 'Histology', generate-id())" as="xs:string" />
        <xsl:variable name="Grading_ID" select="dktk:getID(./@Histology_ID, $Tumor_ID, 'Grading', generate-id())" as="xs:string"/>

        <entry>
            <fullUrl value="http://example.com/Observation/{$Histology_ID}" />
            <resource>
                <Observation>
                    <id value="{$Histology_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Histologie" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="59847-4" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <valueCodeableConcept>
                        <coding>
                            <system value="urn:oid:2.16.840.1.113883.6.43.1" />
                            <version value="{./ICD-O_Katalog_Morphologie_Version}" />
                            <code value="{./Morphologie}" />
                        </coding>
                    </valueCodeableConcept>
                    <hasMember>
                        <reference value="Observation/{$Grading_ID}" />
                    </hasMember>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Histology_ID}" />
            </request>
        </entry>
        <entry>
            <fullUrl value="http://example.com/Observation/{$Grading_ID}" />
            <resource>
                <Observation>
                    <id value="{$Grading_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Grading" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="59542-1" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GradingCS" />
                            <code value="{./Grading}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Grading_ID}" />
            </request>
        </entry>
    </xsl:template>


    <xsl:template match="Tumor" mode="tumor">
        <xsl:param name="Diagnosis_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:variable name="Tumor_ID" select="dktk:getID(./@Tumor_ID, $Diagnosis_ID, 'Tumor', generate-id())" as="xs:string" />

        <xsl:apply-templates select="./Histology">
            <xsl:with-param name="Tumor_ID" select="$Tumor_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>
        <xsl:if test="./Fernmetastasen_vorhanden='ja'">
            <xsl:apply-templates select="./Metastasis">
                <xsl:with-param name="Tumor_ID" select="$Tumor_ID" />
                <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            </xsl:apply-templates>
        </xsl:if>

        <xsl:apply-templates select="./TNM">
            <xsl:with-param name="Tumor_ID" select="$Tumor_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>
        <xsl:apply-templates select="./Progress">
            <xsl:with-param name="Tumor_ID" select="$Tumor_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>
    </xsl:template>


    <xsl:template match="Patient" mode="patient">
        <xsl:variable name="Patient_ID" select="@Patient_ID" />
        <entry>
            <fullUrl value="http://example.com/Patient/{$Patient_ID}" />
            <resource>
                <Patient>
                    <id value="{$Patient_ID}" />
                    <meta>
                        <profile value="https://fhir.bbmri.de/StructureDefinition/Patient" />
                    </meta>
                    <!-- lokale ID als Identifier-->
                    <!-- decased: Wenn verstorben dann Datum des VS = todesdatum-->
                    <gender>
                        <xsl:choose>
                            <xsl:when test="./Geschlecht='M'">
                                <xsl:attribute name="value">male</xsl:attribute>
                            </xsl:when>
                            <xsl:when test="./Geschlecht='F'">
                                <xsl:attribute name="value">female</xsl:attribute>
                            </xsl:when>
                            <xsl:when test="./Geschlecht='S'">
                                <xsl:attribute name="value">other</xsl:attribute>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:attribute name="value">unknown</xsl:attribute>
                            </xsl:otherwise>
                        </xsl:choose>
                    </gender>
                    <birthDate value="{mds2fhir:transformDate(./Geburtsdatum)}" />
                </Patient>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Patient/{$Patient_ID}" />
            </request>
        </entry>
        <entry>
            <fullUrl value="http://example.com/Observation/{$Patient_ID}-vitalstatus" />
            <resource>
                <Observation>
                    <id value="{$Patient_ID}-vitalstatus" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Vitalstatus" />
                    </meta>
                    <status value="registered" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="75186-7" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./Datum_des_letztbekannten_Vitalstatus)}" />
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VitalstatusCS" />
                            <code value="{./Vitalstatus}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Patient_ID}-vitalstatus" />
            </request>
        </entry>

        <!-- Patienten > Patient > Sample -->
        <xsl:apply-templates select="./Sample" mode="sample">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>

        <!-- Patienten > Patient > Diagnose -->
        <xsl:apply-templates select="./Diagnosis" mode="diagnosis">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>
    </xsl:template>


    <!-- Konstanten -->
    <xsl:template name="constants">
        <xsl:param name="constant" />
        <!-- weitere Konstante können hinzugefügt werden -->
        <xsl:variable name="tnm">
            <xsl:copy-of select="dktk:elements(., ('TNM_Datum', 'TNM_Version', 'TNM_r_Symbol', 'TNM_c_p_u_Praefix_T', 'TNM_T', 'TNM_c_p_u_Praefix_N', 'TNM_N', 'TNM_c_p_u_Praefix_M', 'TNM_M', 'TNM_Pn', 'TNM_y_Symbol', 'TNM_a_Symbol', 'TNM_m_Symbol', 'TNM_L', 'TNM_V', 'TNM_S'))" />
        </xsl:variable>
        <xsl:copy-of select="$tnm" />
    </xsl:template>
    <!-- Funktionen -->
    <!-- 
			<xsl:variable name="parent_and_id" select="if(string-length($parent)>0) then concat($parent,'#', $id) else $id">
	-->
    <xsl:function name="dktk:getID">
        <xsl:param name="id" />
        <xsl:param name="parent" />
        <xsl:param name="key" />
        <xsl:param name="prefix" />

        <xsl:sequence select="
			if ($id and $id != '') then
			if(string-length($parent)>0) 
			then concat($parent,'#', $id,'#', $key)
			else concat($id,'#', $key)
			else
			if(string-length($parent)>0) 
			then concat($parent,'#', $prefix,'#', $key)
			else concat($prefix,'#', $key)" />
    </xsl:function>

    <xsl:function name="dktk:elements">
        <xsl:param name="node" />
        <xsl:param name="elements" />
        <xsl:for-each select="$elements">
            <xsl:variable name="element" select="." />
            <xsl:apply-templates mode="textnode" select="$node/*[local-name() = $element]" />
        </xsl:for-each>
    </xsl:function>

    <xsl:function name="mds2fhir:transformDate"><!--TODO: 00 Month und day -->
        <xsl:param name="date" />
        <xsl:variable name="day" select="substring($date, 1,2)" as="xs:string"/>
        <xsl:variable name="month" select="substring($date, 4, 2)" as="xs:string"/>
        <xsl:variable name="year" select="substring($date, 7, 4)" as="xs:string"/>
        <xsl:value-of select="concat($year,'-',$month,'-',$day)" />
    </xsl:function>

    <xsl:function name="mds2fhir:getVersionYear">
        <xsl:param name="version" />
        <xsl:value-of select="substring($version, 4, 4)" />
    </xsl:function>

</xsl:stylesheet>