<?xml version="1.0" encoding="utf-8" standalone="no"?>
<xsl:stylesheet xmlns="http://www.mds.de/namespace"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xsi="http://www.mds.de/namespace MDS_Suchmodell_v4.xsd"
    exclude-result-prefixes="#default" 
    version="2.0"
    xpath-default-namespace="http://www.gekid.de/namespace">
    
    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    <xsl:output omit-xml-declaration="no" indent="yes"/>
    <xsl:strip-space elements="*"/>
    
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
            <xsl:attribute name="Patient_ID">
                <xsl:value-of select="Patienten_Stammdaten/@Patient_ID"/>
            </xsl:attribute>
            <Geschlecht>
                <xsl:choose><xsl:when test="Patienten_Stammdaten/Patienten_Geschlecht = 'D'">S</xsl:when>
                <xsl:otherwise><xsl:value-of select="Patienten_Stammdaten/Patienten_Geschlecht"/></xsl:otherwise></xsl:choose>
            </Geschlecht>
            <Geburtsdatum><xsl:value-of select="Patienten_Stammdaten/Patienten_Geburtsdatum"/></Geburtsdatum>
            <xsl:if test="Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Untersuchungsdatum_Verlauf | Menge_Meldung/Meldung/Tumorzuordnung/Diagnosedatum"><xsl:copy-of select="xsi:Datum_des_letztbekannten_Vitalstatus(Menge_Meldung)"/></xsl:if>
            <xsl:if test="Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Tod"><Vitalstatus>verstorben</Vitalstatus></xsl:if>
            <xsl:if test="not(Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Tod)"><Vitalstatus >lebend</Vitalstatus></xsl:if>
            <DKTK_ID>PLACEHOLDER</DKTK_ID>
            <DKTK_LOCAL_ID><xsl:value-of select="Patienten_Stammdaten/@Patient_ID"/></DKTK_LOCAL_ID>
            <xsl:choose>
                <xsl:when test="Patienten_Stammdaten/DKTK_Einwilligung_erfolgt='ja'"><DKTK_Einwilligung_erfolgt>true</DKTK_Einwilligung_erfolgt></xsl:when>
                <xsl:when test="Patienten_Stammdaten/DKTK_Einwilligung_erfolgt='true'"><DKTK_Einwilligung_erfolgt>true</DKTK_Einwilligung_erfolgt></xsl:when>
                <xsl:otherwise><DKTK_Einwilligung_erfolgt>false</DKTK_Einwilligung_erfolgt></xsl:otherwise>
            </xsl:choose>
            <Upload_Zeitpunkt_ZS_Antwort>PLACEHOLDER</Upload_Zeitpunkt_ZS_Antwort>
            <Upload_Zeitpunkt_ZS_Erfolg>PLACEHOLDER</Upload_Zeitpunkt_ZS_Erfolg>
            
            <!--pass children entities SAMPLE and DIAGNOSIS for further processing-->
            <xsl:if test="./Menge_Meldung/Meldung/Menge_Biomaterial/Biomaterial"><xsl:apply-templates select="./Menge_Meldung/Meldung/Menge_Biomaterial/Biomaterial"></xsl:apply-templates></xsl:if>
            <xsl:for-each select="./Menge_Meldung/Meldung/Diagnose[not(@Tumor_ID=../preceding-sibling::*/Diagnose/@Tumor_ID)]"><!--use foreach loop to allow multiple Diagnoses for one Patient AND ignore multiple identical diagnoses-->
                <xsl:choose>
                    <xsl:when test="@Tumor_ID">
                        <xsl:apply-templates select="../../../Menge_Meldung" mode="withIds">
                            <xsl:with-param name="Tumor_Id" select="@Tumor_ID"></xsl:with-param><!-- For multiple Diagnoses: assign ID for appropriate structure-->
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise><xsl:apply-templates select="../../../Menge_Meldung" mode="noIds"/></xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </Patient>
    </xsl:template>
    
    
    <!--Generate second Level SAMPLE entity (Elements: Entnahmedatum | Patienten_mit_Biomaterial | Fixierungsart | Probentyp | Probenart )-->
    <xsl:template match="Biomaterial">
        <Sample>
            <xsl:attribute name="Sample_ID" ><xsl:value-of select="@Biomaterial_ID"/></xsl:attribute>
            <Entnahmedatum><xsl:value-of select="Entnahmedatum"/></Entnahmedatum>
            <xsl:if test="Patienten_mit_Biomaterial='ja'"><Patienten_mit_Biomaterial>true</Patienten_mit_Biomaterial></xsl:if>
            <xsl:if test="Patienten_mit_Biomaterial='nein'"><Patienten_mit_Biomaterial>false</Patienten_mit_Biomaterial></xsl:if>
            <Fixierungsart><xsl:value-of select="Fixierungsart"/></Fixierungsart>
            <Probentyp><xsl:value-of select="Probentyp"/></Probentyp>
            <Probenart><xsl:value-of select="Probenart"/></Probenart>
        </Sample>
    </xsl:template>
    
    
    <!--Generate second Level DIAGNOSIS entity (Elements: Alter_bei_Erstdiagnose | Tumor_Diagnosedatum | Diagnose | ICD-Katalog_Version )-->
    <xsl:template match="Menge_Meldung" mode="withIds">
        <xsl:param name="Tumor_Id"></xsl:param>
        <!--Some cases allow ambiguous "Diagnosedatum": therefore set unambiguous Variable "diagnoseDatum"-->
        <xsl:variable name="diagnoseDatum">
            <xsl:choose>
                <xsl:when test="./Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Diagnose[./@Tumor_ID=$Tumor_Id]/Diagnosedatum"><xsl:value-of select="./Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Diagnose[./@Tumor_ID=$Tumor_Id]/Diagnosedatum"/></xsl:when><!--Use Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1], because some sites provide unnecessary multiple identical diagnoses-->
                <xsl:otherwise><xsl:value-of select="./Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Tumorzuordnung[./@Tumor_ID=$Tumor_Id]/Diagnosedatum"/></xsl:otherwise><!--Complex legal ADT cases (multiple identical and multiple different Diagnosis entities in the same Menge_Meldung) require complex calling methods (Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Diagnose[./@Tumor_ID=$Tumor_Id]/Diagnosedatum)--> 
            </xsl:choose>
        </xsl:variable>
        
        <Diagnosis>
            <xsl:attribute name="Diagnosis_ID" select="$Tumor_Id"/>
            <xsl:element name="Alter_bei_Erstdiagnose">
                <xsl:variable name="geb" select="number(replace(../Patienten_Stammdaten/Patienten_Geburtsdatum,'\d\d\.\d\d\.(\d\d\d\d)$','$1'))"/>
                <xsl:variable name="diag" select="number(replace($diagnoseDatum,'\d\d\.\d\d\.(\d\d\d\d)$','$1'))"/>
                <xsl:variable name="dif" select="$diag - $geb"/>
                <xsl:variable name="gebMonths" select="number(replace(../Patienten_Stammdaten/Patienten_Geburtsdatum,'(\d\d)\.(\d\d)\.\d\d\d\d','$2$1'))"/><!--Falls ein Jahr mehr aber ein früherer Zeitpunkt des Jahres besteht (also noch kein ganzes Jahr rum ist) z.B. 14.08.xxxx = 814-->
                <xsl:variable name="diagMonths" select="number(replace($diagnoseDatum,'(\d\d)\.(\d\d)\.\d\d\d\d','$2$1'))"/>
                <xsl:if test="$diagMonths &lt; $gebMonths"><xsl:value-of select="$dif -1"/></xsl:if>
                <xsl:if test="not ($diagMonths &lt; $gebMonths)"><xsl:value-of select="$dif"/></xsl:if>
            </xsl:element>
<!--            <Tumor_Diagnosedatum><xsl:apply-templates select="number(replace($diagnoseDatum,'\d\d\.\d\d\.(\d\d\d\d)$','$1'))"/></Tumor_Diagnosedatum>-->
            <Tumor_Diagnosedatum><xsl:apply-templates select="$diagnoseDatum"/></Tumor_Diagnosedatum>
            <xsl:apply-templates select="./Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Diagnose[./@Tumor_ID=$Tumor_Id]/Primaertumor_ICD_Code | ./Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Diagnose[./@Tumor_ID=$Tumor_Id]/Primaertumor_ICD_Version"/>
            
            <!--Generate third Level TUMOR entity (Elements:  Lokalisation | ICD-O_Katalog_Topographie_Version |  Seitenlokalisation ) -->
            <Tumor>
                <xsl:attribute name="Tumor_ID" select="$Tumor_Id"/>
                <Lokalisation><xsl:value-of select="./Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Diagnose[./@Tumor_ID=$Tumor_Id]/Primaertumor_Topographie_ICD_O"/></Lokalisation>
                <ICD-O_Katalog_Topographie_Version><xsl:value-of select="./Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Diagnose[./@Tumor_ID=$Tumor_Id]/Primaertumor_Topographie_ICD_O_Version"/></ICD-O_Katalog_Topographie_Version>
                <Seitenlokalisation><xsl:value-of select="./Meldung[./Diagnose/@Tumor_ID=$Tumor_Id][1]/Diagnose[./@Tumor_ID=$Tumor_Id]/Seitenlokalisation"/></Seitenlokalisation>                
                
                <!--Initiate all TUMOR child nodes-->
                <xsl:apply-templates select="./Meldung/Diagnose[./@Tumor_ID=$Tumor_Id]/Menge_Histologie/Histologie | ./Meldung/Diagnose[./@Tumor_ID=$Tumor_Id]/Menge_FM/Fernmetastase | ./Meldung/Diagnose[./@Tumor_ID=$Tumor_Id]/cTNM | ./Meldung/Diagnose[./@Tumor_ID=$Tumor_Id]/pTNM | Meldung[./Tumorzuordnung/@Tumor_ID=$Tumor_Id]/Menge_OP/OP |Meldung[./Tumorzuordnung/@Tumor_ID=$Tumor_Id]/Menge_ST/ST | Meldung[./Tumorzuordnung/@Tumor_ID=$Tumor_Id]/Menge_SYST/SYST |Meldung[./Tumorzuordnung/@Tumor_ID=$Tumor_Id]/Menge_Verlauf/Verlauf"/>
                
                <!--If metastasis doesn't exist: set requried CCP element "nicht erfasst"-->
                <xsl:if test="not(./Meldung/Diagnose[./@Tumor_ID=$Tumor_Id]/Menge_FM/Fernmetastase)">
                    <Metastasis><Fernmetastasen_vorhanden>nicht erfasst</Fernmetastasen_vorhanden></Metastasis>
                </xsl:if>
            </Tumor>
        </Diagnosis>
    </xsl:template>
    
    <!--!!!IGNORE!!!Ignore thise function if you work with IDs in the ADT file-->
    <!--If no IDs are provided, only the Tree Structure allow entity-dependencies: this function rebuilds the full tree structure for missing IDs-->
    <!--Generate second Level DIAGNOSIS entity (Elements: Alter_bei_Erstdiagnose | Tumor_Diagnosedatum | Diagnose | ICD-Katalog_Version )-->
    <xsl:template match="Menge_Meldung" mode="noIds">
        <xsl:choose>
            <xsl:when test="count(./Meldung/Diagnose[not(@Tumor_ID)]) &gt; 1"></xsl:when>
            <xsl:otherwise>
                <!--Some cases allow ambiguous "Diagnosedatum": therefore set unambiguous Variable "diagnoseDatum"-->
                 <xsl:variable name="diagnoseDatum">
                     <xsl:choose>
                         <xsl:when test="./Meldung/Diagnose[not(@Tumor_ID)]/Diagnosedatum"><xsl:value-of select="./Meldung/Diagnose[not(@Tumor_ID)]/Diagnosedatum"/></xsl:when>
                         <xsl:otherwise><xsl:value-of select="./Meldung/Tumorzuordnung[not(@Tumor_ID)]/Diagnosedatum"/></xsl:otherwise>
                     </xsl:choose>
                 </xsl:variable>
                 
                 <Diagnosis>
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
                     <xsl:apply-templates select="./Meldung/Diagnose[not(@Tumor_ID)]/Primaertumor_ICD_Code | ./Meldung/Diagnose[not(@Tumor_ID)]/Primaertumor_ICD_Version"/>
                     
                     <!--Generate third Level TUMOR entity (Elements:  Lokalisation | ICD-O_Katalog_Topographie_Version |  Seitenlokalisation ) -->
                     <Tumor>
                         <Lokalisation><xsl:value-of select="./Meldung/Diagnose[not(@Tumor_ID)]/Primaertumor_Topographie_ICD_O"/></Lokalisation>
                         <ICD-O_Katalog_Topographie_Version><xsl:value-of select="./Meldung/Diagnose[not(@Tumor_ID)]/Primaertumor_Topographie_ICD_O_Version"/></ICD-O_Katalog_Topographie_Version>
                         <Seitenlokalisation><xsl:value-of select="./Meldung/Diagnose[not(@Tumor_ID)]/Seitenlokalisation"/></Seitenlokalisation>                
                         
                         <!--Initiate all TUMOR child nodes-->
                         <xsl:apply-templates select="./Meldung/Diagnose[not(@Tumor_ID)]/Menge_Histologie/Histologie | ./Meldung/Diagnose[not(@Tumor_ID)]/Menge_FM/Fernmetastase | ./Meldung/Diagnose[not(@Tumor_ID)]/cTNM | ./Meldung/Diagnose[not(@Tumor_ID)]/pTNM | Meldung[not(./Tumorzuordnung/@Tumor_ID)]/Menge_OP/OP |Meldung[not(./Tumorzuordnung/@Tumor_ID)]/Menge_ST/ST | Meldung[not(./Tumorzuordnung/@Tumor_ID)]/Menge_SYST/SYST |Meldung[not(./Tumorzuordnung/@Tumor_ID)]/Menge_Verlauf/Verlauf"/>
                         
                         <!--If metastasis doesn't exist: set requried CCP element "nicht erfasst"-->
                         <xsl:if test="not(./Meldung/Diagnose[not(@Tumor_ID)]/Menge_FM/Fernmetastase)">
                             <Metastasis><Fernmetastasen_vorhanden>nicht erfasst</Fernmetastasen_vorhanden></Metastasis>
                         </xsl:if>
                     </Tumor>
                 </Diagnosis>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!--Generate fourth Level HISTOLOGY entity (Elements:  Morphologie | ICD-O_Katalog_Morphologie_Version |  Grading ) -->
    <xsl:template match="Histologie">
        <Histology>
            <xsl:if test="./@Histologie_ID"><xsl:attribute name="Histology_ID"><xsl:value-of select="@Histologie_ID"/></xsl:attribute></xsl:if>
            <xsl:apply-templates select="Morphologie_Code | Morphologie_ICD_O_Version | Grading "></xsl:apply-templates>
            <xsl:if test="Tumor_Histologiedatum"><Tumor_Histologiedatum><xsl:value-of select="Tumor_Histologiedatum"/></Tumor_Histologiedatum></xsl:if>
            <xsl:if test="LK_untersucht"><LK_untersucht><xsl:value-of select="LK_untersucht"/></LK_untersucht></xsl:if>
            <xsl:if test="LK_befallen"><LK_befallen><xsl:value-of select="LK_befallen"/></LK_befallen></xsl:if>
            <xsl:if test="Sentinel_LK_untersucht"><Sentinel_LK_untersucht><xsl:value-of select="Sentinel_LK_untersucht"/></Sentinel_LK_untersucht></xsl:if>
            <xsl:if test="Sentinel_LK_befallen"><Sentinel_LK_befallen><xsl:value-of select="Sentinel_LK_befallen"/></Sentinel_LK_befallen></xsl:if>
        </Histology>
    </xsl:template>
    
    
    <!--Generate fourth Level METASTASIS entity (Elements:  Datum_diagnostische_Sicherung | Lokalisation_Fernmetastasen |  Fernmetastasen_vorhanden ) -->
    <xsl:template match="Fernmetastase">
        <Metastasis>
            <xsl:if test="FM_Diagnosedatum"><xsl:apply-templates select="FM_Diagnosedatum"/></xsl:if>
            <xsl:apply-templates select="FM_Lokalisation"/>
           <xsl:if test="FM_Lokalisation"><Fernmetastasen_vorhanden>ja</Fernmetastasen_vorhanden></xsl:if>
           <xsl:if test="not(FM_Lokalisation)"><Fernmetastasen_vorhanden>nicht erfasst</Fernmetastasen_vorhanden></xsl:if>
       </Metastasis>
   </xsl:template>
    
    
    <!--Generate fourth Level TNM entity (Elements:  TNM-m-Symbol | TNM-T |  TNM-N | TNM-M | TNM-Version | Datum_der_TNM-Dokumentation-Datum_Befund | c-p-u-Präfix_T | c-p-u-Präfix_N | c-p-u-Präfix_M | TNM-r-Symbol | TNM-y-Symbol ) -->
    <xsl:template match="pTNM">
        <TNM>
            <xsl:if test="@TNM_ID"><xsl:attribute name="TNM_ID"><xsl:value-of select="@TNM_ID"/></xsl:attribute></xsl:if>
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
            <xsl:if test="UICC_Stadium"><UICC_Stadium><xsl:value-of select="UICC_Stadium"/></UICC_Stadium></xsl:if>
            <xsl:if test="TNM_L"><TNM-L><xsl:value-of select="TNM_L"/></TNM-L></xsl:if>
            <xsl:if test="TNM_V"><TNM-V><xsl:value-of select="TNM_V"/></TNM-V></xsl:if>
            <xsl:if test="TNM_Pn"><TNM-Pn><xsl:value-of select="TNM_Pn"/></TNM-Pn></xsl:if>
        </TNM>
    </xsl:template>
    
    <xsl:template match="cTNM">
        <TNM>
            <xsl:if test="@TNM_ID"><xsl:attribute name="TNM_ID"><xsl:value-of select="@TNM_ID"/></xsl:attribute></xsl:if>
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
            <xsl:if test="UICC_Stadium"><UICC_Stadium><xsl:value-of select="UICC_Stadium"/></UICC_Stadium></xsl:if>
            <xsl:if test="TNM_L"><TNM-L><xsl:value-of select="TNM_L"/></TNM-L></xsl:if>
            <xsl:if test="TNM_V"><TNM-V><xsl:value-of select="TNM_V"/></TNM-V></xsl:if>
            <xsl:if test="TNM_Pn"><TNM-Pn><xsl:value-of select="TNM_Pn"/></TNM-Pn></xsl:if>
        </TNM>
    </xsl:template>
    
    <xsl:template match="TNM">
        <TNM>
            <xsl:if test="@TNM_ID"><xsl:attribute name="TNM_ID"><xsl:value-of select="@TNM_ID"/></xsl:attribute></xsl:if>
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
            <xsl:if test="UICC_Stadium"><UICC_Stadium><xsl:value-of select="UICC_Stadium"/></UICC_Stadium></xsl:if>
            <xsl:if test="TNM_L"><TNM-L><xsl:value-of select="TNM_L"/></TNM-L></xsl:if>
            <xsl:if test="TNM_V"><TNM-V><xsl:value-of select="TNM_V"/></TNM-V></xsl:if>
            <xsl:if test="TNM_Pn"><TNM-Pn><xsl:value-of select="TNM_Pn"/></TNM-Pn></xsl:if>
        </TNM>
    </xsl:template>

    <!--Generate fourth Level VERLAUF entity (Elements:  Intention_OP | OP |  Intention_ST | Strahlentherapie | Strahlentherapie_Stellung_zu_operativer_Therapie | Intention_SYST | Chemotherapie | Immuntherapie | Hormontherapie | Knochenmarktransplantation | Weitere_Therapien | Sonstige_Therapieart | 
                                                          Systemische_Therapie_Stellung_zu_operativer_Therapie | Lokales-regionäres_Rezidiv | Datum_lokales-regionäres_Rezidiv | Lymphknoten-Rezidiv | Datum_Lymphknoten-Rezidiv | Fernmetastasen | Datum_Fernmetastasen | Ansprechen_im_Verlauf | Untersuchungs-Befunddatum_im_Verlauf ) -->
    <xsl:template match="Verlauf">
        <Verlauf>
            <xsl:if test="@Verlauf_ID"><xsl:attribute name="Verlauf_ID"><xsl:value-of select="@Verlauf_ID"/></xsl:attribute></xsl:if>
            <xsl:apply-templates select="Histologie"/>
            <xsl:apply-templates select="TNM"/>
            <xsl:apply-templates select="Menge_FM/Fernmetastase"/>
            <xsl:if test="Allgemeiner_Leistungszustand"><Allgemeiner_Leistungszustand><xsl:value-of select="Allgemeiner_Leistungszustand"/></Allgemeiner_Leistungszustand></xsl:if>
            <xsl:apply-templates select="Tod"/>
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
            
            <Datum_Verlauf><xsl:apply-templates select="Untersuchungsdatum_Verlauf/node()"/></Datum_Verlauf>
            
        </Verlauf>
    </xsl:template>
    
    <xsl:template match="OP">
        <OP>
            <xsl:if test="@OP_ID"><xsl:attribute name="OP_ID"><xsl:value-of select="@OP_ID"/></xsl:attribute></xsl:if>
            <xsl:apply-templates select="OP_Intention"/>
            <xsl:apply-templates select="OP_Datum"/>
            <xsl:apply-templates select="Menge_OPS/OP_OPS"/>
            <xsl:apply-templates select="OP_OPS_Version"/>
            <xsl:apply-templates select="Histologie"/>
            <xsl:apply-templates select="TNM"/>
            <xsl:apply-templates select="Residualstatus"/>
        </OP>
    </xsl:template>
    
    <xsl:template match="ST">
        <ST>
            <xsl:if test="@ST_ID"><xsl:attribute name="ST_ID"><xsl:value-of select="@ST_ID"/></xsl:attribute></xsl:if>
            <xsl:apply-templates select="ST_Intention"></xsl:apply-templates>
            <xsl:apply-templates select="ST_Stellung_OP"></xsl:apply-templates>
            
            <xsl:apply-templates select="Menge_Bestrahlung"/>
            <xsl:apply-templates select="ST_Ende_Grund"/>
            <xsl:apply-templates select="Residualstatus"/>
            <xsl:apply-templates select="Menge_Nebenwirkung"/>
        </ST>
    </xsl:template>
    
    
    <xsl:template match="SYST">
        <SYST>
            <xsl:if test="@SYST_ID"><xsl:attribute name="SYST_ID"><xsl:value-of select="@SYST_ID"/></xsl:attribute></xsl:if>
            <xsl:apply-templates select="SYST_Intention"></xsl:apply-templates>
            <xsl:apply-templates select="SYST_Stellung_OP"></xsl:apply-templates>
            <xsl:apply-templates select="Menge_Therapieart"/>
            <xsl:apply-templates select="SYST_Ende_Grund"/>
            <xsl:apply-templates select="Residualstatus"/>
            <xsl:apply-templates select="Menge_Nebenwirkung"/>
            <xsl:if test="SYST_Beginn_Datum"><Systemische_Therapie_Beginn><xsl:value-of select="SYST_Beginn_Datum"/></Systemische_Therapie_Beginn></xsl:if>
            <xsl:if test="SYST_Ende_Datum"><Systemische_Therapie_Ende><xsl:value-of select="SYST_Ende_Datum"/></Systemische_Therapie_Ende></xsl:if>
            <xsl:if test="SYST_Protokoll"><Systemische_Therapie_Protokoll><xsl:value-of select="SYST_Protokoll"/></Systemische_Therapie_Protokoll></xsl:if>
            <xsl:apply-templates select="Menge_Substanz"/>
        </SYST>
    </xsl:template>
    
    <!-- Sub functions -->
    
    <xsl:template match="Menge_Nebenwirkung">
            <xsl:apply-templates select="ST_Nebenwirkung"/>
            <xsl:apply-templates select="SYST_Nebenwirkung"/>
    </xsl:template>
    
    <xsl:template match="ST_Nebenwirkung">
        <ST_Nebenwirkung>
            <xsl:if test="Nebenwirkung_Grad"><Nebenwirkung_Grad><xsl:value-of select="Nebenwirkung_Grad"/></Nebenwirkung_Grad></xsl:if>
            <xsl:if test="Nebenwirkung_Art"><Nebenwirkung_Art><xsl:value-of select="Nebenwirkung_Art"/></Nebenwirkung_Art></xsl:if>
            <xsl:if test="Nebenwirkung_Version"><Nebenwirkung_Version><xsl:value-of select="Nebenwirkung_Version"/></Nebenwirkung_Version></xsl:if>
        </ST_Nebenwirkung>
    </xsl:template>
    
    <xsl:template match="SYST_Nebenwirkung">
        <SYST_Nebenwirkung>
            <xsl:if test="Nebenwirkung_Grad"><Nebenwirkung_Grad><xsl:value-of select="Nebenwirkung_Grad"/></Nebenwirkung_Grad></xsl:if>
            <xsl:if test="Nebenwirkung_Art"><Nebenwirkung_Art><xsl:value-of select="Nebenwirkung_Art"/></Nebenwirkung_Art></xsl:if>
            <xsl:if test="Nebenwirkung_Version"><Nebenwirkung_Version><xsl:value-of select="Nebenwirkung_Version"/></Nebenwirkung_Version></xsl:if>
        </SYST_Nebenwirkung>
    </xsl:template>
    
    <xsl:template match="Menge_Therapieart">
            <xsl:apply-templates select="SYST_Therapieart"/>
    </xsl:template>
    
    <xsl:template match="Tod">
        <Tod>
            <xsl:apply-templates select="Sterbedatum | Tod_tumorbedingt | Menge_Todesursache"></xsl:apply-templates>
        </Tod>
    </xsl:template>
    
    <xsl:template match="Menge_Todesursache">
            <xsl:apply-templates select="Todesursache_ICD | Todesursache_ICD_Version"></xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="Residualstatus">
        <xsl:if test="Lokale_Beurteilung_Residualstatus | Gesamtbeurteilung_Residualstatus">
           <xsl:if test="Lokale_Beurteilung_Residualstatus"><Lokale_Beurteilung_Resttumor><xsl:value-of select="Lokale_Beurteilung_Residualstatus"/></Lokale_Beurteilung_Resttumor></xsl:if>
           <xsl:if test="Gesamtbeurteilung_Residualstatus"><Gesamtbeurteilung_Resttumor><xsl:value-of select="Gesamtbeurteilung_Residualstatus"/></Gesamtbeurteilung_Resttumor></xsl:if>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="Menge_Bestrahlung">
            <xsl:apply-templates select="Bestrahlung"></xsl:apply-templates>
    </xsl:template>
    
    <xsl:template match="Bestrahlung">
        <Bestrahlung>
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
    <xsl:template match="SYST_Therapieart">
        <SYST_Therapieart>
            <xsl:apply-templates select="node() | @*"/>
        </SYST_Therapieart>
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
        <Todesursache_ICD>
            <xsl:apply-templates select="node() | @*"/>
        </Todesursache_ICD>
    </xsl:template>
    <xsl:template match="Todesursache_ICD_Version">
        <Todesursache_ICD_Version>
            <xsl:apply-templates select="node() | @*"/>
        </Todesursache_ICD_Version>
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
    
  
</xsl:stylesheet>
