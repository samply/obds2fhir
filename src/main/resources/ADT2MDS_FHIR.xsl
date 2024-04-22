<?xml version="1.0" encoding="utf-8" standalone="no"?>
<xsl:stylesheet xmlns="http://www.mds.de/namespace"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xsi="http://www.mds.de/namespace MDS_Suchmodell_v4.xsd"
    xmlns:hash="java:de.samply.obds2fhir"
    exclude-result-prefixes="#default"
    version="2.0"
    xpath-default-namespace="http://www.gekid.de/namespace">

    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    <xsl:output omit-xml-declaration="no" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:param name="add_department" />

<!--    This xsl file transforms ADT xml files (ADT_GEKID_v2.1.1-dktk_v0.1.2 and ADT_GEKID_v2.1.1) to the DKTK searchmodel structure (MDS_Suchmodell_v4) combine with aditional ADT elements
        MDS + additional Structure (entities) generated from ADT:
            Patient
                Sample
                Diagnosis
                    Tumor
                        Histology
                        Metastasis
                        TNM
                        Verlauf
                            Histology
                            TNM
                        OP
                            Histology
                            TNM
                        ST
                        SYST-->

    <!--Deep copy of the whole document-->
    <xsl:template match="/ADT_GEKID/Menge_Patient">
        <Patienten>
            <xsl:apply-templates select="node()| @*"/>
        </Patienten>
    </xsl:template>


    <!--Generate first Level PATIENT entity (Elements: Geschlecht | Geburtsdatum | Datum_des_letztbekannten_Vitalstatus | Vitalstatus | DKTK_ID | DKTK_LOCAL_ID | DKTK_Einwilligung_erfolgt | Upload_Zeitpunkt_ZS_Antwort | Upload_Zeitpunkt_ZS_Erfolgt )-->
    <xsl:template match="Patient">
        <Patient>
            <xsl:variable name="Patient_Id" select="Patienten_Stammdaten/@Patient_ID"/>
            <xsl:variable name="Patient_Pseudonym" select="xsi:Pseudonymize(Patienten_Stammdaten/Patienten_Geschlecht, Patienten_Stammdaten/Patienten_Vornamen, Patienten_Stammdaten/Patienten_Nachname, Patienten_Stammdaten/Patienten_Geburtsname, Patienten_Stammdaten/Patienten_Geburtsdatum, Patienten_Stammdaten/@Patient_ID)"/>
            <xsl:attribute name="Patient_ID">
                <!--<xsl:value-of select="Patienten_Stammdaten/@Patient_ID"/>-->
                <xsl:value-of select="hash:hash($Patient_Id,'','')"/>
            </xsl:attribute>
            <Geschlecht>
                <xsl:choose><xsl:when test="Patienten_Stammdaten/Patienten_Geschlecht = 'D'">S</xsl:when>
                <xsl:otherwise><xsl:value-of select="Patienten_Stammdaten/Patienten_Geschlecht"/></xsl:otherwise></xsl:choose>
            </Geschlecht>
            <xsl:if test="Patienten_Stammdaten/Patienten_Geburtsdatum"><Geburtsdatum><xsl:value-of select="Patienten_Stammdaten/Patienten_Geburtsdatum"/></Geburtsdatum></xsl:if>
            <DKTK_LOCAL_ID><xsl:value-of select="$Patient_Pseudonym"/></DKTK_LOCAL_ID>
            <xsl:choose>
                <xsl:when test="Patienten_Stammdaten/DKTK_Einwilligung_erfolgt='ja'"><DKTK_Einwilligung_erfolgt>true</DKTK_Einwilligung_erfolgt></xsl:when>
                <xsl:when test="Patienten_Stammdaten/DKTK_Einwilligung_erfolgt='true'"><DKTK_Einwilligung_erfolgt>true</DKTK_Einwilligung_erfolgt></xsl:when>
                <xsl:otherwise><DKTK_Einwilligung_erfolgt>false</DKTK_Einwilligung_erfolgt></xsl:otherwise>
            </xsl:choose>
            <Vitalstatus_Gesamt>
                <xsl:attribute name="Vitalstatus_ID"><xsl:value-of select="concat($Patient_Id,'vital')"/></xsl:attribute>
                <xsl:choose>
                    <xsl:when test="Patienten_Stammdaten/Vitalstatus_Datum"><Datum_des_letztbekannten_Vitalstatus><xsl:value-of select="Patienten_Stammdaten/Vitalstatus_Datum"/></Datum_des_letztbekannten_Vitalstatus></xsl:when>
                    <xsl:otherwise><xsl:copy-of select="xsi:Datum_des_letztbekannten_Vitalstatus(Menge_Meldung)"/></xsl:otherwise>
                </xsl:choose>
                <xsl:choose>
                    <xsl:when test="lower-case(Patienten_Stammdaten/Vitalstatus)='verstorben'"><Vitalstatus>verstorben</Vitalstatus></xsl:when>
                    <xsl:when test="lower-case(Patienten_Stammdaten/Vitalstatus)='lebend'"><Vitalstatus >lebend</Vitalstatus></xsl:when>
                    <xsl:when test="Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Tod"><Vitalstatus>verstorben</Vitalstatus></xsl:when>
                    <xsl:when test="not(Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Tod)"><Vitalstatus>lebend</Vitalstatus></xsl:when>
                </xsl:choose>
                <xsl:apply-templates select="Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Tod"/>
            </Vitalstatus_Gesamt>
            <xsl:if test="$add_department=true()">
                <Organisationen>
                    <Organisation><xsl:value-of select="/ADT_GEKID/Menge_Melder/Melder[1]/Meldende_Stelle"/></Organisation>
                    <xsl:for-each select="/ADT_GEKID/Menge_Melder/Melder[./@Melder_ID=/ADT_GEKID/Menge_Patient/Patient/Menge_Meldung/Meldung/@Melder_ID]/Melder_KH_Abt_Station_Praxis">
                        <Abteilung>
                            <xsl:value-of select="."/>
                        </Abteilung>
                    </xsl:for-each>
                </Organisationen>
            </xsl:if>

        <!--pass children entities SAMPLE and DIAGNOSIS for further processing-->
            <xsl:if test="./Menge_Meldung/Meldung/Menge_Biomaterial/Biomaterial">
                <xsl:apply-templates select="Menge_Meldung/Meldung/Menge_Biomaterial/Biomaterial[not(@Biomaterial_ID=following::*/@Biomaterial_ID[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id])]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                </xsl:apply-templates>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="./Menge_Meldung/Meldung/Diagnose">
                    <xsl:for-each select="./Menge_Meldung/Meldung/Diagnose[not(@Tumor_ID=following::*/Diagnose[../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id]/@Tumor_ID)]"><!--use foreach loop to allow multiple Diagnoses for one Patient AND ignore multiple identical diagnoses-->
                        <xsl:choose>
                            <xsl:when test="@Tumor_ID">
                               <xsl:apply-templates select="../../../Menge_Meldung" mode="withIds">
                                   <xsl:with-param name="Tumor_Id" select="@Tumor_ID"/><!-- For multiple Diagnoses: assign ID for appropriate structure-->
                                   <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                               </xsl:apply-templates>
                           </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select="../../../Menge_Meldung" mode="noIds"/></xsl:otherwise>
                       </xsl:choose>
                    </xsl:for-each>
                    </xsl:when>
            <xsl:when test="not(./Menge_Meldung/Meldung/Diagnose) and ./Menge_Meldung/Meldung/Tumorzuordnung/@Tumor_ID"><!-- use Tumorzuordnung if no Diagnosis is delivered at all; requieres Tumor IDs -->
                    <!--handle multiple different or similar Tumorzuordnung and place them in the correct tree structure-->
                    <xsl:for-each select="./Menge_Meldung/Meldung/Tumorzuordnung[not(@Tumor_ID=../preceding-sibling::*/Tumorzuordnung/@Tumor_ID)]">
                        <xsl:variable name="TumorID"><xsl:value-of select="./@Tumor_ID"/></xsl:variable>
                         <xsl:apply-templates select="../../../Menge_Meldung" mode="withIds">
                             <xsl:with-param name="Tumor_Id" select="$TumorID"/>
                             <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                         </xsl:apply-templates>
                    </xsl:for-each>
                </xsl:when>
            </xsl:choose>
        </Patient>
    </xsl:template>


    <!--Generate second Level SAMPLE entity (Elements: Entnahmedatum | Patienten_mit_Biomaterial | Fixierungsart | Probentyp | Probenart )-->
    <xsl:template match="Biomaterial">
        <xsl:param name="Patient_Id"/>
        <Sample>
            <xsl:attribute name="Sample_ID" >
                <xsl:variable name="attribute">
                <xsl:choose>
                    <xsl:when test="./@Biomaterial_ID"><xsl:value-of select="@Biomaterial_ID"/></xsl:when>
                    <xsl:when test="./Entnahmedatum">gen:<xsl:value-of select="xsi:DatumID(Entnahmedatum),position()"/></xsl:when>
                    <xsl:otherwise>gen:missing-ID-and-Date</xsl:otherwise>
                </xsl:choose>
                </xsl:variable>
                <xsl:value-of select="concat('bio', hash:hash($Patient_Id, '', string-join($attribute, '')))" />
            </xsl:attribute>
            <xsl:if test="Entnahmedatum"><Entnahmedatum><xsl:value-of select="Entnahmedatum"/></Entnahmedatum></xsl:if>
            <xsl:if test="Patienten_mit_Biomaterial='ja' or Patienten_mit_Biomaterial='Ja' or Patienten_mit_Biomaterial='true'"><Patienten_mit_Biomaterial>true</Patienten_mit_Biomaterial></xsl:if>
            <xsl:if test="Patienten_mit_Biomaterial='nein' or Patienten_mit_Biomaterial='Nein' or Patienten_mit_Biomaterial='false'"><Patienten_mit_Biomaterial>false</Patienten_mit_Biomaterial></xsl:if>
            <xsl:if test="Fixierungsart"><Fixierungsart><xsl:value-of select="Fixierungsart"/></Fixierungsart></xsl:if>
            <xsl:if test="Probentyp"><Probentyp><xsl:value-of select="Probentyp"/></Probentyp></xsl:if>
            <xsl:if test="Probenart"><Probenart><xsl:value-of select="Probenart"/></Probenart></xsl:if>
        </Sample>
    </xsl:template>


    <!--Generate second Level DIAGNOSIS entity (Elements: Alter_bei_Erstdiagnose | Tumor_Diagnosedatum | Diagnose | ICD-Katalog_Version )-->
    <xsl:template match="Menge_Meldung" mode="withIds">
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Patient_Id"/>
        <xsl:variable name="Tumor_Meldung" select="Meldung[Tumorzuordnung/@Tumor_ID=$Tumor_Id]"/>
        <xsl:variable name="Diagnosis_Meldung" select="$Tumor_Meldung/Diagnose[not(@Tumor_ID=following::Diagnose[../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id]/@Tumor_ID)]"/>
        <!--Some cases allow ambiguous "Diagnosedatum": therefore set unambiguous Variable "diagnoseDatum"-->
        <xsl:variable name="diagnoseDatum">
            <xsl:choose>
                <xsl:when test="$Diagnosis_Meldung/Diagnosedatum"><xsl:value-of select="$Diagnosis_Meldung/Diagnosedatum"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="$Tumor_Meldung[1]/Tumorzuordnung/Diagnosedatum"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <Diagnosis>
            <xsl:attribute name="Diagnosis_ID" select="concat('dig', hash:hash($Patient_Id, $Tumor_Id, ''))"/>
            <xsl:if test="$Diagnosis_Meldung"><!-- don't create those elements if no Diagnose is delivered -->
                <xsl:element name="Alter_bei_Erstdiagnose">
                    <xsl:variable name="geb" select="number(replace(../Patienten_Stammdaten/Patienten_Geburtsdatum,'\d\d\.\d\d\.(\d\d\d\d)$','$1'))"/>
                    <xsl:variable name="diag" select="number(replace($diagnoseDatum,'\d\d\.\d\d\.(\d\d\d\d)$','$1'))"/>
                    <xsl:variable name="dif" select="$diag - $geb"/>
                    <xsl:variable name="gebMonths" select="number(replace(../Patienten_Stammdaten/Patienten_Geburtsdatum,'(\d\d)\.(\d\d)\.\d\d\d\d','$2$1'))"/><!--Falls ein Jahr mehr aber ein früherer Zeitpunkt des Jahres besteht (also noch kein ganzes Jahr rum ist) z.B. 14.08.xxxx = 814-->
                    <xsl:variable name="diagMonths" select="number(replace($diagnoseDatum,'(\d\d)\.(\d\d)\.\d\d\d\d','$2$1'))"/>
                    <xsl:if test="$diagMonths &lt; $gebMonths"><xsl:value-of select="$dif -1"/></xsl:if>
                    <xsl:if test="not ($diagMonths &lt; $gebMonths)"><xsl:value-of select="$dif"/></xsl:if>
                </xsl:element>
                <Tumor_Diagnosedatum><xsl:apply-templates select="$diagnoseDatum"/></Tumor_Diagnosedatum>
                <xsl:apply-templates select="$Diagnosis_Meldung/Primaertumor_ICD_Code | $Diagnosis_Meldung/Primaertumor_ICD_Version | $Diagnosis_Meldung/Primaertumor_Diagnosetext | $Diagnosis_Meldung/Primaertumor_Topographie_ICD_O_Freitext | $Diagnosis_Meldung/Diagnosesicherung | $Diagnosis_Meldung/Menge_Weitere_Klassifikation | $Diagnosis_Meldung/Allgemeiner_Leistungszustand"/>
            </xsl:if>
            <!--Generate third Level TUMOR entity (Elements:  Lokalisation | ICD-O_Katalog_Topographie_Version |  Seitenlokalisation ) -->
            <Tumor>
                <xsl:attribute name="Tumor_ID" select="concat('tmr', hash:hash($Patient_Id, $Tumor_Id, ''))"/>
                <xsl:if test="$Diagnosis_Meldung"><!-- don't create those elements if no Diagnose is delivered -->
                    <xsl:if test="$Diagnosis_Meldung/Primaertumor_Topographie_ICD_O"><Lokalisation><xsl:value-of select="$Diagnosis_Meldung/Primaertumor_Topographie_ICD_O"/></Lokalisation></xsl:if>
                    <xsl:if test="$Diagnosis_Meldung/Primaertumor_Topographie_ICD_O_Version"><ICD-O_Katalog_Topographie_Version><xsl:value-of select="$Diagnosis_Meldung/Primaertumor_Topographie_ICD_O_Version"/></ICD-O_Katalog_Topographie_Version></xsl:if>
                    <xsl:if test="$Diagnosis_Meldung/Seitenlokalisation"><Seitenlokalisation><xsl:value-of select="$Diagnosis_Meldung/Seitenlokalisation"/></Seitenlokalisation></xsl:if>
                </xsl:if>
                <!--Initiate all TUMOR child nodes-->
                <xsl:apply-templates select="$Diagnosis_Meldung">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
                <xsl:for-each select="$Tumor_Meldung/Menge_OP/OP">
                    <xsl:choose>
                        <xsl:when test="@OP_ID"><xsl:apply-templates select=".[not(@OP_ID=following::OP[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@OP_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(OP_Datum=following::OP[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/OP_Datum)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldung/Menge_ST/ST">
                    <xsl:choose>
                        <xsl:when test="@ST_ID"><xsl:apply-templates select=".[not(@ST_ID=following::ST[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@ST_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(Menge_Bestrahlung/Bestrahlung/ST_Beginn_Datum=following::ST[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/Menge_Bestrahlung/Bestrahlung/ST_Beginn_Datum)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldung/Menge_SYST/SYST">
                    <xsl:choose>
                        <xsl:when test="@SYST_ID"><xsl:apply-templates select=".[not(@SYST_ID=following::SYST[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@SYST_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(SYST_Beginn_Datum=following::SYST[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/SYST_Beginn_Datum)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldung/Menge_Verlauf/Verlauf">
                    <xsl:choose>
                        <xsl:when test="@Verlauf_ID"><xsl:apply-templates select=".[not(@Verlauf_ID=following::Verlauf[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@Verlauf_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(Untersuchungsdatum_Verlauf=following::Verlauf[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/Untersuchungsdatum_Verlauf)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </Tumor>
        </Diagnosis>
    </xsl:template>


    <xsl:template match="Diagnose">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:for-each select="cTNM|pTNM">
            <xsl:choose>
                <xsl:when test="@TNM_ID"><xsl:apply-templates select=".[
                    not(@TNM_ID=following::TNM[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@TNM_ID) and
                    not(@TNM_ID=following::cTNM[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../@Tumor_ID=$Tumor_Id]/@TNM_ID) and
                    not(@TNM_ID=following::pTNM[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../@Tumor_ID=$Tumor_Id]/@TNM_ID)]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select=".[
                        not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::TNM[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))and
                        not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::pTNM[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../@Tumor_ID=$Tumor_Id]/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))and
                        not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::cTNM[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../@Tumor_ID=$Tumor_Id]/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="Menge_Histologie/Histologie">
            <xsl:choose>
                <xsl:when test="@Histologie_ID"><xsl:apply-templates select=".[
                    not(@Histologie_ID=following::Histologie[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@Histologie_ID)]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select=".[
                        not(concat(Tumor_Histologiedatum,Morphologie_Code,Grading)=following::Histologie[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(Tumor_Histologiedatum,Morphologie_Code,Grading))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="Menge_FM/Fernmetastase">
            <xsl:apply-templates select=".[
                not(concat(FM_Diagnosedatum,FM_Lokalisation)=following::*/Fernmetastase/concat(FM_Diagnosedatum,FM_Lokalisation))]">
                <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Fernmetastase[concat(FM_Diagnosedatum,FM_Lokalisation)=current()/concat(FM_Diagnosedatum,FM_Lokalisation)])" /></xsl:with-param>
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:template>


    <!--Generate fourth Level HISTOLOGY entity (Elements:  Morphologie | ICD-O_Katalog_Morphologie_Version |  Grading ) -->
    <xsl:template match="Histologie">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="Tumor_Histologiedatum !=''">
             <Histology>
                 <xsl:attribute name="Histology_ID">
                     <xsl:variable name="attribute">
                         <xsl:choose>
                             <xsl:when test="@Histologie_ID"><xsl:value-of select="@Histologie_ID"/></xsl:when>
                             <xsl:otherwise>
                                 <xsl:value-of select="'gen',concat(string-join(xsi:DatumID(Tumor_Histologiedatum)),Morphologie_Code,Grading)"/>
                             </xsl:otherwise>
                         </xsl:choose>
                     </xsl:variable>
                     <xsl:value-of select="concat('hist', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))" />
                 </xsl:attribute>
                 <xsl:apply-templates select="Morphologie_Code | Morphologie_ICD_O_Version | Morphologie_Freitext | Grading "/>
                 <xsl:if test="Tumor_Histologiedatum"><Tumor_Histologiedatum><xsl:value-of select="Tumor_Histologiedatum"/></Tumor_Histologiedatum></xsl:if>
                 <xsl:if test="LK_untersucht"><LK_untersucht><xsl:value-of select="LK_untersucht"/></LK_untersucht></xsl:if>
                 <xsl:if test="LK_befallen"><LK_befallen><xsl:value-of select="LK_befallen"/></LK_befallen></xsl:if>
                 <xsl:if test="Sentinel_LK_untersucht"><Sentinel_LK_untersucht><xsl:value-of select="Sentinel_LK_untersucht"/></Sentinel_LK_untersucht></xsl:if>
                 <xsl:if test="Sentinel_LK_befallen"><Sentinel_LK_befallen><xsl:value-of select="Sentinel_LK_befallen"/></Sentinel_LK_befallen></xsl:if>
             </Histology>
        </xsl:if>
    </xsl:template>


    <!--Generate fourth Level METASTASIS entity (Elements:  Datum_diagnostische_Sicherung | Lokalisation_Fernmetastasen |  Fernmetastasen_vorhanden ) -->
    <xsl:template match="Fernmetastase">
        <xsl:param name="counter"/>
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="FM_Lokalisation and FM_Diagnosedatum">
           <Metastasis>
               <xsl:attribute name="Metastasis_ID">
                   <xsl:variable name="attribute" select="'gen',concat(string-join(xsi:DatumID(FM_Diagnosedatum)),FM_Lokalisation,$counter)"/>
                   <xsl:value-of select="concat('fm', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))" />
               </xsl:attribute>
               <xsl:apply-templates select="FM_Diagnosedatum"/>
               <xsl:apply-templates select="FM_Lokalisation"/>
               <Fernmetastasen_vorhanden>ja</Fernmetastasen_vorhanden>
          </Metastasis>
        </xsl:if>
   </xsl:template>


    <!--Generate fourth Level TNM entity (Elements:  TNM-m-Symbol | TNM-T |  TNM-N | TNM-M | TNM-Version | Datum_der_TNM-Dokumentation-Datum_Befund | c-p-u-Präfix_T | c-p-u-Präfix_N | c-p-u-Präfix_M | TNM-r-Symbol | TNM-y-Symbol ) -->
    <xsl:template match="pTNM">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="TNM_Datum !=''">
            <TNM>
                <xsl:attribute name="TNM_ID">
                    <xsl:variable name="attribute">
                        <xsl:choose>
                            <xsl:when test="@TNM_ID"><xsl:value-of select="@TNM_ID"/></xsl:when>
                            <xsl:otherwise><xsl:value-of select="'gen',concat(string-join(xsi:DatumID(TNM_Datum)),TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:value-of select="concat('ptnm', hash:hash($Patient_Id, $Tumor_Id, $attribute))" />
                </xsl:attribute>
                <gesamtpraefix>p</gesamtpraefix>
                <xsl:if test="TNM_m_Symbol"><TNM-m-Symbol><xsl:value-of select="TNM_m_Symbol"/></TNM-m-Symbol></xsl:if>
                <xsl:if test="TNM_T"><TNM-T><xsl:value-of select="TNM_T"/></TNM-T></xsl:if>
                <xsl:if test="TNM_N"><TNM-N><xsl:value-of select="TNM_N"/></TNM-N></xsl:if>
                <xsl:if test="TNM_M"><TNM-M><xsl:value-of select="TNM_M"/></TNM-M></xsl:if>
                <xsl:if test="TNM_Version"><TNM-Version><xsl:value-of select="TNM_Version"/></TNM-Version></xsl:if>
                <xsl:if test="TNM_Datum"><Datum_der_TNM-Dokumentation-Datum_Befund><xsl:value-of select="TNM_Datum"/></Datum_der_TNM-Dokumentation-Datum_Befund></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_T"><c-p-u-Präfix_T><xsl:value-of select="TNM_c_p_u_Praefix_T"/></c-p-u-Präfix_T></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_N"><c-p-u-Präfix_N><xsl:value-of select="TNM_c_p_u_Praefix_N"/></c-p-u-Präfix_N></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_M"><c-p-u-Präfix_M><xsl:value-of select="TNM_c_p_u_Praefix_M"/></c-p-u-Präfix_M></xsl:if>
                <xsl:if test="TNM_r_Symbol"><TNM-r-Symbol><xsl:value-of select="TNM_r_Symbol"/></TNM-r-Symbol></xsl:if>
                <xsl:if test="TNM_y_Symbol"><TNM-y-Symbol><xsl:value-of select="TNM_y_Symbol"/></TNM-y-Symbol></xsl:if>
                <xsl:if test="UICC"><UICC_Stadium><xsl:value-of select="UICC"/></UICC_Stadium></xsl:if>
                <xsl:if test="TNM_L"><TNM-L><xsl:value-of select="TNM_L"/></TNM-L></xsl:if>
                <xsl:if test="TNM_V"><TNM-V><xsl:value-of select="TNM_V"/></TNM-V></xsl:if>
                <xsl:if test="TNM_Pn"><TNM-Pn><xsl:value-of select="TNM_Pn"/></TNM-Pn></xsl:if>
                <xsl:if test="TNM_S"><S><xsl:value-of select="TNM_Pn"/></S></xsl:if>
            </TNM>
        </xsl:if>
    </xsl:template>

    <xsl:template match="cTNM">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="TNM_Datum !=''">
            <TNM>
                <xsl:attribute name="TNM_ID">
                    <xsl:variable name="attribute">
                      <xsl:choose>
                          <xsl:when test="@TNM_ID"><xsl:value-of select="@TNM_ID"/></xsl:when>
                          <xsl:otherwise><xsl:value-of select="'gen',concat(string-join(xsi:DatumID(TNM_Datum)),TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)"/></xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:value-of select="concat('ctnm', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
                </xsl:attribute>
                <gesamtpraefix>c</gesamtpraefix>
                <xsl:if test="TNM_m_Symbol"><TNM-m-Symbol><xsl:value-of select="TNM_m_Symbol"/></TNM-m-Symbol></xsl:if>
                <xsl:if test="TNM_T"><TNM-T><xsl:value-of select="TNM_T"/></TNM-T></xsl:if>
                <xsl:if test="TNM_N"><TNM-N><xsl:value-of select="TNM_N"/></TNM-N></xsl:if>
                <xsl:if test="TNM_M"><TNM-M><xsl:value-of select="TNM_M"/></TNM-M></xsl:if>
                <xsl:if test="TNM_Version"><TNM-Version><xsl:value-of select="TNM_Version"/></TNM-Version></xsl:if>
                <xsl:if test="TNM_Datum"><Datum_der_TNM-Dokumentation-Datum_Befund><xsl:value-of select="TNM_Datum"/></Datum_der_TNM-Dokumentation-Datum_Befund></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_T"><c-p-u-Präfix_T><xsl:value-of select="TNM_c_p_u_Praefix_T"/></c-p-u-Präfix_T></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_N"><c-p-u-Präfix_N><xsl:value-of select="TNM_c_p_u_Praefix_N"/></c-p-u-Präfix_N></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_M"><c-p-u-Präfix_M><xsl:value-of select="TNM_c_p_u_Praefix_M"/></c-p-u-Präfix_M></xsl:if>
                <xsl:if test="TNM_r_Symbol"><TNM-r-Symbol><xsl:value-of select="TNM_r_Symbol"/></TNM-r-Symbol></xsl:if>
                <xsl:if test="TNM_y_Symbol"><TNM-y-Symbol><xsl:value-of select="TNM_y_Symbol"/></TNM-y-Symbol></xsl:if>
                <xsl:if test="UICC"><UICC_Stadium><xsl:value-of select="UICC"/></UICC_Stadium></xsl:if>
                <xsl:if test="TNM_L"><TNM-L><xsl:value-of select="TNM_L"/></TNM-L></xsl:if>
                <xsl:if test="TNM_V"><TNM-V><xsl:value-of select="TNM_V"/></TNM-V></xsl:if>
                <xsl:if test="TNM_Pn"><TNM-Pn><xsl:value-of select="TNM_Pn"/></TNM-Pn></xsl:if>
                <xsl:if test="TNM_S"><S><xsl:value-of select="TNM_Pn"/></S></xsl:if>
            </TNM>
        </xsl:if>
    </xsl:template>

    <xsl:template match="TNM">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="TNM_Datum !=''">
            <TNM>
                <xsl:attribute name="TNM_ID">
                    <xsl:variable name="attribute">
                       <xsl:choose>
                           <xsl:when test="@TNM_ID"><xsl:value-of select="@TNM_ID"/></xsl:when>
                           <xsl:otherwise><xsl:value-of select="'gen',concat(string-join(xsi:DatumID(TNM_Datum)),TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)"/></xsl:otherwise>
                       </xsl:choose>
                    </xsl:variable>
                    <xsl:value-of select="concat('tnm', hash:hash($Patient_Id, $Tumor_Id, $attribute))" />
                </xsl:attribute>
                <gesamtpraefix></gesamtpraefix>
                <xsl:if test="TNM_m_Symbol"><TNM-m-Symbol><xsl:value-of select="TNM_m_Symbol"/></TNM-m-Symbol></xsl:if>
                <xsl:if test="TNM_T"><TNM-T><xsl:value-of select="TNM_T"/></TNM-T></xsl:if>
                <xsl:if test="TNM_N"><TNM-N><xsl:value-of select="TNM_N"/></TNM-N></xsl:if>
                <xsl:if test="TNM_M"><TNM-M><xsl:value-of select="TNM_M"/></TNM-M></xsl:if>
                <xsl:if test="TNM_Version"><TNM-Version><xsl:value-of select="TNM_Version"/></TNM-Version></xsl:if>
                <xsl:if test="TNM_Datum"><Datum_der_TNM-Dokumentation-Datum_Befund><xsl:value-of select="TNM_Datum"/></Datum_der_TNM-Dokumentation-Datum_Befund></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_T"><c-p-u-Präfix_T><xsl:value-of select="TNM_c_p_u_Praefix_T"/></c-p-u-Präfix_T></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_N"><c-p-u-Präfix_N><xsl:value-of select="TNM_c_p_u_Praefix_N"/></c-p-u-Präfix_N></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_M"><c-p-u-Präfix_M><xsl:value-of select="TNM_c_p_u_Praefix_M"/></c-p-u-Präfix_M></xsl:if>
                <xsl:if test="TNM_r_Symbol"><TNM-r-Symbol><xsl:value-of select="TNM_r_Symbol"/></TNM-r-Symbol></xsl:if>
                <xsl:if test="TNM_y_Symbol"><TNM-y-Symbol><xsl:value-of select="TNM_y_Symbol"/></TNM-y-Symbol></xsl:if>
                <xsl:if test="UICC"><UICC_Stadium><xsl:value-of select="UICC"/></UICC_Stadium></xsl:if>
                <xsl:if test="TNM_L"><TNM-L><xsl:value-of select="TNM_L"/></TNM-L></xsl:if>
                <xsl:if test="TNM_V"><TNM-V><xsl:value-of select="TNM_V"/></TNM-V></xsl:if>
                <xsl:if test="TNM_Pn"><TNM-Pn><xsl:value-of select="TNM_Pn"/></TNM-Pn></xsl:if>
                <xsl:if test="TNM_S"><S><xsl:value-of select="TNM_Pn"/></S></xsl:if>
            </TNM>
        </xsl:if>
    </xsl:template>

    <!--Generate fourth Level VERLAUF entity (Elements:  Intention_OP | OP |  Intention_ST | Strahlentherapie | Strahlentherapie_Stellung_zu_operativer_Therapie | Intention_SYST | Chemotherapie | Immuntherapie | Hormontherapie | Knochenmarktransplantation | Weitere_Therapien | Sonstige_Therapieart |
                                                          Systemische_Therapie_Stellung_zu_operativer_Therapie | Lokales-regionäres_Rezidiv | Datum_lokales-regionäres_Rezidiv | Lymphknoten-Rezidiv | Datum_Lymphknoten-Rezidiv | Fernmetastasen | Datum_Fernmetastasen | Ansprechen_im_Verlauf | Untersuchungs-Befunddatum_im_Verlauf ) -->
    <xsl:template match="Verlauf">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="attribute">
            <xsl:choose>
                <xsl:when test="@Verlauf_ID"><xsl:value-of select="@Verlauf_ID"/></xsl:when>
                <xsl:when test="Untersuchungsdatum_Verlauf"><xsl:value-of select="'gen',xsi:DatumID(Untersuchungsdatum_Verlauf)"/></xsl:when>
                <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <Verlauf>
            <xsl:attribute name="Verlauf_ID" select="concat('vrl', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))" />
            <xsl:apply-templates select="Allgemeiner_Leistungszustand"/>
            <xsl:if test="Verlauf_Lokaler_Tumorstatus"><!--Lokales-regionäres_Rezidiv + zugehöriges Datum-->
                <Lokales-regionäres_Rezidiv><xsl:value-of select="Verlauf_Lokaler_Tumorstatus"/></Lokales-regionäres_Rezidiv>
            </xsl:if>
            <xsl:if test="Verlauf_Tumorstatus_Lymphknoten"><!--Lymphknoten-Rezidiv + zugehöriges Datum-->
                <Lymphknoten-Rezidiv><xsl:value-of select="Verlauf_Tumorstatus_Lymphknoten"/></Lymphknoten-Rezidiv>
            </xsl:if>
            <xsl:if test="Verlauf_Tumorstatus_Fernmetastasen"><!--Lymphknoten-Rezidiv+ zugehöriges Datum-->
                <Fernmetastasen><xsl:value-of select="Verlauf_Tumorstatus_Fernmetastasen"/></Fernmetastasen>
            </xsl:if>

            <xsl:if test="Gesamtbeurteilung_Tumorstatus"><Ansprechen_im_Verlauf><xsl:value-of select="Gesamtbeurteilung_Tumorstatus"/></Ansprechen_im_Verlauf></xsl:if><!--Ansprechen_im_Verlauf-->
            <!--<xsl:apply-templates select="./Menge_Verlauf/Verlauf/Gesamtbeurteilung_Tumorstatus"></xsl:apply-templates><!-\-Ansprechen_innerhalb_der_letzten_3_Monate TODO-\->
            <xsl:apply-templates select="./Menge_Verlauf/Verlauf/Untersuchungsdatum_Verlauf"></xsl:apply-templates><!-\-Datum_des_letztbekannten_Verlaufs TODO-\->-->

            <xsl:if test="Untersuchungsdatum_Verlauf !=''"><Datum_Verlauf><xsl:apply-templates select="Untersuchungsdatum_Verlauf/node()"/></Datum_Verlauf></xsl:if>



            <xsl:choose>
             <xsl:when test="TNM/@TNM_ID"><xsl:apply-templates select="TNM[
                 not(@TNM_ID=following::TNM[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@TNM_ID) and
                 not(@TNM_ID=following::Diagnose[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and @Tumor_ID=$Tumor_Id]/cTNM/@TNM_ID) and
                 not(@TNM_ID=following::Diagnose[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and @Tumor_ID=$Tumor_Id]/pTNM/@TNM_ID)]">
                 <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                 <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
             </xsl:apply-templates></xsl:when>
             <xsl:otherwise>
                     <xsl:apply-templates select="TNM[
                         not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::TNM[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))and
                         not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::Diagnose[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and @Tumor_ID=$Tumor_Id]/pTNM/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))and
                         not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::Diagnose[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and @Tumor_ID=$Tumor_Id]/cTNM/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))]">
                         <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                         <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                     </xsl:apply-templates>
                 </xsl:otherwise>
            </xsl:choose>
            <xsl:choose>
                <xsl:when test="Histologie/@Histologie_ID">
                    <xsl:apply-templates select="Histologie[
                        not(@Histologie_ID=following::Histologie[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@Histologie_ID)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="Histologie[
                        not(concat(Tumor_Histologiedatum,Morphologie_Code,Grading)=following::Histologie[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(Tumor_Histologiedatum,Morphologie_Code,Grading))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:for-each select="Menge_FM/Fernmetastase">
                <xsl:apply-templates select=".[
                    not(concat(FM_Diagnosedatum,FM_Lokalisation)=following::*/Fernmetastase/concat(FM_Diagnosedatum,FM_Lokalisation))]">
                    <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Fernmetastase[concat(FM_Diagnosedatum,FM_Lokalisation)=current()/concat(FM_Diagnosedatum,FM_Lokalisation)])" /></xsl:with-param>
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
            </xsl:for-each>
        </Verlauf>
    </xsl:template>

    <xsl:template match="OP">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="attribute">
            <xsl:choose>
                <xsl:when test="@OP_ID"><xsl:value-of select="@OP_ID"/></xsl:when>
                <xsl:when test="OP_Datum"><xsl:value-of select="'gen',xsi:DatumID(OP_Datum)"/></xsl:when>
                <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <OP>
            <xsl:attribute name="OP_ID" select="concat('op', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
            <xsl:apply-templates select="OP_Intention"/>
            <xsl:apply-templates select="OP_Datum"/>
            <xsl:apply-templates select="Menge_OPS/OP_OPS"/>
            <xsl:apply-templates select="OP_OPS_Version"/>
            <xsl:apply-templates select="Residualstatus[not(concat(Lokale_Beurteilung_Residualstatus,Gesamtbeurteilung_Residualstatus)=following-sibling::*/concat(Lokale_Beurteilung_Residualstatus,Gesamtbeurteilung_Residualstatus))]"/>

            <xsl:choose>
                <xsl:when test="TNM/@TNM_ID"><xsl:apply-templates select="TNM[
                    not(@TNM_ID=following::TNM[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@TNM_ID) and
                    not(@TNM_ID=following::Diagnose[@Tumor_ID=$Tumor_Id]/cTNM/@TNM_ID) and
                    not(@TNM_ID=following::Diagnose[@Tumor_ID=$Tumor_Id]/pTNM/@TNM_ID)]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates></xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="TNM[
                        not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::TNM[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))and
                        not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::Diagnose[@Tumor_ID=$Tumor_Id]/pTNM/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))and
                        not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::Diagnose[@Tumor_ID=$Tumor_Id]/cTNM/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:choose>
                <xsl:when test="Histologie/@Histologie_ID">
                    <xsl:apply-templates select="Histologie[
                        not(@Histologie_ID=following::Histologie[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@Histologie_ID)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="Histologie[
                        not(concat(Tumor_Histologiedatum,Morphologie_Code,Grading)=following::Histologie[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(Tumor_Histologiedatum,Morphologie_Code,Grading))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </OP>
    </xsl:template>

    <xsl:template match="ST">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <ST>
            <xsl:variable name="attribute">
                <xsl:choose>
                    <xsl:when test="@ST_ID"><xsl:value-of select="@ST_ID"/></xsl:when>
                    <xsl:when test="Menge_Bestrahlung[1]/Bestrahlung[1]/ST_Beginn_Datum[1]"><xsl:value-of select="'gen',xsi:DatumID(Menge_Bestrahlung[1]/Bestrahlung[1]/ST_Beginn_Datum[1])"/></xsl:when>
                    <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:attribute name="ST_ID" select="concat('st', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
            <xsl:apply-templates select="ST_Intention"></xsl:apply-templates>
            <xsl:apply-templates select="ST_Stellung_OP"></xsl:apply-templates>

            <xsl:apply-templates select="ST_Ende_Grund"/>
            <xsl:apply-templates select="Residualstatus"/>
            <xsl:apply-templates select="Menge_Nebenwirkung">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                <xsl:with-param name="Therapy_Id" select="string-join($attribute, '')"/>
            </xsl:apply-templates>

            <xsl:for-each select="Menge_Bestrahlung/Bestrahlung">
                <xsl:apply-templates select=".[
                    not(concat(ST_Beginn_Datum, ST_Ende_Datum, ST_Applikationsart, ST_Zielgebiet, ST_Seite_Zielgebiet, ST_Gesamtdosis/Dosis, ST_Einzeldosis/Dosis)=following::*/Bestrahlung/concat(ST_Beginn_Datum, ST_Ende_Datum, ST_Applikationsart, ST_Zielgebiet, ST_Seite_Zielgebiet, ST_Gesamtdosis/Dosis, ST_Einzeldosis/Dosis))]">
                    <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Bestrahlung[concat(ST_Beginn_Datum, ST_Ende_Datum, ST_Applikationsart, ST_Zielgebiet, ST_Seite_Zielgebiet, ST_Gesamtdosis/Dosis, ST_Einzeldosis/Dosis)=current()/concat(ST_Beginn_Datum, ST_Ende_Datum, ST_Applikationsart, ST_Zielgebiet, ST_Seite_Zielgebiet, ST_Gesamtdosis/Dosis, ST_Einzeldosis/Dosis)])" /></xsl:with-param>
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
            </xsl:for-each>
        </ST>
    </xsl:template>


    <xsl:template match="SYST">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <SYST>
            <xsl:variable name="attribute">
                <xsl:choose>
                    <xsl:when test="@SYST_ID"><xsl:value-of select="@SYST_ID"/></xsl:when>
                    <xsl:when test="SYST_Beginn_Datum"><xsl:value-of select="'gen',xsi:DatumID(SYST_Beginn_Datum)"/></xsl:when>
                    <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
                </xsl:choose></xsl:variable>
            <xsl:attribute name="SYST_ID" select="concat('syst', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
            <xsl:apply-templates select="SYST_Intention"></xsl:apply-templates>
            <xsl:apply-templates select="SYST_Stellung_OP"></xsl:apply-templates>
            <xsl:apply-templates select="Menge_Therapieart"/>
            <xsl:apply-templates select="SYST_Ende_Grund"/>
            <xsl:apply-templates select="Residualstatus"/>
            <xsl:apply-templates select="Menge_Nebenwirkung">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                <xsl:with-param name="Therapy_Id" select="string-join($attribute, '')"/>
            </xsl:apply-templates>
            <xsl:if test="SYST_Beginn_Datum"><Systemische_Therapie_Beginn><xsl:value-of select="SYST_Beginn_Datum"/></Systemische_Therapie_Beginn></xsl:if>
            <xsl:if test="SYST_Ende_Datum"><Systemische_Therapie_Ende><xsl:value-of select="SYST_Ende_Datum"/></Systemische_Therapie_Ende></xsl:if>
            <xsl:if test="SYST_Protokoll"><Systemische_Therapie_Protokoll><xsl:value-of select="SYST_Protokoll"/></Systemische_Therapie_Protokoll></xsl:if>
            <xsl:apply-templates select="Menge_Substanz"/>
        </SYST>
    </xsl:template>

    <!-- Sub functions -->

    <xsl:template match="Menge_Nebenwirkung">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Therapy_Id"/>
        <xsl:apply-templates select="ST_Nebenwirkung[not(concat(Nebenwirkung_Grad,Nebenwirkung_Art,Nebenwirkung_Version)=following-sibling::*/concat(Nebenwirkung_Grad,Nebenwirkung_Art,Nebenwirkung_Version))]">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            <xsl:with-param name="Therapy_Id" select="$Therapy_Id"/>
            </xsl:apply-templates>
        <xsl:apply-templates select="SYST_Nebenwirkung[not(concat(Nebenwirkung_Grad,Nebenwirkung_Art,Nebenwirkung_Version)=following-sibling::*/concat(Nebenwirkung_Grad,Nebenwirkung_Art,Nebenwirkung_Version))]">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                <xsl:with-param name="Therapy_Id" select="$Therapy_Id"/>
            </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="ST_Nebenwirkung">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Therapy_Id"/>
        <xsl:if test="Nebenwirkung_Grad!=''">
            <Nebenwirkung>
                <xsl:attribute name="Nebenwirkung_ID" select="concat('stn', hash:hash($Patient_Id, $Tumor_Id, concat($Therapy_Id, Nebenwirkung_Art, Nebenwirkung_Grad, Nebenwirkung_Version)))"/>
                <Grad><xsl:value-of select="Nebenwirkung_Grad"/></Grad>
                <xsl:if test="Nebenwirkung_Version!=''"><Version><xsl:value-of select="Nebenwirkung_Version"/></Version></xsl:if>
                <xsl:if test="Nebenwirkung_Art!=''"><Art><xsl:value-of select="Nebenwirkung_Art"/></Art></xsl:if>
                <Art_Typ>ADT2</Art_Typ>
            </Nebenwirkung>
        </xsl:if>
    </xsl:template>

    <xsl:template match="SYST_Nebenwirkung">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Therapy_Id"/>
        <xsl:if test="Nebenwirkung_Grad!=''">
            <Nebenwirkung>
                <xsl:attribute name="Nebenwirkung_ID" select="concat('syn', concat($Patient_Id, $Tumor_Id, concat($Therapy_Id, Nebenwirkung_Art, Nebenwirkung_Grad, Nebenwirkung_Version)))"/>
                <Grad><xsl:value-of select="Nebenwirkung_Grad"/></Grad>
                <xsl:if test="Nebenwirkung_Version!=''"><Version><xsl:value-of select="Nebenwirkung_Version"/></Version></xsl:if>
                <xsl:if test="Nebenwirkung_Art!=''"><Art><xsl:value-of select="Nebenwirkung_Art"/></Art></xsl:if>
                <Art_Typ>ADT2</Art_Typ>
            </Nebenwirkung>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Menge_Therapieart">
        <Therapieart><xsl:value-of select="xsi:oBDS-mapping-therapy(SYST_Therapieart)"/></Therapieart>
        <Therapieart_original><xsl:value-of select="SYST_Therapieart"/></Therapieart_original>
    </xsl:template>

    <xsl:template match="Tod">
        <Tod>
            <xsl:apply-templates select="Sterbedatum | Tod_tumorbedingt | Menge_Todesursache"></xsl:apply-templates>
        </Tod>
    </xsl:template>

    <xsl:template match="Menge_Todesursache">
        <Menge_Todesursachen>
            <xsl:for-each select="Todesursache_ICD">
                <Todesursache_ICD>
                    <xsl:apply-templates select=". | ../Todesursache_ICD_Version"></xsl:apply-templates>
                </Todesursache_ICD>
            </xsl:for-each>
        </Menge_Todesursachen>
    </xsl:template>

    <xsl:template match="Residualstatus">
        <xsl:if test="Lokale_Beurteilung_Residualstatus | Gesamtbeurteilung_Residualstatus">
           <xsl:if test="Lokale_Beurteilung_Residualstatus"><Lokale_Beurteilung_Resttumor><xsl:value-of select="Lokale_Beurteilung_Residualstatus"/></Lokale_Beurteilung_Resttumor></xsl:if>
           <xsl:if test="Gesamtbeurteilung_Residualstatus"><Gesamtbeurteilung_Resttumor><xsl:value-of select="Gesamtbeurteilung_Residualstatus"/></Gesamtbeurteilung_Resttumor></xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Bestrahlung">
        <xsl:param name="counter"/>
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <Bestrahlung>
            <xsl:attribute name="Betrahlung_ID" select="concat('sts', hash:hash($Patient_Id, $Tumor_Id, concat(ST_Beginn_Datum, ST_Ende_Datum, ST_Applikationsart, ST_Zielgebiet, ST_Seite_Zielgebiet, ST_Gesamtdosis/Dosis, ST_Einzeldosis/Dosis)),'-',$counter)"/>
            <xsl:if test="ST_Zielgebiet"><ST_Zielgebiet><xsl:value-of select="ST_Zielgebiet"/></ST_Zielgebiet></xsl:if>
            <xsl:if test="ST_Seite_Zielgebiet"><ST_Seite_Zielgebiet><xsl:value-of select="ST_Seite_Zielgebiet"/></ST_Seite_Zielgebiet></xsl:if>
            <xsl:if test="ST_Beginn_Datum"><ST_Beginn_Datum><xsl:value-of select="ST_Beginn_Datum"/></ST_Beginn_Datum></xsl:if>
            <xsl:if test="ST_Ende_Datum"><ST_Ende_Datum><xsl:value-of select="ST_Ende_Datum"/></ST_Ende_Datum></xsl:if>
            <xsl:if test="ST_Applikationsart"><ST_Applikationsart><xsl:value-of select="ST_Applikationsart"/></ST_Applikationsart></xsl:if>
            <xsl:apply-templates select="ST_Gesamtdosis"/>
            <xsl:apply-templates select="ST_Einzeldosis"/>
        </Bestrahlung>
    </xsl:template>

    <xsl:template match="ST_Gesamtdosis">
        <ST_Gesamtdosis>
            <xsl:if test="Dosis"><Dosis><xsl:value-of select="Dosis"/></Dosis></xsl:if>
            <xsl:if test="Einheit"><Einheit><xsl:value-of select="Einheit"/></Einheit></xsl:if>
        </ST_Gesamtdosis>
    </xsl:template>

    <xsl:template match="ST_Einzeldosis">
        <ST_Einzeldosis>
            <xsl:if test="Dosis"><Dosis><xsl:value-of select="Dosis"/></Dosis></xsl:if>
            <xsl:if test="Einheit"><Einheit><xsl:value-of select="Einheit"/></Einheit></xsl:if>
        </ST_Einzeldosis>
    </xsl:template>

    <xsl:template match="Menge_Weitere_Klassifikation">
        <Menge_Weitere_Klassifikation>
            <xsl:for-each select="Weitere_Klassifikation">
                <Weitere_Klassifikation>
                    <xsl:if test="Datum"><Datum><xsl:value-of select="Datum"/></Datum></xsl:if>
                    <xsl:if test="Name"><Name><xsl:value-of select="Name"/></Name></xsl:if>
                    <xsl:if test="Stadium"><Stadium><xsl:value-of select="Stadium"/></Stadium></xsl:if>
                </Weitere_Klassifikation>
            </xsl:for-each>
        </Menge_Weitere_Klassifikation>
    </xsl:template>

    <xsl:template match="Menge_Substanz">
        <xsl:apply-templates select="SYST_Substanz"/>
    </xsl:template>

    <!--!!!!!!!!!!STRUCTURE TRANSFORMATION COMPLETED!!!!!!!!!!-->


    <!--Rename elements according to MDS-->
    <xsl:template match="Patienten_Geburtsdatum">
        <Geburtsdatum>
            <xsl:apply-templates select="node() | @*"/>
        </Geburtsdatum>
    </xsl:template>
    <xsl:template match="Grading">
        <Grading>
            <xsl:apply-templates select="node() | @*"/>
        </Grading>
    </xsl:template>
    <xsl:template match="Patienten_Geschlecht" >
        <Geschlecht>
            <xsl:apply-templates select="node() | @*"/>
        </Geschlecht>
    </xsl:template>
    <xsl:template match="Primaertumor_ICD_Code" >
        <Diagnose>
            <xsl:apply-templates select="node() | @*"/>
        </Diagnose>
    </xsl:template>
    <xsl:template match="Primaertumor_ICD_Version" >
        <ICD-Katalog_Version>
            <xsl:apply-templates select="node() | @*"/>
        </ICD-Katalog_Version>
    </xsl:template>
    <xsl:template match="Primaertumor_Diagnosetext" >
        <Diagnose_Text>
            <xsl:apply-templates select="node() | @*"/>
        </Diagnose_Text>
    </xsl:template>
    <xsl:template match="Primaertumor_Topographie_ICD_O" >
        <Lokalisation>
            <xsl:apply-templates select="node() | @*"/>
        </Lokalisation>
    </xsl:template>
    <xsl:template match="Primaertumor_Topographie_ICD_O_Version" >
        <ICD-O_Katalog_Topographie_Version>
            <xsl:apply-templates select="node() | @*"/>
        </ICD-O_Katalog_Topographie_Version>
    </xsl:template>
    <xsl:template match="Primaertumor_Topographie_ICD_O_Freitext" >
        <Primaertumor_Topographie_Freitext>
            <xsl:apply-templates select="node() | @*"/>
            </Primaertumor_Topographie_Freitext>
    </xsl:template>
    <xsl:template match="Diagnosesicherung" >
        <Diagnosesicherung>
            <xsl:apply-templates select="node() | @*"/>
        </Diagnosesicherung>
    </xsl:template>
    <xsl:template match="Allgemeiner_Leistungszustand" >
        <xsl:variable name="ecog" select="xsi:mapToECOG(node())"/>
        <xsl:if test="string-length($ecog)>=1">
            <ECOG>
                <xsl:value-of select="$ecog"/>
            </ECOG>
        </xsl:if>
    </xsl:template>
    <xsl:template match="Morphologie_Code" >
        <Morphologie>
            <xsl:apply-templates select="node() | @*"/>
        </Morphologie>
    </xsl:template>
    <xsl:template match="Morphologie_ICD_O_Version" >
        <ICD-O_Katalog_Morphologie_Version>
            <xsl:apply-templates select="node() | @*"/>
        </ICD-O_Katalog_Morphologie_Version>
    </xsl:template>
    <xsl:template match="Morphologie_Freitext" >
        <Morphologie_Freitext>
            <xsl:apply-templates select="node() | @*"/>
        </Morphologie_Freitext>
    </xsl:template>
    <xsl:template match="FM_Diagnosedatum" >
        <Datum_diagnostische_Sicherung>
            <xsl:apply-templates select="node() | @*"/>
        </Datum_diagnostische_Sicherung>
    </xsl:template>
    <xsl:template match="FM_Lokalisation" >
        <Lokalisation_Fernmetastasen>
            <xsl:apply-templates select="node() | @*"/>
        </Lokalisation_Fernmetastasen>
    </xsl:template>
    <xsl:template match="TNM_Datum" >
        <Datum_der_TNM-Dokumentation-Datum_Befund>
            <xsl:apply-templates select="node() | @*"/>
        </Datum_der_TNM-Dokumentation-Datum_Befund>
    </xsl:template>
    <xsl:template match="Diagnosedatum">
        <Tumor_Diagnosedatum>
            <xsl:apply-templates select="node() | @*"/>
        </Tumor_Diagnosedatum>
    </xsl:template>
    <xsl:template match="TNM_m_Symbol">
        <TNM-m-Symbol>
        <xsl:apply-templates select="node() | @*"/>
        </TNM-m-Symbol>
    </xsl:template>
    <xsl:template match="TNM_T">
        <TNM-T>
        <xsl:apply-templates select="node() | @*"/>
        </TNM-T>
    </xsl:template>
    <xsl:template match="TNM_N">
        <TNM-N>
        <xsl:apply-templates select="node() | @*"/>
        </TNM-N>
    </xsl:template>
    <xsl:template match="TNM_M">
        <TNM-M>
        <xsl:apply-templates select="node() | @*"/>
        </TNM-M>
    </xsl:template>
    <xsl:template match="TNM_Version">
        <TNM-Version>
        <xsl:apply-templates select="node() | @*"/>
        </TNM-Version>
    </xsl:template>
    <xsl:template match="TNM_c_p_u_Praefix_T">
        <c-p-u-Präfix_T>
            <xsl:apply-templates select="node() | @*"/>
        </c-p-u-Präfix_T>
    </xsl:template>
    <xsl:template match="TNM_c_p_u_Praefix_N">
        <c-p-u-Präfix_N>
            <xsl:apply-templates select="node() | @*"/>
        </c-p-u-Präfix_N>
    </xsl:template>
    <xsl:template match="TNM_c_p_u_Praefix_M">
        <c-p-u-Präfix_M>
            <xsl:apply-templates select="node() | @*"/>
        </c-p-u-Präfix_M>
    </xsl:template>
    <xsl:template match="TNM_y_Symbol">
        <TNM-y-Symbol>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-y-Symbol>
    </xsl:template>
    <xsl:template match="TNM_r_Symbol">
        <TNM-r-Symbol>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-r-Symbol>
    </xsl:template>
    <xsl:template match="OP_Intention">
        <Intention_OP>
        <xsl:apply-templates select="node() | @*"/>
        </Intention_OP>
    </xsl:template>
    <xsl:template match="ST_Intention">
        <Intention_Strahlentherapie>
        <xsl:apply-templates select="node() | @*"/>
        </Intention_Strahlentherapie>
    </xsl:template>
    <xsl:template match="SYST_Intention">
        <Intention_Chemotherapie>
        <xsl:apply-templates select="node() | @*"/>
        </Intention_Chemotherapie>
    </xsl:template>
    <xsl:template match="ST_Stellung_OP">
        <Strahlentherapie_Stellung_zu_operativer_Therapie>
            <xsl:apply-templates select="node() | @*"/>
        </Strahlentherapie_Stellung_zu_operativer_Therapie>
    </xsl:template>
    <xsl:template match="SYST_Stellung_OP">
        <Systemische_Therapie_Stellung_zu_operativer_Therapie>
            <xsl:apply-templates select="node() | @*"/>
        </Systemische_Therapie_Stellung_zu_operativer_Therapie>
    </xsl:template>
    <xsl:template match="Untersuchungsdatum_Verlauf">
        <Untersuchungs-Befunddatum_im_Verlauf>
            <xsl:apply-templates select="node() | @*"/>
        </Untersuchungs-Befunddatum_im_Verlauf>
    </xsl:template>
    <xsl:template match="SYST_Ende_Grund">
        <SYST_Ende_Grund>
            <xsl:apply-templates select="node() | @*"/>
        </SYST_Ende_Grund>
    </xsl:template>
    <xsl:template match="SYST_Substanz">
        <SYST_Substanz>
            <xsl:apply-templates select="node() | @*"/>
        </SYST_Substanz>
    </xsl:template>

    <!-- remove ADT Namespace -->
    <xsl:template match="OP_OPS">
        <OP_OPS>
            <xsl:apply-templates select="node() | @*"/>
        </OP_OPS>
    </xsl:template>
    <xsl:template match="OP_OPS_Version">
        <OP_OPS_Version>
            <xsl:apply-templates select="node() | @*"/>
        </OP_OPS_Version>
    </xsl:template>
    <xsl:template match="OP_Datum">
        <OP_Datum>
            <xsl:apply-templates select="node() | @*"/>
        </OP_Datum>
    </xsl:template>
    <xsl:template match="ST_Ende_Grund">
        <ST_Ende_Grund>
            <xsl:apply-templates select="node() | @*"/>
        </ST_Ende_Grund>
    </xsl:template>
    <xsl:template match="Sterbedatum">
        <Sterbedatum>
            <xsl:apply-templates select="node() | @*"/>
        </Sterbedatum>
    </xsl:template>
    <xsl:template match="Tod_tumorbedingt">
        <Tod_tumorbedingt>
            <xsl:apply-templates select="node() | @*"/>
        </Tod_tumorbedingt>
    </xsl:template>
    <xsl:template match="Todesursache_ICD">
        <Code>
            <xsl:apply-templates select="node() | @*"/>
        </Code>
    </xsl:template>
    <xsl:template match="Todesursache_ICD_Version">
        <Version>
            <xsl:apply-templates select="node() | @*"/>
        </Version>
    </xsl:template>



    <!--Remove unnescessary parents-->
    <xsl:template match="Patienten_Stammdaten  | ADT_GEKID | Menge_Verlauf | Menge_OP | Menge_ST | Menge_SYST | Menge_Biomaterial ">
        <xsl:apply-templates select="*"/>
    </xsl:template>

    <xsl:template match="Absender"/>
    <xsl:template match="Menge_Frueherer_Name"/>
    <xsl:template match="Menge_Adresse"/>
    <xsl:template match="Meldedatum"/>
    <xsl:template match="Meldebegruendung"/>
    <xsl:template match="Meldeanlass"/>
    <xsl:template match="Tumorzuordnung"/>
    <xsl:template match="Menge_Tumorkonferenz"/>
    <xsl:template match="Menge_Zusatzitem"/>
    <xsl:template match="KrankenversichertenNr"/>
    <xsl:template match="KrankenkassenNr"/>
    <xsl:template match="Menge_Melder"/>
    <xsl:template match="Menge_Fruehere_Tumorerkrankung"/>


    <!--!!!!!!!!!!FUNCTION DEFINITIONS!!!!!!!!!!-->
    <xsl:function name="xsi:Datum_des_letztbekannten_Vitalstatus">
        <xsl:param name="meldungen"/>
        <xsl:choose>
            <xsl:when test="$meldungen/Meldung/Menge_Verlauf/Verlauf/Tod/Sterbedatum">
                <xsl:variable name="datum" select="max($meldungen/Meldung/Menge_Verlauf/Verlauf/Tod/(replace(Sterbedatum,'(\d\d)\.(\d\d)\.(\d\d\d\d)$','$3$2$1')))"/>
                <Datum_des_letztbekannten_Vitalstatus><xsl:value-of select="replace($datum,'(\d\d\d\d)(\d\d)(\d\d)$','$3.$2.$1')"/></Datum_des_letztbekannten_Vitalstatus>
            </xsl:when>
            <xsl:when test="$meldungen/Meldung/Menge_Verlauf/Verlauf/Untersuchungsdatum_Verlauf">
                <xsl:variable name="datum" select="max($meldungen/Meldung/Menge_Verlauf/Verlauf/(replace(Untersuchungsdatum_Verlauf,'(\d\d)\.(\d\d)\.(\d\d\d\d)$','$3$2$1')))"/>
<!--                <Datum_des_letztbekannten_Vitalstatus><xsl:value-of select="(replace($datum,'(\d\d\d\d)(\d\d)(\d\d)$','$2.$1'))"/></Datum_des_letztbekannten_Vitalstatus>-->
                <Datum_des_letztbekannten_Vitalstatus><xsl:value-of select="replace($datum,'(\d\d\d\d)(\d\d)(\d\d)$','$3.$2.$1')"/></Datum_des_letztbekannten_Vitalstatus>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="datum" select="max($meldungen/Meldung/Tumorzuordnung/(replace(Diagnosedatum,'(\d\d)\.(\d\d)\.(\d\d\d\d)$','$3$2$1')))"/><!--If Verlauf does not exist-->
<!--                <Datum_des_letztbekannten_Vitalstatus><xsl:value-of select="(replace($datum,'(\d\d\d\d)(\d\d)(\d\d)$','$2.$1'))"/></Datum_des_letztbekannten_Vitalstatus>-->
                <Datum_des_letztbekannten_Vitalstatus><xsl:value-of select="replace($datum,'(\d\d\d\d)(\d\d)(\d\d)$','$3.$2.$1')"/></Datum_des_letztbekannten_Vitalstatus>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="xsi:DatumID">
        <xsl:param name="datum"/>
        <xsl:variable name="day" select="string(replace($datum,'(\d\d\.)\d\d\.\d\d\d\d$','$1'))"/>
        <xsl:choose>
            <xsl:when test="$day='00.'"><xsl:value-of select="1"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="round(number($day) * 2.5)"/></xsl:otherwise>
        </xsl:choose>
        <xsl:variable name="week" select="string(replace($datum,'\d\d\.(\d\d\.)\d\d\d\d$','$1'))"/>
        <xsl:choose>
            <xsl:when test="$week='00.'"><xsl:value-of select="1"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="round(number($week) * 1.8)"/></xsl:otherwise>
        </xsl:choose>
        <xsl:value-of select="number(string(replace($datum,'\d\d\.\d\d\.(\d\d\d\d)$','$1')))*8"/>
    </xsl:function>

    <xsl:function name="xsi:Pseudonymize">
        <xsl:param name="gender"/>
        <xsl:param name="prename"/>
        <xsl:param name="surname"/>
        <xsl:param name="birthname"/>
        <xsl:param name="brithdate"/>
        <xsl:param name="identifier"/>
        <xsl:value-of select="hash:pseudonymize(xsi:ReplaceEmpty($gender), xsi:ReplaceEmpty($prename), xsi:ReplaceEmpty($surname), xsi:ReplaceEmpty($birthname), xsi:ReplaceEmpty($brithdate), xsi:ReplaceEmpty($identifier))"/>
    </xsl:function>

    <xsl:function name="xsi:ReplaceEmpty">
        <xsl:param name="toReplace"/>
        <xsl:choose>
            <xsl:when test="string-length($toReplace)>0">
                <xsl:value-of select="$toReplace"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="'empty'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="xsi:oBDS-mapping-therapy">
        <xsl:param name="toReplace"/>
        <xsl:choose>
            <xsl:when test="contains(string-join($toReplace, ','), 'CH')">
                <xsl:choose>
                    <xsl:when test="contains(string-join($toReplace, ','), 'IM')">
                        <xsl:choose>
                            <xsl:when test="contains(string-join($toReplace, ','), 'ZS')">
                                <xsl:value-of select="'CIZ'"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="'CI'"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:when test="contains(string-join($toReplace, ','), 'ZS')">
                        <xsl:value-of select="'CZ'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="'CH'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'IM')">
                <xsl:choose>
                    <xsl:when test="contains(string-join($toReplace, ','), 'ZS')">
                        <xsl:value-of select="'IZ'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="'IM'"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'HO')">
                <xsl:value-of select="'HO'"/>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'KM')">
                <xsl:value-of select="'SZ'"/>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'ZS')">
                <xsl:value-of select="'ZS'"/>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'AS')">
                <xsl:value-of select="'AS'"/>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'WS')">
                <xsl:value-of select="'WS'"/>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'SO')">
                <xsl:value-of select="'SO'"/>
            </xsl:when>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="xsi:mapToECOG">
        <xsl:param name="value"/>
        <xsl:if test="$value !=''">
            <xsl:choose>
                <xsl:when test="matches($value, '\d\d%')"><!-- Karnofsky; map to ECOG -->
                    <xsl:choose>
                        <xsl:when test="number(substring($value, 1, 2)) >= 90">
                            <xsl:value-of select="number('0')"/>
                        </xsl:when>
                        <xsl:when test="number(substring($value, 1, 2)) >= 70">
                            <xsl:value-of select="number('1')"/>
                        </xsl:when>
                        <xsl:when test="number(substring($value, 1, 2)) >= 50">
                            <xsl:value-of select="number('2')"/>
                        </xsl:when>
                        <xsl:when test="number(substring($value, 1, 2)) >= 30">
                            <xsl:value-of select="number('3')"/>
                        </xsl:when>
                        <xsl:when test="number(substring($value, 1, 2)) >= 10">
                            <xsl:value-of select="number('4')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="'error'"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="matches($value, '[0-4U]')"><!-- ECOG; use directly-->
                    <xsl:value-of select="$value"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="'error -',$value"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:function>
</xsl:stylesheet>
