<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xsl:stylesheet xmlns="http://hl7.org/fhir"
                xmlns:mds2fhir="https://github.com/samply/obds2fhir/blob/main/MDS_FHIR2FHIR"
                xmlns:dktk="http://dktk.dkfz.de"
                xmlns:saxon="http://saxon.sf.net"
                xmlns:xalan="http://xml.apache.org/xalan"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:hash="java:de.samply.obds2fhir"
                exclude-result-prefixes="xs xsi dktk saxon xalan mds2fhir #default"
                version="2.0"
                xpath-default-namespace="http://www.mds.de/namespace">

    <xsl:param name="identifier_system"/>
    <xsl:variable name="Lokal_DKTK_ID_Pat_System">
        <xsl:value-of select="$identifier_system"/>
    </xsl:variable>
    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    <xsl:output omit-xml-declaration="yes" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:param name="filepath"/>
    <xsl:param name="customPrefix"/>

    <xsl:template match="/">
        <xsl:param name="Patient_ID" select="Patienten/@Patient_ID"/>
        <xsl:variable name="root" select="/"/>
        <xsl:apply-templates select="Patienten/Patient" mode="patient"/>
    </xsl:template>

    <xsl:template match="Patient" mode="patient">
        <xsl:variable name="Patient_ID" select="@Patient_ID"/>
        <xsl:result-document href="file:{$filepath}/tmp/FHIR_Patients/FHIR_{$customPrefix}">
            <Bundle xmlns="http://hl7.org/fhir">
                <id value="{substring($customPrefix, 9, 16)}"/>
                <type value="transaction"/>
                <xsl:if test="Geschlecht!='' and Geburtsdatum!=''">
                    <entry>
                        <fullUrl value="http://example.com/Patient/{$Patient_ID}"/>
                        <resource>
                            <Patient>
                                <id value="{$Patient_ID}"/>
                                <meta>
                                    <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Patient-Patient"/>
                                </meta>
                                <xsl:if test="DKTK_LOCAL_ID!=''">
                                    <identifier>
                                        <type>
                                            <coding>
                                                <system value="{$Lokal_DKTK_ID_Pat_System}"/>
                                                <code value="Lokal"/>
                                            </coding>
                                        </type>
                                        <value value="{DKTK_LOCAL_ID}"/>
                                    </identifier>
                                </xsl:if>
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
                                <xsl:if test="Geburtsdatum!=''">
                                    <birthDate value="{mds2fhir:transformDate(./Geburtsdatum)}"/>
                                </xsl:if>
                            </Patient>
                        </resource>
                        <request>
                            <method value="PUT"/>
                            <xsl:if test="not(DKTK_LOCAL_ID!='')">
                                <ifNoneMatch value="*"/>
                            </xsl:if>
                            <url value="Patient/{$Patient_ID}"/>
                        </request>
                    </entry>
                </xsl:if>
                <!-- Patienten > Patient > Sample -->
                <xsl:apply-templates select="./Sample" mode="sample">
                    <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                </xsl:apply-templates>
                <!-- Patienten > Patient > Diagnose -->
                <xsl:apply-templates select="./Diagnosis" mode="diagnosis">
                    <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                </xsl:apply-templates>
            </Bundle>
        </xsl:result-document>

        <xsl:if test="Vitalstatus_Gesamt/Datum_des_letztbekannten_Vitalstatus!='' or Vitalstatus_Gesamt/Tod!='' or Organisationen/Abteilung!=''">
            <xsl:result-document href="file:{$filepath}/tmp/FHIR_Patients/FHIR_batch_{$customPrefix}">
                <Bundle xmlns="http://hl7.org/fhir">
                    <id value="{substring($customPrefix, 9, 16)}"/>
                    <type value="batch"/>
                    <xsl:apply-templates select="Vitalstatus_Gesamt">
                        <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                    </xsl:apply-templates>

                    <xsl:for-each select="Organisationen/Abteilung[.!='']">
                        <xsl:variable name="Encounter_ID" select="hash:hash($Patient_ID, ., '')"/>
                        <entry>
                            <fullUrl value="http://example.com/Encounter/{$Encounter_ID}"/>
                            <resource>
                                <Encounter>
                                    <id value="{$Encounter_ID}"/>
                                    <meta>
                                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Encounter-Fall"/>
                                    </meta>
                                    <identifier>
                                        <system value="http://dktk.dkfz.de/fhir/sid/hki-department"/>
                                        <value value="{.}"/>
                                    </identifier>
                                    <status value="finished"/>
                                    <class>
                                        <system value="http://terminology.hl7.org/CodeSystem/v3-ActCode"/>
                                        <code value="VR"/>
                                        <display value="virtual"/>
                                    </class>
                                    <subject>
                                        <reference value="Patient/{$Patient_ID}"/>
                                    </subject>
                                </Encounter>
                            </resource>
                            <request>
                                <method value="PUT"/>
                                <ifNoneMatch value="*"/>
                                <url value="Encounter/{$Encounter_ID}"/>
                            </request>
                        </entry>
                    </xsl:for-each>
                </Bundle>
            </xsl:result-document>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Sample" mode="sample">
        <xsl:param name="Patient_ID" select="../@Patient_ID"/>
        <xsl:variable name="Sample_ID" select="@Sample_ID"/>
        <xsl:if test="Probentyp!=''">
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
                                        <xsl:when test="lower-case(normalize-space(Probentyp)) = 'gewebeprobe'">
                                            <xsl:choose>
                                                <xsl:when test="starts-with(lower-case(normalize-space(Fixierungsart)), 'kryo') or starts-with(lower-case(normalize-space(Probenart)), 'frisch')">
                                                    <xsl:attribute name="value">tissue-frozen</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="starts-with(lower-case(normalize-space(Fixierungsart)), 'paraffin')">
                                                    <xsl:attribute name="value">tissue-ffpe</xsl:attribute>
                                                </xsl:when>
                                                <xsl:otherwise>
                                                    <xsl:attribute name="value">tissue-other</xsl:attribute>
                                                </xsl:otherwise>
                                            </xsl:choose>
                                        </xsl:when>
                                        <xsl:when test="lower-case(normalize-space(Probentyp)) = 'flüssigprobe'">
                                            <xsl:choose>
                                                <xsl:when test="lower-case(normalize-space(Probenart)) = 'vollblut'">
                                                    <xsl:attribute name="value">whole-blood</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="ends-with(lower-case(normalize-space(Probenart)), 'serum')">
                                                    <xsl:attribute name="value">blood-serum</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="starts-with(lower-case(normalize-space(Probenart)), 'plasma')">
                                                    <xsl:attribute name="value">blood-plasma</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="starts-with(lower-case(normalize-space(Probenart)), 'urin')">
                                                    <xsl:attribute name="value">urine</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="ends-with(lower-case(normalize-space(Probenart)), 'liquor')">
                                                    <xsl:attribute name="value">csf-liquor</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="starts-with(lower-case(normalize-space(Probenart)), 'knochenmark')">
                                                    <xsl:attribute name="value">bone-marrow</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="ends-with(lower-case(normalize-space(Probenart)), 'dna')">
                                                    <xsl:attribute name="value">dna</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="ends-with(lower-case(normalize-space(Probenart)), 'rna')">
                                                    <xsl:attribute name="value">rna</xsl:attribute>
                                                </xsl:when>
                                                <xsl:when test="lower-case(normalize-space(Probenart)) = 'protein'">
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
                        <xsl:if test="Entnahmedatum!=''">
                            <collection>
                                <collectedDateTime value="{mds2fhir:transformDate(Entnahmedatum)}"/>
                            </collection>
                        </xsl:if>
                    </Specimen>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Specimen/{$Sample_ID}"/>
                </request>
            </entry>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Diagnosis" mode="diagnosis">
        <xsl:param name="Patient_ID" select="../@Patient_ID"/>
        <xsl:variable name="Diagnosis_ID" select="./@Diagnosis_ID"/>
        <xsl:if test="Diagnose!='' and Tumor_Diagnosedatum !=''">
            <entry>
                <fullUrl value="http://example.com/Condition/{$Diagnosis_ID}"/>
                <resource>
                    <Condition xmlns="http://hl7.org/fhir">
                        <id value="{$Diagnosis_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Condition-Primaerdiagnose"/>
                        </meta>
                        <xsl:for-each select="Tumor/Metastasis[.!='']">
                            <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-Fernmetastasen">
                                <valueReference>
                                    <reference value="Observation/{@Metastasis_ID}"/>
                                </valueReference>
                            </extension>
                        </xsl:for-each>
                        <code>
                            <coding>
                                <xsl:if test="ICD-Katalog_Version!=''">
                                    <xsl:choose>
                                        <xsl:when test="ICD-Katalog_Version = 'Sonstige'">
                                            <system value="Sonstige"/>
                                            <version value="Sonstige"/>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <system value="{mds2fhir:getICDType(./ICD-Katalog_Version)}"/>
                                            <version value="{mds2fhir:getVersionYear(./ICD-Katalog_Version)}"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:if>
                                <code value="{./Diagnose}"/>
                            </coding>
                            <xsl:if test="Diagnose_Text != ''">
                                <text value="{mds2fhir:fix-free-text(Diagnose_Text)}"/>
                            </xsl:if>
                        </code>
                        <bodySite>
                            <coding>
                                <system value="urn:oid:2.16.840.1.113883.6.43.1"/>
                                <xsl:if test="Tumor/ICD-O_Katalog_Topographie_Version!=''">
                                    <version value="{./Tumor/ICD-O_Katalog_Topographie_Version}"/>
                                </xsl:if>
                                <xsl:if test="Tumor/Lokalisation!=''">
                                    <code value="{./Tumor/Lokalisation}"/>
                                </xsl:if>
                                <xsl:if test="Primaertumor_Topographie_Freitext != ''">
                                    <display value="{mds2fhir:fix-free-text(Primaertumor_Topographie_Freitext)}"/>
                                </xsl:if>
                            </coding>
                            <xsl:if test="Tumor/Seitenlokalisation!=''">
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SeitenlokalisationCS"/>
                                    <code value="{./Tumor/Seitenlokalisation}"/>
                                </coding>
                            </xsl:if>
                        </bodySite>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <onsetDateTime value="{mds2fhir:transformDateBlazebug(./Tumor_Diagnosedatum)}"/>
                        <recordedDate value="{mds2fhir:transformDateBlazebug(./Tumor_Diagnosedatum)}"/>
                        <xsl:for-each select="Tumor/TNM[.!='']">
                            <xsl:if test="Datum !=''">
                                <stage>
                                    <assessment>
                                        <reference value="Observation/{mds2fhir:getID(./@TNM_ID, mds2fhir:transformDate(Datum), generate-id())}"/>
                                    </assessment>
                                </stage>
                            </xsl:if>
                        </xsl:for-each>
                        <xsl:if test="Diagnosesicherung!='' or Tumor/Histology!='' or Tumor/Genetische_Variante!=''">
                            <evidence>
                                <xsl:if test="Diagnosesicherung!=''">
                                    <code>
                                        <coding>
                                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/DiagnosesicherungCS"/>
                                            <code value="{Diagnosesicherung}"/>
                                        </coding>
                                    </code>
                                </xsl:if>
                                <xsl:for-each select="Tumor/Histology[.!=''] | Tumor/Genetische_Variante[.!='']">
                                    <xsl:if test="Tumor_Histologiedatum !=''">
                                        <detail>
                                            <reference value="Observation/{@Histology_ID}"/>
                                        </detail>
                                    </xsl:if>
                                    <xsl:if test="Bezeichnung !=''">
                                        <detail>
                                            <reference value="Observation/{@Gen_ID}"/>
                                        </detail>
                                    </xsl:if>
                                </xsl:for-each>
                            </evidence>
                        </xsl:if>
                    </Condition>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Condition/{$Diagnosis_ID}"/>
                </request>
            </entry>
        </xsl:if>
        <xsl:apply-templates select="ECOG">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="Weitere_Klassifikation">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="./Tumor" mode="tumor">
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="SYST">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:if test="./Systemische_Therapie_Beginn !=''">
            <xsl:variable name="System_Therapy_ID" select="mds2fhir:getID(./@SYST_ID, mds2fhir:transformDate(./Systemische_Therapie_Beginn), generate-id())" as="xs:string"/>
            <entry>
                <fullUrl value="http://example.com/MedicationStatement/{$System_Therapy_ID}"/>
                <resource>
                    <MedicationStatement>
                        <id value="{$System_Therapy_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-MedicationStatement-Systemtherapie"/>
                        </meta>
                        <xsl:choose>
                            <xsl:when test="Systemische_Therapie_Stellung_zu_operativer_Therapie!=''"><!--legacy mapping-->
                                <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                                    <valueCodeableConcept>
                                        <coding>
                                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS"/>
                                            <code value="{Systemische_Therapie_Stellung_zu_operativer_Therapie}"/>
                                        </coding>
                                    </valueCodeableConcept>
                                </extension>
                            </xsl:when>
                            <xsl:when test="Stellung_OP!=''"><!--oBDS-->
                                <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                                    <valueCodeableConcept>
                                        <coding>
                                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS"/>
                                            <code value="{Stellung_OP}"/>
                                        </coding>
                                    </valueCodeableConcept>
                                </extension>
                            </xsl:when>
                        </xsl:choose>
                        <xsl:choose>
                            <xsl:when test="Intention_Chemotherapie!=''"><!--legacy mapping-->
                                <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SYSTIntention">
                                    <valueCodeableConcept>
                                        <coding>
                                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTIntentionCS"/>
                                            <code value="{Intention_Chemotherapie}"/>
                                        </coding>
                                    </valueCodeableConcept>
                                </extension>
                            </xsl:when>
                            <xsl:when test="Intention!=''"><!--oBDS-->
                                <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SYSTIntention">
                                    <valueCodeableConcept>
                                        <coding>
                                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTIntentionCS"/>
                                            <code value="{Intention}"/>
                                        </coding>
                                    </valueCodeableConcept>
                                </extension>
                            </xsl:when>
                        </xsl:choose>
                        <xsl:if test="Lokale_Beurteilung_Resttumor!=''">
                            <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-LokaleResidualstatus">
                                <valueReference>
                                    <reference value="Observation/{mds2fhir:getID(hash:hash($Patient_ID, $Diagnosis_ID , concat(./Lokale_Beurteilung_Resttumor, $System_Therapy_ID, 'lokal')),'', generate-id(./Lokale_Beurteilung_Resttumor))}"/>
                                </valueReference>
                            </extension>
                        </xsl:if>
                        <xsl:if test="Gesamtbeurteilung_Resttumor!=''">
                            <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-GesamtbeurteilungResidualstatus">
                                <valueReference>
                                    <reference value="Observation/{mds2fhir:getID(hash:hash($Patient_ID, $Diagnosis_ID , concat(./Gesamtbeurteilung_Resttumor, $System_Therapy_ID, 'gesamt')),'', generate-id(./Gesamtbeurteilung_Resttumor))}"/>
                                </valueReference>
                            </extension>
                        </xsl:if>
                        <xsl:if test="Systemische_Therapie_Protokoll!=''">
                            <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SystemischeTherapieProtokoll">
                                <valueCodeableConcept>
                                    <text value="{mds2fhir:fix-free-text(Systemische_Therapie_Protokoll)}"/>
                                </valueCodeableConcept>
                            </extension>
                        </xsl:if>
                        <status>
                            <xsl:attribute name="value">
                                <xsl:value-of select="mds2fhir:getMedicationStatementTreatmentStatus(Meldeanlass,SYST_Ende_Grund)"/>
                            </xsl:attribute>
                        </status>
                        <xsl:if test="Therapieart!=''">
                            <category>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS"/>
                                    <code value="{Therapieart}"/>
                                    <xsl:if test="Therapieart_original!=''">
                                        <display value="{Therapieart_original}"/>
                                    </xsl:if>
                                </coding>
                            </category>
                        </xsl:if>
                        <medicationCodeableConcept>
                            <!--<xsl:for-each select="SYST_Substanz[normalize-space(.)!='' or .='/']">
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTSubstanzCS"/>
                                    <code value="{mds2fhir:fix-free-text(.)}"/>
                                </coding>
                            </xsl:for-each>TODO add later-->
                            <xsl:for-each select="SYST_Substanz-ATC[Code!='']">
                                <coding>
                                    <system value="http://fhir.de/CodeSystem/bfarm/atc"/>
                                    <xsl:if test="Version!=''">
                                        <version value="{Version}"/>
                                    </xsl:if>
                                    <code value="{Code}"/>
                                </coding>
                            </xsl:for-each>
                            <xsl:choose>
                                <xsl:when test="SYST_Substanz!=''">
                                    <text>
                                        <xsl:attribute name="value">
                                            <xsl:value-of select="string-join(SYST_Substanz, ';')"/>
                                        </xsl:attribute>
                                    </text>
                                </xsl:when>
                                <xsl:otherwise>
                                    <text value="Keine Angabe zur Substanz"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </medicationCodeableConcept>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <xsl:if test="Systemische_Therapie_Beginn!='' or Systemische_Therapie_Ende!=''">
                            <effectivePeriod>
                                <xsl:if test="Systemische_Therapie_Beginn!=''">
                                    <start value="{mds2fhir:transformDate(./Systemische_Therapie_Beginn)}"/>
                                </xsl:if>
                                <xsl:if test="Systemische_Therapie_Ende!=''">
                                    <end value="{mds2fhir:transformDate(./Systemische_Therapie_Ende)}"/>
                                </xsl:if>
                            </effectivePeriod>
                        </xsl:if>
                        <reasonReference>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </reasonReference>
                    </MedicationStatement>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="MedicationStatement/{$System_Therapy_ID}"/>
                </request>
            </entry>

            <xsl:apply-templates select="Nebenwirkung[Grad!='']">
                <xsl:with-param name="Parent_Ressource" select="concat('MedicationStatement/',$System_Therapy_ID)"/>
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            </xsl:apply-templates>

            <xsl:if test="Gesamtbeurteilung_Resttumor!=''">
                <entry>
                    <xsl:variable name="Gesamtbeurteilung_Resttumor_ID" select="mds2fhir:getID(hash:hash($Patient_ID, $Diagnosis_ID , concat(./Gesamtbeurteilung_Resttumor, $System_Therapy_ID, 'gesamt')),'', generate-id(./Gesamtbeurteilung_Resttumor))"/>
                    <fullUrl value="http://example.com/Observation/{$Gesamtbeurteilung_Resttumor_ID}"/>
                    <resource>
                        <Observation xmlns="http://hl7.org/fhir">
                            <id value="{$Gesamtbeurteilung_Resttumor_ID}"/>
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-GesamtbeurteilungResidualstatus"/>
                            </meta>
                            <status value="final"/>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="81169-5"/>
                                </coding>
                            </code>
                            <subject>
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <focus>
                                <reference value="Condition/{$Diagnosis_ID}"/>
                            </focus>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungResidualstatusCS"/>
                                    <code value="{Gesamtbeurteilung_Resttumor}"/>
                                </coding>
                            </valueCodeableConcept>
                        </Observation>
                    </resource>
                    <request>
                        <method value="PUT"/>
                        <url value="Observation/{$Gesamtbeurteilung_Resttumor_ID}"/>
                    </request>
                </entry>
            </xsl:if>
            <xsl:if test="Lokale_Beurteilung_Resttumor!=''">
                <entry>
                    <xsl:variable name="Lokale_Beurteilung_Resttumor_ID" select="mds2fhir:getID(hash:hash($Patient_ID, $Diagnosis_ID , concat(./Lokale_Beurteilung_Resttumor, $System_Therapy_ID, 'lokal')),'', generate-id(./Lokale_Beurteilung_Resttumor))"/>
                    <fullUrl value="http://example.com/Observation/{$Lokale_Beurteilung_Resttumor_ID}"/>
                    <resource>
                        <Observation xmlns="http://hl7.org/fhir">
                            <id value="{$Lokale_Beurteilung_Resttumor_ID}"/>
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-LokaleBeurteilungResidualstatus"/>
                            </meta>
                            <status value="final"/>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="84892-9"/>
                                </coding>
                            </code>
                            <subject>
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <focus>
                                <reference value="Condition/{$Diagnosis_ID}"/>
                            </focus>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/LokaleBeurteilungResidualstatusCS"/>
                                    <code value="{Lokale_Beurteilung_Resttumor}"/>
                                </coding>
                            </valueCodeableConcept>
                        </Observation>
                    </resource>
                    <request>
                        <method value="PUT"/>
                        <url value="Observation/{$Lokale_Beurteilung_Resttumor_ID}"/>
                    </request>
                </entry>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template match="ST">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:variable name="Radiation_Therapy_ID" select="mds2fhir:getID(./@ST_ID,'', generate-id())" as="xs:string"/>
        <entry>
            <fullUrl value="http://example.com/Procedure/{$Radiation_Therapy_ID}"/>
            <resource>
                <Procedure>
                    <id value="{$Radiation_Therapy_ID}"/>
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Strahlentherapie"/>
                    </meta>
                    <xsl:if test="Stellung_OP!=''">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS"/>
                                    <code value="{Stellung_OP}"/>
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:if test="Intention!=''">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SYSTIntention">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTIntentionCS"/>
                                    <code value="{Intention}"/>
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <status>
                        <xsl:attribute name="value">
                            <xsl:value-of select="mds2fhir:getProcedureTreatmentStatus(Meldeanlass,Ende_Grund)"/>
                        </xsl:attribute>
                    </status>
                    <category>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS"/>
                            <code value="ST"/>
                            <display value="Strahlentherapie"/>
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
                        <reference value="Patient/{$Patient_ID}"/>
                    </subject>
                    <reasonReference>
                        <reference value="Condition/{$Diagnosis_ID}"/>
                    </reasonReference>
                    <xsl:if test="Ende_Grund!='' or Lokale_Beurteilung_Resttumor!='' or Gesamtbeurteilung_Resttumor!=''"><!--legacy ADT, not present in oBDS-->
                        <outcome>
                            <xsl:if test="Lokale_Beurteilung_Resttumor!=''">
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/LokaleBeurteilungResidualstatusCS"/>
                                    <code value="{./Lokale_Beurteilung_Resttumor}"/>
                                </coding>
                            </xsl:if>
                            <xsl:if test="Gesamtbeurteilung_Resttumor!=''">
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungResidualstatusCS"/>
                                    <code value="{Gesamtbeurteilung_Resttumor}"/>
                                </coding>
                            </xsl:if>
                            <xsl:if test="Ende_Grund!=''">
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/EndeGrundCS"/>
                                    <code value="{Ende_Grund}"/>
                                </coding>
                            </xsl:if>
                        </outcome>
                    </xsl:if>
                </Procedure>
            </resource>
            <request>
                <method value="PUT"/>
                <url value="Procedure/{$Radiation_Therapy_ID}"/>
            </request>
        </entry>

        <xsl:apply-templates select="Nebenwirkung[Grad!='']">
            <xsl:with-param name="Parent_Ressource" select="concat('Procedure/',$Radiation_Therapy_ID)"/>
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
        </xsl:apply-templates>

        <xsl:variable name="Radiation_Therapy_ID" select="mds2fhir:getID(./@ST_ID,'', generate-id())" as="xs:string"/>
        <xsl:for-each select="Bestrahlung[.!='']">
            <xsl:if test="Beginn_Datum !=''">
                <entry>
                    <fullUrl value="http://example.com/Procedure/{@Betrahlung_ID}"/>
                    <resource>
                        <Procedure>
                            <id value="{@Betrahlung_ID}"/>
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Strahlentherapie"/>
                            </meta>
                            <xsl:if test="Applikationsart!='' or Zielgebiet!='' or Seite_Zielgebiet!='' or Gesamtdosis/Dosis!='' or Einzeldosis/Dosis!='' or Boost!=''">
                                <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-Bestrahlung">
                                    <xsl:if test="Applikationsart!=''">
                                        <extension url="Applikationsart">
                                            <valueCodeableConcept>
                                                <coding>
                                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/ApplikationsartCS"/>
                                                    <code value="{ApplikationsartLegacy}"/>
                                                </coding>
                                            </valueCodeableConcept>
                                        </extension>
                                    </xsl:if>
                                    <xsl:if test="Strahlenart!=''">
                                        <extension url="Strahlenart">
                                            <valueCodeableConcept>
                                                <coding>
                                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/StrahlenartCS"/>
                                                    <code value="{Strahlenart}"/>
                                                </coding>
                                            </valueCodeableConcept>
                                        </extension>
                                    </xsl:if>
                                    <xsl:if test="Zielgebiet!=''">
                                        <extension url="Zielgebiet">
                                            <valueCodeableConcept>
                                                <coding>
                                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/ZielgebietCS"/>
                                                    <code value="{Zielgebiet}"/>
                                                </coding>
                                            </valueCodeableConcept>
                                        </extension>
                                    </xsl:if>
                                    <xsl:if test="Seite_Zielgebiet!=''">
                                        <extension url="SeiteZielgebiet">
                                            <valueCodeableConcept>
                                                <coding>
                                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SeitenlokalisationCS"/>
                                                    <code value="{Seite_Zielgebiet}"/>
                                                </coding>
                                            </valueCodeableConcept>
                                        </extension>
                                    </xsl:if>
                                    <xsl:if test="Gesamtdosis/Dosis!=''">
                                        <extension url="Gesamtdosis">
                                            <valueQuantity>
                                                <value value="{Gesamtdosis/Dosis}"/>
                                                <xsl:if test="Gesamtdosis/Einheit!=''"><unit value="{Gesamtdosis/Einheit}"/></xsl:if>
                                                <system value="http://dktk.dkfz.de/fhir/onco/core/ValueSet/StrahlungseinheitVS"/>
                                            </valueQuantity>
                                        </extension>
                                    </xsl:if>
                                    <xsl:if test="Einzeldosis/Dosis!=''">
                                        <extension url="Einzeldosis">
                                            <valueQuantity>
                                                <value value="{Einzeldosis/Dosis}"/>
                                                <xsl:if test="Einzeldosis/Einheit!=''"><unit value="{Einzeldosis/Einheit}"/></xsl:if>
                                                <system value="http://dktk.dkfz.de/fhir/onco/core/ValueSet/StrahlungseinheitVS"/>
                                            </valueQuantity>
                                        </extension>
                                    </xsl:if>
                                    <xsl:if test="Boost!=''">
                                        <extension url="Boost">
                                            <valueCodeableConcept>
                                                <coding>
                                                    <code value="{Boost}"/>
                                                </coding>
                                            </valueCodeableConcept>
                                        </extension>
                                    </xsl:if>
                                </extension>
                            </xsl:if>
                            <partOf>
                                <reference value="Procedure/{$Radiation_Therapy_ID}"/>
                            </partOf>
                            <xsl:choose>
                                <xsl:when test="Ende_Datum!=''">
                                    <xsl:choose>
                                        <xsl:when test="Ende_Grund='E'">
                                            <status value="completed"/>
                                        </xsl:when>
                                        <xsl:when test="Ende_Grund='U'">
                                            <status value="unknown"/>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <status value="stopped"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:choose>
                                        <xsl:when test="Beginn_Datum!=''">
                                            <status value="in-progress"/>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <status value="preparation"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:otherwise>
                            </xsl:choose>
                            <category>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS"/>
                                    <code value="ST"/>
                                    <display value="Strahlentherapie"/>
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
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <xsl:if test="Beginn_Datum!='' or Ende_Datum!=''">
                                <performedPeriod>
                                    <xsl:if test="Beginn_Datum!=''">
                                        <start value="{mds2fhir:transformDate(Beginn_Datum)}"/>
                                    </xsl:if>
                                    <xsl:if test="Ende_Datum!=''">
                                        <end value="{mds2fhir:transformDate(Ende_Datum)}"/>
                                    </xsl:if>
                                </performedPeriod>
                            </xsl:if>
                            <reasonReference>
                                <reference value="Condition/{$Diagnosis_ID}"/>
                            </reasonReference>
                        </Procedure>
                    </resource>
                    <request>
                        <method value="PUT"/>
                        <url value="Procedure/{@Betrahlung_ID}"/>
                    </request>
                </entry>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="OP">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:if test="OP_Datum!='' or Datum!=''">
            <xsl:variable name="OP_ID" select="mds2fhir:getID(./@OP_ID, '', generate-id())" as="xs:string"/>

            <entry>
                <fullUrl value="http://example.com/Procedure/{$OP_ID}"/>
                <resource>
                    <Procedure>
                        <id value="{$OP_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Operation"/>
                        </meta>
                        <xsl:if test="Intention_OP!=''">
                            <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-OPIntention">
                                <valueCodeableConcept>
                                    <coding>
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/OPIntentionCS"/>
                                        <code value="{Intention_OP}"/>
                                    </coding>
                                </valueCodeableConcept>
                            </extension>
                        </xsl:if>
                        <status value="completed"/>
                        <category>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS"/>
                                <code value="OP"/>
                                <display value="Operation"/>
                            </coding>
                        </category>
                        <code>
                            <xsl:for-each select="OP_OPS[.!='']"><!--legacy-->
                                <coding>
                                    <system value="http://fhir.de/CodeSystem/bfarm/ops"/>
                                    <xsl:if test="../OP_OPS_Version!=''">
                                        <version value="{../OP_OPS_Version}"/>
                                    </xsl:if>
                                    <code value="{.}"/>
                                </coding>
                            </xsl:for-each>
                            <xsl:for-each select="OPS[.!='']"><!--oBDS-->
                                <coding>
                                    <system value="http://fhir.de/CodeSystem/bfarm/ops"/>
                                    <xsl:if test="Version!=''">
                                        <version value="{Version}"/>
                                    </xsl:if>
                                    <code value="{Code}"/>
                                </coding>
                            </xsl:for-each>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <performedDateTime value="{mds2fhir:transformDate(OP_Datum | Datum)}"/>
                        <reasonReference>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </reasonReference>
                        <xsl:if test="Lokale_Beurteilung_Resttumor!='' or Gesamtbeurteilung_Resttumor!=''">
                            <outcome>
                                <xsl:if test="Lokale_Beurteilung_Resttumor!=''">
                                    <coding>
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/LokaleBeurteilungResidualstatusCS"/>
                                        <code value="{Lokale_Beurteilung_Resttumor}"/>
                                    </coding>
                                </xsl:if>
                                <xsl:if test="Gesamtbeurteilung_Resttumor!=''">
                                    <coding>
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungResidualstatusCS"/>
                                        <code value="{Gesamtbeurteilung_Resttumor}"/>
                                    </coding>
                                </xsl:if>
                            </outcome>
                        </xsl:if>
                        <xsl:if test="Komplikationen!=''">
                            <complication>
                                <xsl:for-each select="Komplikationen/Komplikation[. != '']">
                                    <coding>
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/OPKomplikationenCS"/>
                                        <code value="{.}"/>
                                    </coding>
                                </xsl:for-each>
                                <xsl:for-each select="Komplikationen/ICD[./Code != '']">
                                    <coding>
                                        <system value="http://fhir.de/CodeSystem/bfarm/icd-10-gm"/>
                                        <xsl:if test="Version !=''">
                                            <version value="{Version}"/>
                                        </xsl:if>
                                        <code value="{Code}"/>
                                    </coding>
                                </xsl:for-each>
                            </complication>
                        </xsl:if>
                    </Procedure>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Procedure/{$OP_ID}"/>
                </request>
            </entry>
        </xsl:if>
        <xsl:apply-templates select="./Histology">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="./TNM">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="Genetische_Variante">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="Weitere_Klassifikation">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="Verlauf">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:if test="Datum_Verlauf !=''">
            <xsl:variable name="Progress_ID" select="@Verlauf_ID"/>
            <xsl:variable name="TumorstatusLymphknoten_ID"><xsl:if test="Lymphknoten-Rezidiv!='' or Verlauf_Tumorstatus_Lymphknoten!=''"><xsl:value-of select="concat($Progress_ID, 'tsl')"/></xsl:if></xsl:variable><!-- for both, legacy ADT or oBDS -->
            <xsl:variable name="TumorstatusFernmetastasen_ID"><xsl:if test="Fernmetastasen!='' or Verlauf_Tumorstatus_Fernmetastasen!=''"><xsl:value-of select="concat($Progress_ID, 'fmn')"/></xsl:if></xsl:variable><!-- for both, legacy ADT or oBDS -->
            <xsl:variable name="LokalerTumorstatus_ID"><xsl:if test="Lokales-regionäres_Rezidiv!='' or Verlauf_Lokaler_Tumorstatus!=''"><xsl:value-of select="concat($Progress_ID, 'krz')"/></xsl:if></xsl:variable><!-- for both, legacy ADT or oBDS -->
            <xsl:variable name="GesamtbeurteilungTumorstatus_ID"><xsl:if test="Ansprechen_im_Verlauf!='' or Gesamtbeurteilung_Tumorstatus!=''"><xsl:value-of select="concat($Progress_ID, 'asp')"/></xsl:if></xsl:variable><!-- for both, legacy ADT or oBDS -->

            <entry>
                <fullUrl value="http://example.com/ClinicalImpression/{$Progress_ID}"/>
                <resource>
                    <ClinicalImpression xmlns="http://hl7.org/fhir">
                        <id value="{$Progress_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-ClinicalImpression-Verlauf"/>
                        </meta>
                        <status value="completed"/>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <effectiveDateTime value="{mds2fhir:transformDate(Datum_Verlauf)}"/>
                        <problem>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </problem>
                        <xsl:for-each select="TNM[.!='']">
                            <xsl:if test="Datum !=''">
                                <finding>
                                    <itemReference>
                                        <reference value="Observation/{mds2fhir:getID(./@TNM_ID, mds2fhir:transformDate(Datum), generate-id())}"/>
                                    </itemReference>
                                </finding>
                            </xsl:if>
                        </xsl:for-each>
                        <xsl:for-each select="Histology[.!='']">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{mds2fhir:getID(./@Histology_ID, mds2fhir:transformDate(./Tumor_Histologiedatum), generate-id())}"/>
                                </itemReference>
                            </finding>
                        </xsl:for-each>
                        <xsl:for-each select="Metastasis[.!='']">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{@Metastasis_ID}"/>
                                </itemReference>
                            </finding>
                        </xsl:for-each>
                        <xsl:for-each select="Genetische_Variante[.!='']">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{@Gen_ID}"/>
                                </itemReference>
                            </finding>
                        </xsl:for-each>
                        <xsl:if test="ECOG !=''">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{ECOG/@ECOG_ID}"/>
                                </itemReference>
                            </finding>
                        </xsl:if>
                        <xsl:for-each select="Weitere_Klassifikation[.!='']">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{@WeitereKlassifikation_ID}"/>
                                </itemReference>
                            </finding>
                        </xsl:for-each>
                        <xsl:if test="$LokalerTumorstatus_ID != ''">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{$LokalerTumorstatus_ID}"/>
                                </itemReference>
                            </finding>
                        </xsl:if>
                        <xsl:if test="$TumorstatusLymphknoten_ID != ''">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{$TumorstatusLymphknoten_ID}"/>
                                </itemReference>
                            </finding>
                        </xsl:if>
                        <xsl:if test="$TumorstatusFernmetastasen_ID != ''">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{$TumorstatusFernmetastasen_ID}"/>
                                </itemReference>
                            </finding>
                        </xsl:if>
                        <xsl:if test="$GesamtbeurteilungTumorstatus_ID != ''">
                            <finding>
                                <itemReference>
                                    <reference value="Observation/{$GesamtbeurteilungTumorstatus_ID}"/>
                                </itemReference>
                            </finding>
                        </xsl:if>
                    </ClinicalImpression>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="ClinicalImpression/{$Progress_ID}"/>
                </request>
            </entry>
            <xsl:if test="Lokales-regionäres_Rezidiv!='' or Verlauf_Lokaler_Tumorstatus!=''">
                <entry>
                    <fullUrl value="http://example.com/Observation/{$LokalerTumorstatus_ID}"/>
                    <resource>
                        <Observation xmlns="http://hl7.org/fhir">
                            <id value="{$LokalerTumorstatus_ID}"/>
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-LokalerTumorstatus"/>
                            </meta>
                            <status value="final"/>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="LA4583-6"/>
                                </coding>
                            </code>
                            <subject>
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <focus>
                                <reference value="Condition/{$Diagnosis_ID}"/>
                            </focus>
                            <effectiveDateTime value="{mds2fhir:transformDate(Datum_Verlauf)}"/>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufLokalerTumorstatusCS"/>
                                    <code value="{Lokales-regionäres_Rezidiv}{Verlauf_Lokaler_Tumorstatus}"/><!-- for both, legacy ADT or oBDS -->
                                </coding>
                            </valueCodeableConcept>
                        </Observation>
                    </resource>
                    <request>
                        <method value="PUT"/>
                        <url value="Observation/{$LokalerTumorstatus_ID}"/>
                    </request>
                </entry>
            </xsl:if>
            <xsl:if test="Lymphknoten-Rezidiv!='' or Verlauf_Tumorstatus_Lymphknoten!=''">
                <entry>
                    <fullUrl value="http://example.com/Observation/{$TumorstatusLymphknoten_ID}"/>
                    <resource>
                        <Observation xmlns="http://hl7.org/fhir">
                            <id value="{$TumorstatusLymphknoten_ID}"/>
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TumorstatusLymphknoten"/>
                            </meta>
                            <status value="final"/>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="LA4370-8"/>
                                </coding>
                            </code>
                            <subject>
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <focus>
                                <reference value="Condition/{$Diagnosis_ID}"/>
                            </focus>
                            <effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}"/>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufTumorstatusLymphknotenCS"/>
                                    <code value="{Lymphknoten-Rezidiv}{Verlauf_Tumorstatus_Lymphknoten}"/><!-- for both, legacy ADT or oBDS -->
                                </coding>
                            </valueCodeableConcept>
                        </Observation>
                    </resource>
                    <request>
                        <method value="PUT"/>
                        <url value="Observation/{$TumorstatusLymphknoten_ID}"/>
                    </request>
                </entry>
            </xsl:if>
            <xsl:if test="Fernmetastasen!='' or Verlauf_Tumorstatus_Fernmetastasen!=''">
                <entry>
                    <fullUrl value="http://example.com/Observation/{$TumorstatusFernmetastasen_ID}"/>
                    <resource>
                        <Observation xmlns="http://hl7.org/fhir">
                            <id value="{$TumorstatusFernmetastasen_ID}"/>
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TumorstatusFernmetastasen"/>
                            </meta>
                            <status value="final"/>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="LA4226-2"/>
                                </coding>
                            </code>
                            <subject>
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <focus>
                                <reference value="Condition/{$Diagnosis_ID}"/>
                            </focus>
                            <effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}"/>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufTumorstatusFernmetastasenCS"/>
                                    <code value="{Fernmetastasen}{Verlauf_Tumorstatus_Fernmetastasen}"/>
                                </coding>
                            </valueCodeableConcept>
                        </Observation>
                    </resource>
                    <request>
                        <method value="PUT"/>
                        <url value="Observation/{$TumorstatusFernmetastasen_ID}"/>
                    </request>
                </entry>
            </xsl:if>
            <xsl:if test="Ansprechen_im_Verlauf!='' or Gesamtbeurteilung_Tumorstatus!=''">
                <entry>
                    <fullUrl value="http://example.com/Observation/{$GesamtbeurteilungTumorstatus_ID}"/>
                    <resource>
                        <Observation xmlns="http://hl7.org/fhir">
                            <id value="{$GesamtbeurteilungTumorstatus_ID}"/>
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-GesamtbeurteilungTumorstatus"/>
                            </meta>
                            <status value="final"/>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="21976-6"/>
                                </coding>
                            </code>
                            <subject>
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <focus>
                                <reference value="Condition/{$Diagnosis_ID}"/>
                            </focus>
                            <effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}"/>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungTumorstatusCS"/>
                                    <code value="{Ansprechen_im_Verlauf}{Gesamtbeurteilung_Tumorstatus}"/><!-- for both, legacy ADT or oBDS -->
                                </coding>
                            </valueCodeableConcept>
                        </Observation>
                    </resource>
                    <request>
                        <method value="PUT"/>
                        <url value="Observation/{$GesamtbeurteilungTumorstatus_ID}"/>
                    </request>
                </entry>
            </xsl:if>
            <xsl:apply-templates select="./Histology">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="./TNM">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="./Metastasis">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
                <xsl:with-param name="Datum_Verlauf" select="./Datum_Verlauf"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="Genetische_Variante">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="ECOG">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="Weitere_Klassifikation">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
            </xsl:apply-templates>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Therapieempfehlung">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:if test="Datum !=''">
            <entry>
                <fullUrl value="http://example.com/CarePlan/{@Tumorkonferenz_ID}"/>
                <resource>
                    <CarePlan xmlns="http://hl7.org/fhir">
                        <id value="{@Tumorkonferenz_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-CarePlan-Therapieempfehlung"/>
                        </meta>
                        <status value="unknown"/>
                        <intent value="proposal"/>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <created value="{mds2fhir:transformDate(Datum)}"/>
                        <addresses>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </addresses>
                        <xsl:for-each select="Typ_Therapieempfehlung[.!='']">
                            <activity>
                                <detail>
                                    <code>
                                        <coding>
                                            <system value="http://dktk.dkfz.de/fhir/onco/core/ValueSet/TherapieempfehlungCS"/>
                                            <code value="{.}"/>
                                        </coding>
                                    </code>
                                    <status value="unknown"/>
                                    <xsl:if test="../Abweichung_Patientenwunsch!=''">
                                        <statusReason>
                                            <coding>
                                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/JNUCS"/>
                                                <code value="{../Abweichung_Patientenwunsch}"/>
                                            </coding>
                                        </statusReason>
                                    </xsl:if>
                                </detail>
                            </activity>
                        </xsl:for-each>
                    </CarePlan>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="CarePlan/{@Tumorkonferenz_ID}"/>
                </request>
            </entry>
        </xsl:if>
    </xsl:template>

    <xsl:template match="TNM">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:if test="Datum !=''">
            <xsl:variable name="TNM_ID" select="@TNM_ID" as="xs:string"/>
            <entry>
                <fullUrl value="http://example.com/Observation/{$TNM_ID}"/>
                <resource>
                    <Observation>
                        <id value="{$TNM_ID}"/>
                        <meta>
                            <xsl:choose>
                                <xsl:when test="gesamtpraefix='pTNM' or ./c-p-u-Präfix_T='p' or ./c-p-u-Präfix_N='p' or ./c-p-u-Präfix_M='p'">
                                    <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TNMp"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TNMc"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </meta>
                        <status value="final"/>
                        <code>
                            <xsl:choose>
                                <xsl:when test="gesamtpraefix='pTNM' or ./c-p-u-Präfix_T='p' or ./c-p-u-Präfix_N='p' or ./c-p-u-Präfix_M='p'">
                                    <coding>
                                        <system value="http://loinc.org"/>
                                        <code>
                                            <xsl:attribute name="value">21902-2</xsl:attribute>
                                        </code>
                                    </coding>
                                </xsl:when>
                                <xsl:when test="gesamtpraefix='cTNM' or ./c-p-u-Präfix_T='c' or ./c-p-u-Präfix_N='c' or ./c-p-u-Präfix_M='c'">
                                    <coding>
                                        <system value="http://loinc.org"/>
                                        <code>
                                            <xsl:attribute name="value">21908-9</xsl:attribute>
                                        </code>
                                    </coding>
                                </xsl:when>
                                <xsl:otherwise>
                                    <text value="TNM ohne Angabe ob klinisch oder pathologisch"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <effectiveDateTime value="{mds2fhir:transformDate(Datum)}"/>
                        <xsl:if test="UICC_Stadium!=''">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/UiccstadiumCS"/>
                                    <xsl:if test="TNM-Version!=''">
                                        <version value="{TNM-Version}"/>
                                    </xsl:if>
                                    <code value="{UICC_Stadium[1]}"/>
                                </coding>
                            </valueCodeableConcept>
                        </xsl:if>
                        <xsl:if test="TNM-T!=''">
                            <component>
                                <xsl:if test="c-p-u-Präfix_T!=''">
                                    <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-TNMcpuPraefix">
                                        <valueCodeableConcept>
                                            <coding>
                                                <code value="{c-p-u-Präfix_T}"/>
                                            </coding>
                                        </valueCodeableConcept>
                                    </extension>
                                </xsl:if>
                                <code>
                                    <coding>
                                        <system value="http://loinc.org"/>
                                        <code>
                                            <xsl:attribute name="value">
                                                <xsl:value-of select="if (c-p-u-Präfix_T = 'p') then '21899-0' else '21905-5'" />
                                            </xsl:attribute>
                                        </code>
                                    </coding>
                                </code>
                                <valueCodeableConcept>
                                    <coding>
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMTCS"/>
                                        <code value="{TNM-T}"/>
                                        <xsl:if test="TNM-Version!=''">
                                            <version value="{TNM-Version}"/>
                                        </xsl:if>
                                    </coding>
                                </valueCodeableConcept>
                            </component>
                        </xsl:if>
                        <xsl:if test="TNM-N!=''">
                            <component>
                                <xsl:if test="c-p-u-Präfix_N!=''">
                                    <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-TNMcpuPraefix">
                                        <valueCodeableConcept>
                                            <coding>
                                                <code value="{c-p-u-Präfix_N}"/>
                                            </coding>
                                        </valueCodeableConcept>
                                    </extension>
                                </xsl:if>
                                <code>
                                    <coding>
                                        <system value="http://loinc.org"/>
                                        <code>
                                            <xsl:attribute name="value">
                                                <xsl:value-of select="if (c-p-u-Präfix_N = 'p') then '21900-6' else '21906-3'" />
                                            </xsl:attribute>
                                        </code>
                                    </coding>
                                </code>
                                <valueCodeableConcept>
                                    <coding>
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMNCS"/>
                                        <code value="{TNM-N}"/>
                                        <xsl:if test="TNM-Version!=''">
                                            <version value="{TNM-Version}"/>
                                        </xsl:if>
                                    </coding>
                                </valueCodeableConcept>
                            </component>
                        </xsl:if>
                        <xsl:if test="TNM-M!=''">
                            <component>
                                <xsl:if test="c-p-u-Präfix_M!=''">
                                    <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-TNMcpuPraefix">
                                        <valueCodeableConcept>
                                            <coding>
                                                <code value="{c-p-u-Präfix_M}"/>
                                            </coding>
                                        </valueCodeableConcept>
                                    </extension>
                                </xsl:if>
                                <code>
                                    <coding>
                                        <system value="http://loinc.org"/>
                                        <code>
                                            <xsl:attribute name="value">
                                                <xsl:value-of select="if (c-p-u-Präfix_M = 'p') then '21901-4' else '21907-1'" />
                                            </xsl:attribute>
                                        </code>
                                    </coding>
                                </code>
                                <valueCodeableConcept>
                                    <coding>
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMMCS"/>
                                        <code value="{TNM-M}"/>
                                        <xsl:if test="TNM-Version!=''">
                                            <version value="{TNM-Version}"/>
                                        </xsl:if>
                                    </coding>
                                </valueCodeableConcept>
                            </component>
                        </xsl:if>
                        <component>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="59479-6"/>
                                </coding>
                            </code>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMySymbolCS"/>
                                    <code>
                                        <xsl:attribute name="value">
                                            <xsl:value-of select="if (TNM-y-Symbol = 'y') then 'y' else '9'" />
                                        </xsl:attribute>
                                    </code>
                                </coding>
                            </valueCodeableConcept>
                        </component>
                        <component>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="21983-2"/>
                                </coding>
                            </code>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMrSymbolCS"/>
                                    <code>
                                        <xsl:attribute name="value">
                                            <xsl:value-of select="if (TNM-r-Symbol = 'r') then 'r' else '9'" />
                                        </xsl:attribute>
                                    </code>
                                </coding>
                            </valueCodeableConcept>
                        </component>
                        <xsl:apply-templates select="TNM-m-Symbol">
                            <xsl:with-param name="code" select="'42030-7'"/>
                            <xsl:with-param name="system" select="'TNMmSymbolCS'"/>
                        </xsl:apply-templates>
                        <xsl:apply-templates select="L">
                            <xsl:with-param name="code" select="'33739-4'"/>
                            <xsl:with-param name="system" select="'TNMLKategorieCS'"/>
                        </xsl:apply-templates>
                        <xsl:apply-templates select="V">
                            <xsl:with-param name="code" select="'33740-2'"/>
                            <xsl:with-param name="system" select="'TNMVKategorieCS'"/>
                        </xsl:apply-templates>
                        <xsl:apply-templates select="Pn">
                            <xsl:with-param name="code" select="'92837-4'"/>
                            <xsl:with-param name="system" select="'TNMPnKategorieCS'"/>
                        </xsl:apply-templates>
                        <xsl:apply-templates select="S">
                            <xsl:with-param name="code" select="'21924-6'"/>
                            <xsl:with-param name="system" select="'TNMSKategorieCS'"/>
                        </xsl:apply-templates>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Observation/{$TNM_ID}"/>
                </request>
            </entry>
        </xsl:if>
    </xsl:template>

    <xsl:template match="TNM-m-Symbol | L | V | Pn | S">
        <xsl:param name="code"/>
        <xsl:param name="system"/>
        <xsl:if test=".!=''">
            <component>
                <code>
                    <coding>
                        <system value="http://loinc.org"/>
                        <code value="{$code}"/>
                    </coding>
                </code>
                <valueCodeableConcept>
                    <coding>
                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/{$system}"/>
                        <code value="{.}"/>
                    </coding>
                </valueCodeableConcept>
            </component>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Metastasis">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:param name="Datum_Verlauf"/>
        <xsl:if test="Datum_diagnostische_Sicherung!='' and Lokalisation_Fernmetastasen!=''">
            <entry>
                <fullUrl value="http://example.com/Observation/{@Metastasis_ID}"/>
                <resource>
                    <Observation>
                        <id value="{@Metastasis_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Fernmetastasen"/>
                        </meta>
                        <status value="final"/>
                        <code>
                            <coding>
                                <system value="http://loinc.org"/>
                                <code value="21907-1"/>
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <xsl:choose>
                            <xsl:when test="Datum_diagnostische_Sicherung!=''">
                                <effectiveDateTime value="{mds2fhir:transformDate(Datum_diagnostische_Sicherung)}"/>
                            </xsl:when>
                            <xsl:when test="$Datum_Verlauf!=''">
                                <effectiveDateTime value="{mds2fhir:transformDate($Datum_Verlauf)}"/>
                            </xsl:when>
                        </xsl:choose>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/JNUCS"/>
                                <code value="J"/>
                            </coding>
                        </valueCodeableConcept>
                        <bodySite>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/FMLokalisationCS"/>
                                <code value="{Lokalisation_Fernmetastasen}"/>
                            </coding>
                        </bodySite>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Observation/{@Metastasis_ID}"/>
                </request>
            </entry>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Histology">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:if test="./Tumor_Histologiedatum !=''">
            <xsl:variable name="Histology_ID" select="mds2fhir:getID(./@Histology_ID, mds2fhir:transformDate(./Tumor_Histologiedatum), generate-id())" as="xs:string"/>
            <entry>
                <fullUrl value="http://example.com/Observation/{$Histology_ID}"/>
                <resource>
                    <Observation>
                        <id value="{$Histology_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Histologie"/>
                        </meta>
                        <status value="final"/>
                        <code>
                            <coding>
                                <system value="http://loinc.org"/>
                                <code value="59847-4"/>
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <xsl:if test="Tumor_Histologiedatum !=''">
                            <effectiveDateTime value="{mds2fhir:transformDate(Tumor_Histologiedatum)}"/>
                        </xsl:if>
                        <valueCodeableConcept>
                            <xsl:choose>
                                <xsl:when test="Morphologie_ICD_O!=''"><!--oBDS source-->
                                    <xsl:for-each select="Morphologie_ICD_O[.!='']">
                                        <coding>
                                            <system value="urn:oid:2.16.840.1.113883.6.43.1"/>
                                            <xsl:if test="ICD-O_Katalog_Morphologie_Version!=''">
                                                <version value="{ICD-O_Katalog_Morphologie_Version}"/>
                                            </xsl:if>
                                            <xsl:if test="Morphologie_Code!=''">
                                                <code value="{Morphologie_Code}"/>
                                            </xsl:if>
                                        </coding>
                                    </xsl:for-each>
                                </xsl:when>
                                <xsl:otherwise>
                                    <!--ADT2 source-->
                                    <coding>
                                        <system value="urn:oid:2.16.840.1.113883.6.43.1"/>
                                        <xsl:if test="ICD-O_Katalog_Morphologie_Version!=''">
                                            <version value="{ICD-O_Katalog_Morphologie_Version}"/>
                                        </xsl:if>
                                        <xsl:if test="Morphologie!=''">
                                            <code value="{Morphologie}"/>
                                        </xsl:if>
                                    </coding>
                                </xsl:otherwise>
                            </xsl:choose>
                            <xsl:if test="Morphologie_Freitext!=''">
                                <text value="{mds2fhir:fix-free-text(Morphologie_Freitext)}"/>
                            </xsl:if>
                        </valueCodeableConcept>
                        <xsl:if test="Grading!=''">
                            <hasMember>
                                <reference value="Observation/{Grading/@Grading_ID}"/>
                            </hasMember>
                        </xsl:if>
                        <xsl:if test="LK_untersucht!=''">
                            <hasMember>
                                <reference value="Observation/{LK_untersucht/@LK_untersucht_ID}"/>
                            </hasMember>
                        </xsl:if>
                        <xsl:if test="LK_befallen!=''">
                            <hasMember>
                                <reference value="Observation/{LK_befallen/@LK_befallen_ID}"/>
                            </hasMember>
                        </xsl:if>
                        <xsl:if test="Sentinel_LK_untersucht!=''">
                            <hasMember>
                                <reference value="Observation/{Sentinel_LK_untersucht/@Sentinel_LK_untersucht_ID}"/>
                            </hasMember>
                        </xsl:if>
                        <xsl:if test="Sentinel_LK_befallen!=''">
                            <hasMember>
                                <reference value="Observation/{Sentinel_LK_befallen/@Sentinel_LK_befallen_ID}"/>
                            </hasMember>
                        </xsl:if>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Observation/{$Histology_ID}"/>
                </request>
            </entry>
            <xsl:if test="Grading!=''">
                <entry>
                    <fullUrl value="http://example.com/Observation/{Grading/@Grading_ID}"/>
                    <resource>
                        <Observation>
                            <id value="{Grading/@Grading_ID}"/>
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Grading"/>
                            </meta>
                            <status value="final"/>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="59542-1"/>
                                </coding>
                            </code>
                            <subject>
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <focus>
                                <reference value="Condition/{$Diagnosis_ID}"/>
                            </focus>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GradingCS"/>
                                    <xsl:if test="Grading!=''">
                                        <code value="{Grading}"/>
                                    </xsl:if>
                                </coding>
                            </valueCodeableConcept>
                        </Observation>
                    </resource>
                    <request>
                        <method value="PUT"/>
                        <url value="Observation/{Grading/@Grading_ID}"/>
                    </request>
                </entry>
            </xsl:if>
            <xsl:apply-templates select="LK_untersucht">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
                <xsl:with-param name="URL" select="'AnzahlUntersuchtenLymphknoten'"/>
                <xsl:with-param name="LOINC" select="'21894-1'"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="LK_befallen">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
                <xsl:with-param name="URL" select="'AnzahlBefallenenLymphknoten'"/>
                <xsl:with-param name="LOINC" select="'21893-3'"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="Sentinel_LK_untersucht">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
                <xsl:with-param name="URL" select="'AnzahlUntersuchtenSentinelLymphknoten'"/>
                <xsl:with-param name="LOINC" select="'85347-3'"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="Sentinel_LK_befallen">
                <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
                <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
                <xsl:with-param name="URL" select="'AnzahlBefallenenSentinelLymphknoten'"/>
                <xsl:with-param name="LOINC" select="'92832-5'"/>
            </xsl:apply-templates>
        </xsl:if>
    </xsl:template>

    <xsl:template match="LK_untersucht | LK_befallen | Sentinel_LK_untersucht | Sentinel_LK_befallen">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:param name="URL"/>
        <xsl:param name="LOINC"/>
        <xsl:if test=".!=''">
            <entry>
                <fullUrl value="http://example.com/Observation/{@*}"/>
                <resource>
                    <Observation>
                        <id value="{@*}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-{$URL}"/>
                        </meta>
                        <status value="final"/>
                        <code>
                            <coding>
                                <system value="http://loinc.org"/>
                                <code value="{$LOINC}"/>
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <valueQuantity>
                            <value value="{number(.)}"/>
                        </valueQuantity>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Observation/{@*}"/>
                </request>
            </entry>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Genetische_Variante">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:variable name="Gen_ID" select="@Gen_ID" as="xs:string"/>
        <entry>
            <fullUrl value="http://example.com/Observation/{$Gen_ID}"/>
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{$Gen_ID}"/>
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-GenetischeVariante"/>
                    </meta>
                    <status value="final"/>
                    <code>
                        <coding>
                            <system value="http://loinc.org"/>
                            <code value="69548-6"/>
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}"/>
                    </subject>
                    <focus>
                        <reference value="Condition/{$Diagnosis_ID}"/>
                    </focus>
                    <effectiveDateTime value="{Datum}"/>
                    <xsl:choose>
                        <xsl:when test="Auspraegung!=''">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GenetischeVarianteCS"/>
                                    <code value="{Auspraegung}"/>
                                </coding>
                            </valueCodeableConcept>
                        </xsl:when>
                        <xsl:when test="Sonstige_Auspraegung!=''">
                            <valueCodeableConcept>
                                <text value="{mds2fhir:fix-free-text(Sonstige_Auspraegung)}"/>
                            </valueCodeableConcept>
                        </xsl:when>
                    </xsl:choose>
                    <xsl:if test="Bezeichnung!=''">
                        <component>
                            <code>
                                <coding>
                                    <system value="http://loinc.org"/>
                                    <code value="48018-6"/>
                                </coding>
                            </code>
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://www.genenames.org"/>
                                    <code value="{Bezeichnung}"/>
                                </coding>
                            </valueCodeableConcept>
                        </component>
                    </xsl:if>
                </Observation>
            </resource>
            <request>
                <method value="PUT"/>
                <url value="Observation/{$Gen_ID}"/>
            </request>
        </entry>
    </xsl:template>

    <xsl:template match="ECOG">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:variable name="date">
            <xsl:value-of select="../Tumor_Diagnosedatum|../Datum_Verlauf"/>
        </xsl:variable>
        <xsl:if test="$date !=''">
            <xsl:variable name="ECOG_ID" select="@ECOG_ID"/>
            <entry>
                <fullUrl value="http://example.com/Observation/{$ECOG_ID}"/>
                <resource>
                    <Observation xmlns="http://hl7.org/fhir">
                        <id value="{$ECOG_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Ecog"/>
                        </meta>
                        <status value="final"/>
                        <code>
                            <coding>
                                <system value="http://loinc.org"/>
                                <code value="89247-1"/>
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <effectiveDateTime value="{mds2fhir:transformDate($date)}"/>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/EcogCS"/>
                                <code value="{.}"/>
                            </coding>
                        </valueCodeableConcept>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Observation/{$ECOG_ID}"/>
                </request>
            </entry>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Nebenwirkung">
        <xsl:param name="Parent_Ressource"/>
        <xsl:param name="Patient_ID"/>
        <xsl:variable name="Gen_ID" select="./@Gen_ID" as="xs:string"/>
        <entry>
            <fullUrl value="http://example.com/AdverseEvent/{@Nebenwirkung_ID}"/>
            <resource>
                <AdverseEvent xmlns="http://hl7.org/fhir">
                    <id value="{@Nebenwirkung_ID}"/>
                    <actuality value="actual"/>
                    <xsl:if test="Art!=''">
                        <event>
                            <coding>
                                <xsl:choose>
                                    <xsl:when test="starts-with(lower-case(Typ), 'meddra')">
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/MedDRA_CodeCS"/>
                                    </xsl:when>
                                    <xsl:when test="starts-with(lower-case(Typ), 'ctc')">
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/CTCAECS"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <system value="urn:{mds2fhir:fix-free-text(Typ)}"/>
                                    </xsl:otherwise>
                                </xsl:choose>
                                <xsl:if test="Version!=''"><version value="{Version}"/></xsl:if>
                                <code value="{Art}"/>
                            </coding>
                        </event>
                    </xsl:if>
                    <subject>
                        <reference value="Patient/{$Patient_ID}"/>
                    </subject>
                    <severity>
                        <coding>
                            <system value="http://hl7.org/fhir/us/ctcae/CodeSystem/ctcae-grade-code-system"/>
                            <code value="{Grad}"/>
                        </coding>
                    </severity>
                    <suspectEntity>
                        <instance>
                            <reference value="{$Parent_Ressource}"/>
                        </instance>
                    </suspectEntity>
                </AdverseEvent>
            </resource>
            <request>
                <method value="PUT"/>
                <url value="AdverseEvent/{@Nebenwirkung_ID}"/>
            </request>
        </entry>
    </xsl:template>

    <xsl:template match="Vitalstatus_Gesamt">
        <xsl:param name="Patient_ID"/>
        <xsl:if test="Datum_des_letztbekannten_Vitalstatus !=''">
            <entry>
                <fullUrl value="http://example.com/Observation/{@Vitalstatus_ID}"/>
                <resource>
                    <Observation>
                        <id value="{@Vitalstatus_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Vitalstatus"/>
                        </meta>
                        <status value="{if (Vitalstatus = 'verstorben') then 'final' else 'registered'}"/>
                        <code>
                            <coding>
                                <system value="http://loinc.org"/>
                                <code value="75186-7"/>
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <effectiveDateTime value="{mds2fhir:transformDate(Datum_des_letztbekannten_Vitalstatus)}"/>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VitalstatusCS"/>
                                <code value="{Vitalstatus}"/>
                            </coding>
                        </valueCodeableConcept>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT"/>
                    <xsl:if test="not(Vitalstatus = 'verstorben')">
                        <ifNoneMatch value="*"/>
                    </xsl:if>
                    <url value="Observation/{@Vitalstatus_ID}"/>
                </request>
            </entry>
            <xsl:if test="Tod/Tod_tumorbedingt!='' or Tod/Menge_Todesursachen/Todesursache_ICD/Code!=''">
                <xsl:variable name="TodUrsacheID" select="replace(@Vitalstatus_ID, '^.{5}', 'tod')"/>
                <entry>
                    <fullUrl value="http://example.com/Observation/{$TodUrsacheID}" />
                    <resource>
                        <Observation>
                            <id value="{$TodUrsacheID}" />
                            <meta>
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TodUrsache" />
                            </meta>
                            <status value="final" />
                            <code>
                                <coding>
                                    <system value="http://loinc.org" />
                                    <code value="68343-3" />
                                </coding>
                            </code>
                            <subject>
                                <reference value="Patient/{$Patient_ID}"/>
                            </subject>
                            <xsl:if test="Tod/Sterbedatum!=''">
                                <effectiveDateTime value="{Tod/Sterbedatum}" />
                            </xsl:if>
                            <valueCodeableConcept>
                                <xsl:for-each select="Tod/Menge_Todesursachen/Todesursache_ICD[Code!='']">
                                    <coding>
                                        <system value="http://fhir.de/CodeSystem/bfarm/icd-10-gm" />
                                        <xsl:if test="Version!=''">
                                            <version value="{Version}"/>
                                        </xsl:if>
                                        <code value="{Code}" />
                                    </coding>
                                </xsl:for-each>
                                <xsl:if test="Tod/Tod_tumorbedingt!=''">
                                    <coding>
                                        <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/JNUCS" />
                                        <code value="{Tod/Tod_tumorbedingt}" />
                                    </coding>
                                </xsl:if>
                            </valueCodeableConcept>
                        </Observation>
                    </resource>
                    <request>
                        <method value="PUT" />
                        <url value="Observation/{$TodUrsacheID}" />
                    </request>
                </entry>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Weitere_Klassifikation">
        <xsl:param name="Patient_ID"/>
        <xsl:param name="Diagnosis_ID"/>
        <xsl:if test="Datum !='' and Stadium !=''">
            <entry>
                <fullUrl value="http://example.com/Observation/{@WeitereKlassifikation_ID}"/>
                <resource>
                    <Observation>
                        <id value="{@WeitereKlassifikation_ID}"/>
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-WeitereKlassifikation"/>
                        </meta>
                        <status value="registered"/>
                        <code>
                            <coding>
                                <system value="http://loinc.org"/>
                                <code value="LP248771-0"/>
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}"/>
                        </subject>
                        <focus>
                            <reference value="Condition/{$Diagnosis_ID}"/>
                        </focus>
                        <effectiveDateTime value="{mds2fhir:transformDate(Datum)}"/>
                        <valueCodeableConcept>
                            <coding>
                                <system value="urn:{mds2fhir:fix-free-text(Name)}"/>
                                <code value="{Stadium}"/>
                            </coding>
                        </valueCodeableConcept>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT"/>
                    <url value="Observation/{@WeitereKlassifikation_ID}"/>
                </request>
            </entry>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Tumor" mode="tumor">
        <xsl:param name="Diagnosis_ID"/>
        <xsl:param name="Patient_ID"/>
        <xsl:apply-templates select="Histology">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="Metastasis">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="TNM">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="Genetische_Variante">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="OP">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="ST">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="SYST">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="Verlauf">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="Therapieempfehlung">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="Tod">
            <xsl:with-param name="Patient_ID" select="$Patient_ID"/>
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID"/>
        </xsl:apply-templates>
    </xsl:template>

    <!-- Funktionen -->
    <!-- Generate Id if non exists. If possible, include some releated date to avoid collision & improve indexing. -->
    <xsl:function name="mds2fhir:getID">
        <xsl:param name="id"/>
        <xsl:param name="date"/>
        <xsl:param name="prefix"/>
        <xsl:sequence select="
            if ($id and $id != '') then
               $id
            else
                if ($date and $date != '') then
                    concat($date,'-', $prefix)
                else $prefix
			"/>
    </xsl:function>


    <xsl:function name="mds2fhir:transformDateBlazebug">
        <xsl:param name="date"/>
        <xsl:variable name="fixedDate" select="mds2fhir:autocorrectDate($date)"/>
        <xsl:variable name="day" select="substring($fixedDate, 1,2)" as="xs:string"/>
        <xsl:variable name="month" select="substring($fixedDate, 4, 2)" as="xs:string"/>
        <xsl:variable name="year" select="substring($fixedDate, 7, 4)" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($fixedDate, '\d{4}-\d{2}-\d{2}')"><!-- oBDS date -->
                <xsl:value-of select="mds2fhir:transformDateBlazebugHelper(substring($fixedDate, 9, 2),substring($fixedDate, 6, 2),substring($fixedDate, 1, 4))"/>
            </xsl:when>
            <xsl:otherwise><!-- ADT date -->
                <xsl:value-of select="mds2fhir:transformDateBlazebugHelper(substring($fixedDate, 1,2),substring($fixedDate, 4, 2),substring($fixedDate, 7, 4))"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:transformDateBlazebugHelper">
        <xsl:param name="day"/>
        <xsl:param name="month"/>
        <xsl:param name="year"/>
        <xsl:choose>
            <xsl:when test="$day='00'">
                <xsl:choose>
                    <xsl:when test="$month='00'">
                        <xsl:value-of select="concat($year,'-01-01')"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat($year,'-',$month,'-01')"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($year,'-',$month,'-',$day)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:transformDate">
        <xsl:param name="date"/>
        <xsl:variable name="fixedDate" select="mds2fhir:autocorrectDate($date)"/>
        <xsl:variable name="day" select="substring($fixedDate, 1,2)" as="xs:string"/>
        <xsl:variable name="month" select="substring($fixedDate, 4, 2)" as="xs:string"/>
        <xsl:variable name="year" select="substring($fixedDate, 7, 4)" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="matches($date, '\d{4}-\d{2}-\d{2}')"><!-- oBDS date -->
                <xsl:value-of select="$date"/>
            </xsl:when>
            <xsl:when test="$day='00'"><!-- legacy ADT date mapping -->
                <xsl:choose>
                    <xsl:when test="$month='00'">
                        <xsl:value-of select="$year"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat($year,'-',$month)"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($year,'-',$month,'-',$day)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:autocorrectDate">
        <xsl:param name="date"/>
        <xsl:choose>
            <xsl:when test="matches($date, '\d{4}-\d{2}-\d{2}')"><!-- oBDS date -->
                <xsl:value-of select="$date"/>
            </xsl:when>
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
                <xsl:message terminate="yes">ERROR: wrong date format: "<xsl:value-of select="$date"/>" in node <xsl:value-of select="name($date/../.)"/>
                </xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:getVersionYear">
        <xsl:param name="version"/>
        <xsl:value-of select="substring($version, 4, 4)"/>
    </xsl:function>

    <xsl:function name="mds2fhir:getICDType">
        <xsl:param name="version"/>
        <xsl:choose>
            <xsl:when test="contains($version,'GM')">http://fhir.de/CodeSystem/bfarm/icd-10-gm</xsl:when>
            <xsl:when test="contains($version,'WHO')">http://hl7.org/fhir/sid/icd-10</xsl:when>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:getMedicationStatementTreatmentStatus">
        <xsl:param name="meldeanlass"/>
        <xsl:param name="endeGrund"/>
        <xsl:choose>
            <xsl:when test="$endeGrund='E' or $endeGrund='R'">
                <xsl:value-of select="'completed'"/>
            </xsl:when>
            <xsl:when test="$endeGrund='U'">
                <xsl:value-of select="'unknown'"/>
            </xsl:when>
            <xsl:when test="$endeGrund='W' or $endeGrund='A' or $endeGrund='P' or $endeGrund='S' or $endeGrund='T'">
                <xsl:value-of select="'stopped'"/>
            </xsl:when>
            <xsl:when test="$endeGrund='V'">
                <xsl:value-of select="'not-taken'"/>
            </xsl:when>
            <xsl:when test="$meldeanlass='behandlungsbeginn'">
                <xsl:value-of select="'active'"/>
            </xsl:when>
            <xsl:when test="$meldeanlass='behandlungsende'">
                <xsl:value-of select="'completed'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="'unknown'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:getProcedureTreatmentStatus">
        <xsl:param name="meldeanlass"/>
        <xsl:param name="endeGrund"/>
        <xsl:choose>
            <xsl:when test="$endeGrund='E'">
                <xsl:value-of select="'completed'"/>
            </xsl:when>
            <xsl:when test="$endeGrund='U'">
                <xsl:value-of select="'unknown'"/>
            </xsl:when>
            <xsl:when test="$endeGrund='A' or $endeGrund='P' or $endeGrund='S'">
                <xsl:value-of select="'stopped'"/>
            </xsl:when>
            <xsl:when test="$endeGrund='V'">
                <xsl:value-of select="'not-done'"/>
            </xsl:when>
            <xsl:when test="$meldeanlass='behandlungsbeginn'">
                <xsl:value-of select="'in-progress'"/>
            </xsl:when>
            <xsl:when test="$meldeanlass='behandlungsende'">
                <xsl:value-of select="'completed'"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="'unknown'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:fix-free-text">
        <xsl:param name="text" />
        <xsl:value-of select="replace(replace(replace(replace(replace(replace(translate($text,' ', '_'), 'ä', 'ae'), 'Ä', 'Ae'), 'ö', 'oe'), 'Ö', 'Oe'), 'ü', 'ue'), 'Ü', 'Ue')"/>
    </xsl:function>
</xsl:stylesheet>