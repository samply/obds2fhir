<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xsl:stylesheet
        xmlns="http://hl7.org/fhir"
        xmlns:mds2fhir="https://github.com/samply/adt2fhir/blob/main/MDS_FHIR2FHIR"
        xmlns:dktk="http://dktk.dkfz.de"
        xmlns:saxon="http://saxon.sf.net"
        xmlns:xalan="http://xml.apache.org/xalan"
        xmlns:xs="http://www.w3.org/2001/XMLSchema"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:hash="java:de.samply.adt2fhir"
        exclude-result-prefixes="xs xsi dktk saxon xalan mds2fhir #default"
        version="2.0"
        xpath-default-namespace="http://www.mds.de/namespace">

    <!-- Settings-->
    <!-- System für lokale Identifier-->
    <xsl:param name="identifier_system" />
    <xsl:variable name="Lokal_DKTK_ID_Pat_System"><xsl:value-of select="$identifier_system"/></xsl:variable>

    <xsl:output encoding="UTF-8" indent="yes" method="xml" />
    <xsl:output omit-xml-declaration="yes" indent="yes" />
    <xsl:strip-space elements="*" />
    <xsl:param name="filepath" />
    <xsl:param name="customPrefix" />

    <!-- Ende Settings -->

    <xsl:template match="/">

        <xsl:param name="Patient_ID" select="Patienten/@Patient_ID" />

        <xsl:variable name="root" select="/" />
        <xsl:apply-templates select="Patienten/Patient" mode="patient" />

    </xsl:template>

    <xsl:template match="Patient" mode="patient">
        <xsl:variable name="Patient_ID" select="@Patient_ID" />
        <xsl:variable name="Vitalstatus_ID" select="hash:hash($Patient_ID, 'vitalstatus', '')" />
        <xsl:result-document href="file:{$filepath}/tmp/FHIR_Patients/FHIR_{$customPrefix}">
        <Bundle xmlns="http://hl7.org/fhir">
            <id value="{generate-id()}" />
            <type value="transaction" />
            <entry>
                <fullUrl value="http://example.com/Patient/{$Patient_ID}" />
                <resource>
                    <Patient>
                        <id value="{$Patient_ID}" />
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Patient-Patient" />
                        </meta>
                        <identifier>
                            <type>
                                <coding>
                                    <system value="{$Lokal_DKTK_ID_Pat_System}"/>
                                    <code value="Lokal"/>
                                </coding>
                            </type>
                            <value value="{./DKTK_LOCAL_ID}"/>
                        </identifier>
                        <!--<xsl:if test="./Vitalstatus='verstorben'"><deceasedDateTime value="{mds2fhir:transformDate(./Datum_des_letztbekannten_Vitalstatus)}"/></xsl:if>-->
                        <gender>
                            <xsl:choose>
                                <xsl:when test="./Geschlecht='M'">
                                    <xsl:attribute name="value">male</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Geschlecht='F' or ./Geschlecht='W'">
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
                        <xsl:if test="./Geburtsdatum"><birthDate value="{mds2fhir:transformDate(./Geburtsdatum)}" /></xsl:if>
                    </Patient>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Patient/{$Patient_ID}" />
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

        </Bundle>
        </xsl:result-document>

        <xsl:result-document href="file:{$filepath}/tmp/FHIR_Patients/FHIR_batch_{$customPrefix}">
            <Bundle xmlns="http://hl7.org/fhir">
                <id value="{generate-id()}" />
                <type value="batch" />
                <entry>
                    <fullUrl value="http://example.com/Observation/{$Vitalstatus_ID}" />
                    <resource>
                        <Observation>
                            <id value="{$Vitalstatus_ID}" />
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
                            <xsl:if test="./Datum_des_letztbekannten_Vitalstatus"><effectiveDateTime value="{mds2fhir:transformDate(./Datum_des_letztbekannten_Vitalstatus)}" /></xsl:if>
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
                        <xsl:if test="not(./Vitalstatus = 'verstorben')">
                            <ifNoneMatch value="*"/>
                        </xsl:if>
                        <url value="Observation/{$Vitalstatus_ID}" />
                    </request>
                </entry>
                <xsl:for-each select="./Organisationen/Abteilung">
                    <xsl:variable name="Encounter_ID" select="hash:hash($Patient_ID, ., '')"/>
                    <entry>
                        <fullUrl value="http://example.com/Encounter/{$Encounter_ID}" />
                        <resource>
                            <Encounter>
                                <id value="{$Encounter_ID}" />
                                <meta>
                                    <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Encounter-Fall" />
                                </meta>
                                <identifier>
                                    <system value="http://dktk.dkfz.de/fhir/sid/hki-department"/>
                                    <value value="{.}"/>
                                </identifier>
                                <status value="finished" />
                                <class>
                                    <system value="http://terminology.hl7.org/CodeSystem/v3-ActCode" />
                                    <code value="VR" />
                                    <display value="virtual" />
                                </class>
                                <subject>
                                    <reference value="Patient/{$Patient_ID}" />
                                </subject>
                            </Encounter>
                        </resource>
                        <request>
                            <method value="PUT" />
                            <ifNoneMatch value="*"/>
                            <url value="Encounter/{$Encounter_ID}" />
                        </request>
                    </entry>
                </xsl:for-each>
            </Bundle>

        </xsl:result-document>
    
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
                <xsl:if test="./Entnahmedatum">
                  <collection>
                    <collectedDateTime value="{mds2fhir:transformDate(./Entnahmedatum)}"/>
                  </collection>
                </xsl:if>
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
        <xsl:if test="./Diagnose">
            <entry>
                <fullUrl value="http://example.com/Condition/{$Diagnosis_ID}" />
                <resource>
                    <Condition xmlns="http://hl7.org/fhir">
                        <id value="{$Diagnosis_ID}" />
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Condition-Primaerdiagnose" />
                        </meta>
                        <xsl:for-each select="./Tumor/Metastasis">
                            <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-Fernmetastasen">
                                <valueReference>
                                    <reference value="Observation/{mds2fhir:getID(./@Metastasis_ID, mds2fhir:transformDate(./Datum_diagnostische_Sicherung), generate-id())}" />
                                </valueReference>
                            </extension>
                        </xsl:for-each>
                        <code>
                            <coding>
                                <xsl:if test="./ICD-Katalog_Version">
                                    <system value="{mds2fhir:getICDType(./ICD-Katalog_Version)}" />
                                    <version value="{mds2fhir:getVersionYear(./ICD-Katalog_Version)}" />
                                </xsl:if>
                                <code value="{./Diagnose}" />
                            </coding>
                            <xsl:if test="./Diagnose_Text"><text value="{./Diagnose_Text}" /></xsl:if>
                        </code>
                        <bodySite>
                            <coding>
                                <system value="urn:oid:2.16.840.1.113883.6.43.1" />
                                <xsl:if test="./Tumor/ICD-O_Katalog_Topographie_Version">"<version value="{./Tumor/ICD-O_Katalog_Topographie_Version}" /></xsl:if>
                                <xsl:if test="./Tumor/Lokalisation"><code value="{./Tumor/Lokalisation}" /></xsl:if>
                            </coding>
                            <xsl:if test="./Tumor/Seitenlokalisation">
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SeitenlokalisationCS" />
                                    <code value="{./Tumor/Seitenlokalisation}" />
                                </coding>
                            </xsl:if>
                        </bodySite>
                        <subject>
                            <reference value="Patient/{$Patient_ID}" />
                        </subject>
                        <xsl:if test="./Tumor_Diagnosedatum">
                            <onsetDateTime value="{mds2fhir:transformDate(./Tumor_Diagnosedatum)}" />
                            <recordedDate value="{mds2fhir:transformDate(./Tumor_Diagnosedatum)}" />
                        </xsl:if>
                        <xsl:for-each select="./Tumor/TNM">
                        <stage>
                            <assessment>
                                <reference value="Observation/{mds2fhir:getID(./@TNM_ID, mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund), generate-id())}" />
                            </assessment>
                        </stage>
                        </xsl:for-each>
                        <evidence>
                            <xsl:for-each select="./Tumor/Histology">
                                <detail>
                                    <reference value="Observation/{mds2fhir:getID(./@Histology_ID,'',generate-id())}" />
                                </detail>
                        </xsl:for-each>
                        </evidence>
                    </Condition>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Condition/{$Diagnosis_ID}" />
                </request>
            </entry>
        </xsl:if>
        <xsl:apply-templates select="./Tumor" mode="tumor">
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>
    </xsl:template>


    <xsl:template match="SYST">
        <xsl:param name="Progress_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="System_Therapy_ID" select="mds2fhir:getID(./@SYST_ID, mds2fhir:transformDate(./Systemische_Therapie_Beginn), generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/MedicationStatement/{$System_Therapy_ID}" />
            <resource>
                <MedicationStatement>
                    <id value="{$System_Therapy_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-MedicationStatement-Systemtherapie" />
                    </meta>
                    <xsl:if test="./Systemische_Therapie_Stellung_zu_operativer_Therapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS" />
                                    <code value="{./Systemische_Therapie_Stellung_zu_operativer_Therapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Intention_Chemotherapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SYSTIntention">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTIntentionCS" />
                                    <code value="{./Intention_Chemotherapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Lokale_Beurteilung_Resttumor">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-LokaleResidualstatus">
                            <valueReference>
                                <reference value="Observation/{mds2fhir:getID(hash:hash($Patient_ID, $Diagnosis_ID , concat(./Lokale_Beurteilung_Resttumor, $System_Therapy_ID, 'lokal')),'', generate-id(./Lokale_Beurteilung_Resttumor))}" />
                            </valueReference>
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Gesamtbeurteilung_Resttumor">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-GesamtbeurteilungResidualstatus">
                            <valueReference>
                                <reference value="Observation/{mds2fhir:getID(hash:hash($Patient_ID, $Diagnosis_ID , concat(./Gesamtbeurteilung_Resttumor, $System_Therapy_ID, 'gesamt')),'', generate-id(./Gesamtbeurteilung_Resttumor))}" />
                            </valueReference>
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Systemische_Therapie_Protokoll">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SystemischeTherapieProtokoll">
                            <valueCodeableConcept>
                                <text value="{./Systemische_Therapie_Protokoll}" />
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:choose>
                        <xsl:when test="./Systemische_Therapie_Ende">
                            <xsl:choose>
                                <xsl:when test="SYST_Ende_Grund='E' or SYST_Ende_Grund='R'">
                                    <status value="completed" />
                                </xsl:when>
                                <xsl:when test="SYST_Ende_Grund='U'">
                                    <status value="unknown" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <status value="stopped" />
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:choose>
                                <xsl:when test="./Systemische_Therapie_Beginn">
                                    <status value="active" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <status value="intended" />
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                    <category>
                        <xsl:for-each select="./SYST_Therapieart">
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                                <code value="{.}" />
                            </coding>
                        </xsl:for-each>
                    </category>
                    <!-- There may be more substances, but we can only save one here -->
                    <medicationCodeableConcept>
                    <xsl:choose>
                        <xsl:when test="./SYST_Substanz">
                            <text value="{./SYST_Substanz}" />
                        </xsl:when>
                        <xsl:otherwise>
                            <text value="Keine Angabe zur Substanz" />
                        </xsl:otherwise>
                    </xsl:choose>
                    </medicationCodeableConcept>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <xsl:if test="./Systemische_Therapie_Beginn or ./Systemische_Therapie_Ende">
                        <effectivePeriod>
                            <xsl:if test="./Systemische_Therapie_Beginn"><start value="{mds2fhir:transformDate(./Systemische_Therapie_Beginn)}" /></xsl:if>
                            <xsl:if test="./Systemische_Therapie_Ende"><end value="{mds2fhir:transformDate(./Systemische_Therapie_Ende)}" /></xsl:if>
                        </effectivePeriod>
                    </xsl:if>
                    <reasonReference>
                        <reference value="Condition/{$Diagnosis_ID}" />
                    </reasonReference> 
                </MedicationStatement>
            </resource>
            <request>
                <method value="PUT" />
                <url value="MedicationStatement/{$System_Therapy_ID}" />
            </request>
        </entry>

        <!--<xsl:for-each select="./SYST_Nebenwirkung">
            <xsl:variable name="Nebenwirkung_ID" select="mds2fhir:getID(./@Nebenwirkung_ID, '', generate-id())" as="xs:string" />
            <entry>
                <fullUrl value="http://example.com/AdverseEvent/{$Nebenwirkung_ID}" />
                <resource>
                    <AdverseEvent xmlns="http://hl7.org/fhir">
                        <id value="{$Nebenwirkung_ID}" />
                        <actuality value="actual" />
                        <event>
                            <text value="{./Nebenwirkung_Art}" />
                        </event>
                        <subject>
                            <reference value="Patient/{$Patient_ID}" />
                        </subject>
                        <suspectEntity>
                            <instance>
                                <reference value="MedicationStatement/{$System_Therapy_ID}" />
                            </instance>
                        </suspectEntity>
                    </AdverseEvent>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="AdverseEvent/{$Nebenwirkung_ID}" />
                </request>
            </entry>
        </xsl:for-each>-->

        <xsl:if test="./Gesamtbeurteilung_Resttumor">
        <entry>
            <xsl:variable name="Gesamtbeurteilung_Resttumor_ID" select="mds2fhir:getID(hash:hash($Patient_ID, $Diagnosis_ID , concat(./Gesamtbeurteilung_Resttumor, $System_Therapy_ID, 'gesamt')),'', generate-id(./Gesamtbeurteilung_Resttumor))"/>
            <fullUrl value="http://example.com/Observation/{$Gesamtbeurteilung_Resttumor_ID}" />
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{$Gesamtbeurteilung_Resttumor_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-GesamtbeurteilungResidualstatus" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="81169-5" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <focus>
                        <reference value="Condition/{$Diagnosis_ID}"/>
                    </focus>
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungResidualstatusCS" />
                            <code value="{./Gesamtbeurteilung_Resttumor}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Gesamtbeurteilung_Resttumor_ID}" />
            </request>
        </entry>
    </xsl:if>
    <xsl:if test="./Lokale_Beurteilung_Resttumor">
        <entry>
            <xsl:variable name="Lokale_Beurteilung_Resttumor_ID" select="mds2fhir:getID(hash:hash($Patient_ID, $Diagnosis_ID , concat(./Lokale_Beurteilung_Resttumor, $System_Therapy_ID, 'lokal')),'', generate-id(./Lokale_Beurteilung_Resttumor))"/>
            <fullUrl value="http://example.com/Observation/{$Lokale_Beurteilung_Resttumor_ID}" />
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{$Lokale_Beurteilung_Resttumor_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-LokaleBeurteilungResidualstatus" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="84892-9" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <focus>
                        <reference value="Condition/{$Diagnosis_ID}"/>
                    </focus>
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/LokaleBeurteilungResidualstatusCS" />
                            <code value="{./Lokale_Beurteilung_Resttumor}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Lokale_Beurteilung_Resttumor_ID}" />
            </request>
        </entry>
    </xsl:if>


    </xsl:template>

    <xsl:template match="ST">
        <xsl:param name="Progress_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="Radiation_Therapy_ID" select="mds2fhir:getID(./@ST_ID,'', generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/Procedure/{$Radiation_Therapy_ID}" />
            <resource>
                <Procedure>
                    <id value="{$Radiation_Therapy_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Strahlentherapie" />
                    </meta>
<!--                    TODO: Betrahlungen abdecken; Datum ergänzen-->
                    <xsl:if test="./Strahlentherapie_Stellung_zu_operativer_Therapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS" />
                                    <code value="{./Strahlentherapie_Stellung_zu_operativer_Therapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Intention_Strahlentherapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SYSTIntention">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTIntentionCS" />
                                    <code value="{./Intention_Strahlentherapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <status value="unknown" />
                    <category>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                            <code value="ST" />
                            <display value="Strahlentherapie" />
                        </coding>
                    </category>
                    <code>
                        <coding>
                            <system value="http://fhir.de/CodeSystem/bfarm/ops"/>
                            <code value="8-52"/>
                            <display value="Strahlentherapie"/>
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <reasonReference>
                        <reference value="Condition/{$Diagnosis_ID}" />
                    </reasonReference> 
                    <xsl:if test="./Lokale_Beurteilung_Resttumor or ./Gesamtbeurteilung_Resttumor">
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
                </xsl:if>
                <!--<xsl:for-each select="./ST_Nebenwirkung">
                    <complication>
                        <text value="./Nebenwirkung_Art"/>
                    </complication>
                </xsl:for-each>-->
                </Procedure>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Procedure/{$Radiation_Therapy_ID}" />
            </request>
        </entry>

        <xsl:variable name="Radiation_Therapy_ID" select="mds2fhir:getID(./@ST_ID,'', generate-id())" as="xs:string" />
        <xsl:for-each select="./Bestrahlung">
            <xsl:variable name="Single_Radiation_Therapy_ID" select="mds2fhir:getID(./@Betrahlung_ID,mds2fhir:transformDate(./ST_Beginn_Datum), generate-id())" as="xs:string" />
            <entry>
                <fullUrl value="http://example.com/Procedure/{$Single_Radiation_Therapy_ID}" />
                <resource>
                    <Procedure>
                        <id value="{$Single_Radiation_Therapy_ID}" />
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Strahlentherapie" />
                        </meta>
                        <partOf>
                            <reference value="Procedure/{$Radiation_Therapy_ID}"/>
                        </partOf>
                        <xsl:choose>
                            <xsl:when test="./ST_Ende_Datum">
                                <xsl:choose>
                                    <xsl:when test="ST_Ende_Grund='E'">
                                        <status value="completed" />
                                    </xsl:when>
                                    <xsl:when test="ST_Ende_Grund='U'">
                                        <status value="unknown" />
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <status value="stopped" />
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:choose>
                                    <xsl:when test="./ST_Beginn_Datum">
                                        <status value="in-progress" />
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <status value="preparation" />
                                    </xsl:otherwise>
                                </xsl:choose>
                            </xsl:otherwise>
                        </xsl:choose>
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
                        <xsl:if test="./ST_Beginn_Datum or ./ST_Ende_Datum">
                            <performedPeriod>
                                <xsl:if test="./ST_Beginn_Datum"><start value="{mds2fhir:transformDate(./ST_Beginn_Datum)}" /></xsl:if>
                                <xsl:if test="./ST_Ende_Datum"><end value="{mds2fhir:transformDate(./ST_Ende_Datum)}" /></xsl:if>
                            </performedPeriod>
                        </xsl:if>
                        <reasonReference>
                            <reference  value="Condition/{$Diagnosis_ID}" />
                        </reasonReference>
                    </Procedure>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Procedure/{$Single_Radiation_Therapy_ID}" />
                </request>
            </entry>
        </xsl:for-each>

    </xsl:template>

    <xsl:template match="OP">
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />

        <xsl:variable name="OP_ID" select="mds2fhir:getID(./@OP_ID, '', generate-id())" as="xs:string" />
        
        <entry>
            <fullUrl value="http://example.com/Procedure/{$OP_ID}" />
            <resource>
                <Procedure>
                    <id value="{$OP_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Operation" />
                    </meta>
                    <xsl:if test="./Intention_OP">
                    <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-OPIntention">
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/OPIntentionCS" />
                                <code value="{./Intention_OP}" />
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
                    <code>
                        <xsl:for-each select="./OP_OPS">
                            <coding>
                                <system value="http://fhir.de/CodeSystem/bfarm/ops" />
                                <xsl:if test="../../OP_OPS_Version">
                                <version value="{../../OP_OPS_Version}"/>
                            </xsl:if>
                                <code value="{.}" />
                            </coding>
                        </xsl:for-each>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <xsl:if test="./OP_Datum"><performedDateTime value="{mds2fhir:transformDate(./OP_Datum)}" /></xsl:if>
                    <reasonReference>
                        <reference value="Condition/{$Diagnosis_ID}" />
                    </reasonReference>
                    <xsl:if test="./Lokale_Beurteilung_Resttumor or ./Gesamtbeurteilung_Resttumor">
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
                    </xsl:if>
                </Procedure>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Procedure/{$OP_ID}" />
            </request>
        </entry>

        <xsl:apply-templates select="./Histology">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>

        <xsl:apply-templates select="./TNM">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>

    </xsl:template>

    <xsl:template match="Verlauf">
        <xsl:param name="Tumor_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="Progress_ID" select="mds2fhir:getID(./@Verlauf_ID, '', generate-id())" as="xs:string" />
        <xsl:variable name="Lym_Rezidiv_ID"><xsl:if test="./Lymphknoten-Rezidiv"><xsl:value-of select="hash:hash($Progress_ID, ./Lymphknoten-Rezidiv, 'yrz')"/></xsl:if></xsl:variable>
        <xsl:variable name="Fernmetastasen_ID"><xsl:if test="./Fernmetastasen"><xsl:value-of select="hash:hash($Progress_ID, ./Fernmetastasen, 'fmn')"/></xsl:if></xsl:variable>
        <xsl:variable name="Lokales_Rezidiv_ID"><xsl:if test="./Lokales-regionäres_Rezidiv"><xsl:value-of select="hash:hash($Progress_ID, ./Lokales-regionäres_Rezidiv, 'krz')"/></xsl:if></xsl:variable>
        <xsl:variable name="Ansprechen_ID"><xsl:if test="./Ansprechen_im_Verlauf"><xsl:value-of select="hash:hash($Progress_ID, ./Ansprechen_im_Verlauf, 'asp')"/></xsl:if></xsl:variable>

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
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <xsl:if test="./Datum_Verlauf"><effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" /></xsl:if>
<!--                    TODO Todesursache + Tumorbedingt-->
                    <problem>
                        <reference value="Condition/{$Diagnosis_ID}" />
                    </problem>
                    <xsl:for-each select="./TNM">
                    <finding>
                        <itemReference>
                            <reference value="Observation/{mds2fhir:getID(./@TNM_ID, mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund), generate-id())}" />
                        </itemReference>
                    </finding>
                </xsl:for-each>
                <xsl:for-each select="./Histology">
                    <finding>
                        <itemReference>
                            <reference value="Observation/{mds2fhir:getID(./@Histology_ID, mds2fhir:transformDate(./Tumor_Histologiedatum), generate-id())}" />
                        </itemReference>
                    </finding>
                </xsl:for-each>
                <xsl:for-each select="./Metastasis">
                    <finding>
                        <itemReference>
                            <reference value="Observation/{mds2fhir:getID(./@Metastasis_ID, mds2fhir:transformDate(./Datum_diagnostische_Sicherung), generate-id())}" />
                        </itemReference>
                    </finding>
                </xsl:for-each>
            <xsl:if test="$Lokales_Rezidiv_ID != ''">
                <finding>
                    <itemReference>
                        <reference value="Observation/{$Lokales_Rezidiv_ID}" />
                    </itemReference>
                </finding>
            </xsl:if>
            <xsl:if test="$Lym_Rezidiv_ID != ''">
                <finding>
                    <itemReference>
                        <reference value="Observation/{$Lym_Rezidiv_ID}" />
                    </itemReference>
                </finding>
            </xsl:if>
            <xsl:if test="$Fernmetastasen_ID != ''">
                <finding>
                    <itemReference>
                        <reference value="Observation/{$Fernmetastasen_ID}" />
                    </itemReference>
                </finding>
            </xsl:if>
            <xsl:if test="$Ansprechen_ID != ''">
                <finding>
                    <itemReference>
                        <reference value="Observation/{$Ansprechen_ID}" />
                    </itemReference>
                </finding>
            </xsl:if>
                </ClinicalImpression>
            </resource>
            <request>
                <method value="PUT" />
                <url value="ClinicalImpression/{$Progress_ID}" />
            </request>
        </entry>
        <xsl:if test="./Lokales-regionäres_Rezidiv">
            <entry>
                <fullUrl value="http://example.com/Observation/{$Lokales_Rezidiv_ID}" />
                <resource>
                    <Observation xmlns="http://hl7.org/fhir">
                        <id value="{$Lokales_Rezidiv_ID}" />
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-LokalerTumorstatus" />
                        </meta>
                        <status value="final" />
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="LA4583-6" />
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}" />
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <xsl:if test="./Datum_Verlauf"><effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" /></xsl:if>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufLokalerTumorstatusCS" />
                                <code value="{./Lokales-regionäres_Rezidiv}" />
                            </coding>
                        </valueCodeableConcept>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Observation/{$Lokales_Rezidiv_ID}" />
                </request>
            </entry>
        </xsl:if>
        <xsl:if test="./Lymphknoten-Rezidiv">
            <entry>
                <fullUrl value="http://example.com/Observation/{$Lym_Rezidiv_ID}" />
                <resource>
                    <Observation xmlns="http://hl7.org/fhir">
                        <id value="{$Lym_Rezidiv_ID}" />
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TumorstatusLymphknoten" />
                        </meta>
                        <status value="final" />
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="LA4370-8" />
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}" />
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <xsl:if test="./Datum_Verlauf"><effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" /></xsl:if>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufTumorstatusLymphknotenCS" />
                                <code value="{./Lymphknoten-Rezidiv}" />
                            </coding>
                        </valueCodeableConcept>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Observation/{$Lym_Rezidiv_ID}" />
                </request>
            </entry>
        </xsl:if>
        <xsl:if test="./Fernmetastasen">
            <entry>
                <fullUrl value="http://example.com/Observation/{$Fernmetastasen_ID}" />
                <resource>
                    <Observation xmlns="http://hl7.org/fhir">
                        <id value="{$Fernmetastasen_ID}" />
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TumorstatusFernmetastasen" />
                        </meta>
                        <status value="final" />
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="LA4226-2" />
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}" />
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <xsl:if test="./Datum_Verlauf"><effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" /></xsl:if>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufTumorstatusFernmetastasenCS" />
                                <code value="{./Fernmetastasen}" />
                            </coding>
                        </valueCodeableConcept>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Observation/{$Fernmetastasen_ID}" />
                </request>
            </entry>
        </xsl:if>
        <xsl:if test="./Ansprechen_im_Verlauf">
            <entry>
                <fullUrl value="http://example.com/Observation/{$Ansprechen_ID}" />
                <resource>
                    <Observation xmlns="http://hl7.org/fhir">
                        <id value="{$Ansprechen_ID}" />
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-GesamtbeurteilungTumorstatus" />
                        </meta>
                        <status value="final" />
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="21976-6" />
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}" />
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <xsl:if test="./Datum_Verlauf"><effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" /></xsl:if>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungTumorstatusCS" />
                                <code value="{./Ansprechen_im_Verlauf}" />
                            </coding>
                        </valueCodeableConcept>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Observation/{$Ansprechen_ID}" />
                </request>
            </entry>
        </xsl:if>
        <xsl:apply-templates select="./Histology">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>

        <xsl:apply-templates select="./TNM">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>

        <xsl:apply-templates select="./Metastasis">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
            <xsl:with-param name="Datum_Verlauf" select="./Datum_Verlauf" />
        </xsl:apply-templates>

    </xsl:template>


    <xsl:template match="TNM">
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="TNM_ID" select="mds2fhir:getID(./@TNM_ID, mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund), generate-id())" as="xs:string" />

        <entry>
            <fullUrl value="http://example.com/Observation/{$TNM_ID}" />
            <resource>
                <Observation>
                    <id value="{$TNM_ID}" />
                    <meta>
                        <xsl:choose>
                            <xsl:when test="./gesamtpraefix='p' or ./c-p-u-Präfix_T='p' or ./c-p-u-Präfix_N='p' or ./c-p-u-Präfix_M='p'">
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TNMp" />
                            </xsl:when>
                            <xsl:otherwise>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TNMc" />
                            </xsl:otherwise>
                        </xsl:choose>
                    </meta>
                    <status value="final" />
                    <code>
                        <xsl:choose>
                            <xsl:when test="./gesamtpraefix='p' or ./c-p-u-Präfix_T='p' or ./c-p-u-Präfix_N='p' or ./c-p-u-Präfix_M='p'">
                                <coding>
                                    <system value="http://loinc.org" />
                                    <code>
                                        <xsl:attribute name="value">21902-2</xsl:attribute>
                                    </code>
                                </coding>
                            </xsl:when>
                            <xsl:when test="./gesamtpraefix='c' or ./c-p-u-Präfix_T='c' or ./c-p-u-Präfix_N='c' or ./c-p-u-Präfix_M='c'">
                                <coding>
                                    <system value="http://loinc.org" />
                                    <code>
                                        <xsl:attribute name="value">21908-9</xsl:attribute>
                                    </code>
                                </coding>
                            </xsl:when>
                            <xsl:otherwise>
                                <text value= "TNM ohne Angabe ob klinisch oder pthologisch"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <focus>
                        <reference value="Condition/{$Diagnosis_ID}"/>
                    </focus>
                    <xsl:if test="./Datum_der_TNM-Dokumentation-Datum_Befund"><effectiveDateTime value="{mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund)}" /></xsl:if>
                    <xsl:if test="./UICC_Stadium">
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/UiccstadiumCS" />
                                <xsl:if test="./TNM-Version">
                                    <version value="{./TNM-Version}"/>
                                </xsl:if>
                                <code value="{./UICC_Stadium}" />
                            </coding>
                        </valueCodeableConcept>
                    </xsl:if>
                    <xsl:if test="./TNM-T">
                        <component>
                            <xsl:if test="./c-p-u-Präfix_T">
                                <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-TNMcpuPraefix">
                                    <valueCodeableConcept>
                                        <coding>
                                            <code value="{./c-p-u-Präfix_T}" />
                                        </coding>
                                    </valueCodeableConcept>
                                </extension>
                                <extension></extension>
                            </xsl:if>
                            <code>
                                <coding>
                                    <system value="http://loinc.org" />
                                    <code>
                                        <xsl:choose>
                                            <xsl:when test="./c-p-u-Präfix_T='p'">
                                                <xsl:attribute name="value">21899-0</xsl:attribute>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:attribute name="value">21905-5</xsl:attribute>
                                            </xsl:otherwise>
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
                    </xsl:if>
                    <xsl:if test="./TNM-N">
                        <component>
                            <xsl:if test="./c-p-u-Präfix_N">
                                <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-TNMcpuPraefix">
                                    <valueCodeableConcept>
                                        <coding>
                                            <code value="{./c-p-u-Präfix_N}" />
                                        </coding>
                                    </valueCodeableConcept>
                                </extension>
                                <extension></extension>
                            </xsl:if>
                            <code>
                                <coding>
                                    <system value="http://loinc.org" />
                                    <code>
                                        <xsl:choose>
                                            <xsl:when test="./c-p-u-Präfix_N='p'">
                                                <xsl:attribute name="value">21900-6</xsl:attribute>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:attribute name="value">21906-3</xsl:attribute>
                                            </xsl:otherwise>
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
                    </xsl:if>
                    <xsl:if test="./TNM-M">
                        <component>
                            <xsl:if test="./c-p-u-Präfix_M">
                                <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-TNMcpuPraefix">
                                    <valueCodeableConcept>
                                        <coding>
                                            <code value="{./c-p-u-Präfix_M}" />
                                        </coding>
                                    </valueCodeableConcept>
                                </extension>
                                <extension></extension>
                            </xsl:if>
                            <code>
                                <coding>
                                    <system value="http://loinc.org" />
                                    <code>
                                        <xsl:choose>
                                            <xsl:when test="./c-p-u-Präfix_M='p'">
                                                <xsl:attribute name="value">21901-4</xsl:attribute>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:attribute name="value">21907-1</xsl:attribute>
                                            </xsl:otherwise>
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
                    </xsl:if>
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
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMmSymbolCS" />
                                    <code value="{./TNM-m-Symbol}"/>
                                </coding>
                            </valueCodeableConcept>
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
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:param name="Datum_Verlauf"/>

        <xsl:variable name="Metastasis_ID" select="mds2fhir:getID(./@Metastasis_ID, mds2fhir:transformDate(./Datum_diagnostische_Sicherung), generate-id())" as="xs:string" />
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
                    <focus>
                        <reference value="Condition/{$Diagnosis_ID}"/>
                    </focus>
                    <xsl:choose>
                        <xsl:when test="./FM_Diagnosedatum"><effectiveDateTime value="{mds2fhir:transformDate(./FM_Diagnosedatum)}" /></xsl:when>
                        <xsl:when test="$Datum_Verlauf"><effectiveDateTime value="{mds2fhir:transformDate($Datum_Verlauf)}" /></xsl:when>
                    </xsl:choose>
                    <xsl:if test="./Fernmetastasen_vorhanden">
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/JNUCS" />
                            <xsl:choose>
                                <xsl:when test="./Fernmetastasen_vorhanden = 'nicht erfasst'">
                                <code value="U" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <code value="{./Fernmetastasen_vorhanden}" />
                                 </xsl:otherwise>
                            </xsl:choose>
                        </coding>
                    </valueCodeableConcept>
                </xsl:if>
                <xsl:if test="./Lokalisation_Fernmetastasen">
                    <bodySite>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/FMLokalisationCS" />
                            <code value="{./Lokalisation_Fernmetastasen}" />
                        </coding>
                    </bodySite>
                    </xsl:if>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Metastasis_ID}" />
            </request>
        </entry>
    </xsl:template>


    <xsl:template match="Histology">
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />

        <xsl:variable name="Histology_ID" select="mds2fhir:getID(./@Histology_ID, mds2fhir:transformDate(./Tumor_Histologiedatum), generate-id())" as="xs:string" />
        <xsl:variable name="Grading_ID" select="mds2fhir:getID(hash:hash($Patient_ID, ./@Histology_ID,'grading'), '', generate-id())" as="xs:string"/>

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
                    <focus>
                        <reference value="Condition/{$Diagnosis_ID}"/>
                    </focus>
                    <xsl:if test="./Tumor_Histologiedatum"><effectiveDateTime value="{mds2fhir:transformDate(./Tumor_Histologiedatum)}" /></xsl:if>
                    <valueCodeableConcept>
                        <coding>
                            <system value="urn:oid:2.16.840.1.113883.6.43.1" />
                            <xsl:if test="./ICD-O_Katalog_Morphologie_Version"><version value="{./ICD-O_Katalog_Morphologie_Version}" /></xsl:if>
                            <xsl:if test="./Morphologie"><code value="{./Morphologie}" /></xsl:if>
                        </coding>
                        <xsl:if test="./Morphologie_Freitext"><text value="{./Morphologie_Freitext}" /></xsl:if>
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
                    <focus>
                        <reference value="Condition/{$Diagnosis_ID}"/>
                    </focus>
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GradingCS" />
                            <xsl:if test="./Grading"><code value="{./Grading}" /></xsl:if>
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
        <xsl:variable name="Tumor_ID" select="mds2fhir:getID(./@Tumor_ID, '', generate-id())" as="xs:string" />

        <xsl:apply-templates select="./Histology">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>

        <xsl:apply-templates select="./Metastasis">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>


        <xsl:apply-templates select="./TNM">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>

        <xsl:apply-templates select="./OP">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./ST">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./SYST">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>


        <xsl:apply-templates select="./Verlauf">
            <xsl:with-param name="Tumor_ID" select="$Tumor_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>
    </xsl:template>




    <!-- Funktionen -->
    <!-- Generate Id if non exists. If possible, include some releated date to avoid collision & improve indexing. -->
    <xsl:function name="mds2fhir:getID">
        <xsl:param name="id" />
        <xsl:param name="date"/>
        <xsl:param name="prefix" />

        <xsl:sequence select="
            if ($id and $id != '') then
               $id
            else 
                if ($date and $date != '') then
                    concat($date,'-', $prefix)
                else $prefix
			" />
    </xsl:function>


    <xsl:function name="mds2fhir:transformDate">
        <xsl:param name="date" />
        <xsl:variable name="fixedDate" select="mds2fhir:autocorrectDate($date)"/>
        <xsl:variable name="day" select="substring($fixedDate, 1,2)" as="xs:string" />
        <xsl:variable name="month" select="substring($fixedDate, 4, 2)" as="xs:string" />
        <xsl:variable name="year" select="substring($fixedDate, 7, 4)" as="xs:string" />
        <xsl:choose>
            <xsl:when test="$day='00'">
                <xsl:choose>
                    <xsl:when test="$month='00'">
                        <xsl:value-of select="$year" />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat($year,'-',$month)" />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($year,'-',$month,'-',$day)" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:autocorrectDate">
        <xsl:param name="date"/>
        <xsl:choose>
            <xsl:when test="matches($date, '^\d{4}')">
                <xsl:value-of select="concat('00.00.', $date)"/>
            </xsl:when>
            <xsl:when test="matches($date, '^\d{2}\.\d{4}')">
                <xsl:value-of select="concat('00.', $date)"/>
            </xsl:when>
            <xsl:when test="matches($date, '^\d{2}\.\d{2}\.\d{4}')">
                <xsl:value-of select="$date"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes">ERROR: wrong date format:
                    <xsl:value-of select="$date"/>
                </xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:getVersionYear">
        <xsl:param name="version" />
        <xsl:value-of select="substring($version, 4, 4)" />
    </xsl:function>

    <xsl:function name="mds2fhir:getICDType">
        <xsl:param name="version" />
        <xsl:choose>
            <xsl:when test="contains($version,'GM')">http://fhir.de/CodeSystem/bfarm/icd-10-gm</xsl:when>
            <xsl:when test="contains($version,'WHO')">http://hl7.org/fhir/sid/icd-10</xsl:when>
        </xsl:choose>
    </xsl:function>


</xsl:stylesheet>