<?xml version="1.0" encoding="utf-8" standalone="no"?>
<xsl:stylesheet xmlns="http://www.mds.de/namespace"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.mds.de/namespace MDS_Suchmodell_v4.xsd"
    xmlns:hash="java:de.samply.obds2fhir"
    exclude-result-prefixes="#default"
    version="2.0"
    xpath-default-namespace="http://www.basisdatensatz.de/oBDS/XML">

    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    <xsl:output omit-xml-declaration="no" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:param name="add_department" />
    <xsl:param name="keep_internal_id" />

    <xsl:template match="/oBDS/Menge_Patient">
        <Patienten>
            <xsl:apply-templates select="node()| @*"/>
        </Patienten>
    </xsl:template>
    <xsl:template match="Patient">
        <Patient>
            <xsl:variable name="Patient_Id" select="if ($keep_internal_id=true()) then @Patient_ID else hash:hash(@Patient_ID,'','')"/>
            <xsl:variable name="Geburtsdatum" select="Patienten_Stammdaten/Geburtsdatum"/>
            <xsl:variable name="Geburtstag" select="string(replace($Geburtsdatum,'\d\d\d\d\-\d\d\-(\d\d)$','$1'))"/>
            <xsl:variable name="Geburtsmonat" select="string(replace($Geburtsdatum,'\d\d\d\d\-(\d\d)\-\d\d$','$1'))"/>
            <xsl:variable name="Geburtsjahr" select="string(replace($Geburtsdatum,'(\d\d\d\d)\-\d\d\-\d\d$','$1'))"/>
            <xsl:variable name="Patient_Pseudonym" select="hash:pseudonymize(
            xsi:ReplaceEmpty(Patienten_Stammdaten/Geschlecht),
            xsi:ReplaceEmpty(Patienten_Stammdaten/Vornamen),
            xsi:ReplaceEmpty(Patienten_Stammdaten/Nachname),
            xsi:ReplaceEmpty(Patienten_Stammdaten/Geburtsname),
            xsi:ReplaceEmpty($Geburtstag),
            xsi:ReplaceEmpty($Geburtsmonat),
            xsi:ReplaceEmpty($Geburtsjahr),
            xsi:ReplaceEmpty(@Patient_ID))"/>
            <xsl:attribute name="Patient_ID" select="$Patient_Id"/>
            <xsl:apply-templates select="Patienten_Stammdaten/Geschlecht | Patienten_Stammdaten/Geburtsdatum"/>
            <!--<DKTK_ID>TODO</DKTK_ID>-->
            <DKTK_LOCAL_ID><xsl:value-of select="$Patient_Pseudonym"/></DKTK_LOCAL_ID>
            <Vitalstatus_Gesamt Vitalstatus_ID="{concat('vital', $Patient_Id)}">
                <Datum_des_letztbekannten_Vitalstatus>
                    <xsl:value-of select="if (Patienten_Stammdaten/Vitalstatus_Datum != '') then 'Patienten_Stammdaten/Vitalstatus_Datum' else xsi:Datum_des_letztbekannten_Vitalstatus(Menge_Meldung)"/>
                </Datum_des_letztbekannten_Vitalstatus>
                <xsl:choose>
                    <xsl:when test="lower-case(Patienten_Stammdaten/Vitalstatus)='verstorben'"><Vitalstatus>verstorben</Vitalstatus></xsl:when>
                    <xsl:when test="lower-case(Patienten_Stammdaten/Vitalstatus)='lebend'"><Vitalstatus >lebend</Vitalstatus></xsl:when>
                    <xsl:when test="Menge_Meldung/Meldung/Tod"><Vitalstatus>verstorben</Vitalstatus></xsl:when>
                    <xsl:when test="not(Menge_Meldung/Meldung/Tod)"><Vitalstatus>lebend</Vitalstatus></xsl:when>
                </xsl:choose>
                <xsl:apply-templates select="Menge_Meldung/Meldung/Tod"/>
            </Vitalstatus_Gesamt>
            <xsl:if test="$add_department=true()">
                <Organisationen>
                    <Organisation><xsl:value-of select="/oBDS/Menge_Melder/Melder[1]/Kontoinhaber"/></Organisation>
                    <xsl:for-each select="/oBDS/Menge_Melder/Melder[./@ID=/oBDS/Menge_Patient/Patient/Menge_Meldung/Meldung/@Melder_ID]/KH_Abt_Station_Praxis">
                        <Abteilung>
                            <xsl:value-of select="."/>
                        </Abteilung>
                    </xsl:for-each>
                </Organisationen>
            </xsl:if>
        <!--pass children entities SAMPLE and DIAGNOSIS for further processing; TODO redo for oBDS
            <xsl:if test="./Menge_Meldung/Meldung/Menge_Biomaterial/Biomaterial">
                <xsl:apply-templates select="Menge_Meldung/Meldung/Menge_Biomaterial/Biomaterial[not(@Biomaterial_ID=following::*/@Biomaterial_ID[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id])]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                </xsl:apply-templates>
            </xsl:if>-->
            <xsl:for-each select="Menge_Meldung/Meldung[not(Tumorzuordnung/@Tumor_ID=preceding-sibling::*/Tumorzuordnung/@Tumor_ID)]">
                <xsl:apply-templates select="../../Menge_Meldung"><!--apply sequential tumor related reports -->
                    <xsl:with-param name="Patient_Id" select="../../@Patient_ID"/>
                    <xsl:with-param name="Tumor_Id" select="Tumorzuordnung/@Tumor_ID"/>
                </xsl:apply-templates>
            </xsl:for-each>
        </Patient>
    </xsl:template>

    <xsl:template match="Menge_Meldung">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="Tumor_Meldungen" select="Meldung[Tumorzuordnung/@Tumor_ID=$Tumor_Id]"/>
        <xsl:variable name="diagnoseDatum" select="$Tumor_Meldungen[1]/Tumorzuordnung/Diagnosedatum"/>
        <Diagnosis>
            <xsl:variable name="Diagnosis_Id" select="concat('dig', hash:hash($Patient_Id, $Tumor_Id, ''))"/>
            <xsl:attribute name="Diagnosis_ID" select="$Diagnosis_Id"/>
            <xsl:if test="$Tumor_Meldungen/Diagnose"><!-- don't create those elements if no Diagnose is delivered -->
                <Alter_bei_Erstdiagnose><xsl:value-of select="xsi:date_diff(/oBDS/Menge_Patient/Patient/Patienten_Stammdaten/Geburtsdatum, $diagnoseDatum)"/></Alter_bei_Erstdiagnose>
                <xsl:apply-templates select="
                    $diagnoseDatum |
                    $Tumor_Meldungen[1]/Tumorzuordnung/Primaertumor_ICD |
                    ($Tumor_Meldungen/(Diagnose|Pathologie)/Primaertumor_Diagnosetext)[last()] |
                    ($Tumor_Meldungen/(Diagnose|Pathologie)/Primaertumor_Topographie_Freitext)[last()] |
                    ($Tumor_Meldungen/(Diagnose|Pathologie)/Diagnosesicherung)[last()]"/>
                <xsl:apply-templates select="
                    $Tumor_Meldungen/Diagnose/Allgemeiner_Leistungszustand |
                    $Tumor_Meldungen/(Diagnose|Pathologie)/Menge_Weitere_Klassifikation">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    <xsl:with-param name="Origin" select="$diagnoseDatum"/>
                </xsl:apply-templates>
            </xsl:if>
            <Tumor>
                <xsl:attribute name="Tumor_ID" select="$Diagnosis_Id"/>
                <xsl:if test="$Tumor_Meldungen/Diagnose"><!-- don't create those elements if no Diagnose is delivered -->
                    <xsl:apply-templates select="($Tumor_Meldungen/(Diagnose|Pathologie)/Primaertumor_Topographie_ICD_O)[last()] | $Tumor_Meldungen[1]/Tumorzuordnung/Seitenlokalisation"/>
                </xsl:if>
                <!--Initiate all TUMOR child nodes-->
                <xsl:apply-templates select="$Tumor_Meldungen/Diagnose | $Tumor_Meldungen/Pathologie">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
                <xsl:for-each select="$Tumor_Meldungen/OP">
                    <xsl:choose>
                        <xsl:when test="@OP_ID">
                            <xsl:apply-templates select=".[not(@OP_ID=following::OP/@OP_ID)]">
                                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                            </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:apply-templates select=".[not(OP_Datum=following::OP/OP_Datum)]">
                                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                            </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldungen/ST">
                    <xsl:choose>
                        <xsl:when test="@ST_ID"><xsl:apply-templates select=".[not(@ST_ID=following::ST/@ST_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(Menge_Bestrahlung/Bestrahlung/Beginn_=following::ST/Menge_Bestrahlung/Bestrahlung/Beginn)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldungen/SYST">
                    <xsl:choose>
                        <xsl:when test="@SYST_ID"><xsl:apply-templates select=".[not(@SYST_ID=following::SYST/@SYST_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(SYST_Beginn_Datum=following::SYST/SYST_Beginn_Datum)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldungen/Verlauf">
                    <xsl:choose>
                        <xsl:when test="@Verlauf_ID"><xsl:apply-templates select=".[not(@Verlauf_ID=following::Verlauf/@Verlauf_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(Untersuchungsdatum_Verlauf=following::Verlauf/Untersuchungsdatum_Verlauf)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldungen/Tumorkonferenz">
                    <xsl:choose>
                        <xsl:when test="@Tumorkonferenz_ID"><xsl:apply-templates select=".[not(@Tumorkonferenz_ID=following::Tumorkonferenz/@Tumorkonferenz_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(Datum=following::Tumorkonferenz/Datum)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </Tumor>
        </Diagnosis>
    </xsl:template>

    <xsl:template match="Diagnose | Pathologie">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:for-each select="cTNM|pTNM">
            <xsl:choose>
                <xsl:when test="@ID">
                    <xsl:apply-templates select=".[
                        not(@ID=following::TNM/@ID) and
                        not(@ID=following::cTNM/@ID) and
                        not(@ID=following::pTNM/@ID)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select=".[
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::TNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::pTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::cTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="Histologie">
            <xsl:choose>
                <xsl:when test="@Histologie_ID"><xsl:apply-templates select=".[not(@Histologie_ID=following::Histologie/@Histologie_ID)]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select=".[not(Tumor_Histologiedatum=following::Histologie/Tumor_Histologiedatum)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="Menge_FM/Fernmetastase">
            <xsl:apply-templates select=".[not(concat(Diagnosedatum,Lokalisation)=following::Fernmetastase/concat(Diagnosedatum,Lokalisation))]">
                <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Fernmetastase[concat(Diagnosedatum,Lokalisation)=current()/concat(Diagnosedatum,Lokalisation)])" /></xsl:with-param>
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            </xsl:apply-templates>
        </xsl:for-each>
        <xsl:for-each select="Menge_Genetik/Genetische_Variante">
            <xsl:apply-templates select=".[not(concat(Datum,Bezeichnung,Sonstige_Auspraegung)=following::Genetische_Variante/concat(Datum,Bezeichnung,Sonstige_Auspraegung))]">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="Histologie">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="Tumor_Histologiedatum !=''">
             <Histology>
                 <xsl:variable name="Histology_ID">
                     <xsl:choose>
                         <xsl:when test="@Histologie_ID"><xsl:value-of select="hash:hash($Patient_Id, $Tumor_Id, @Histologie_ID)"/></xsl:when>
                         <xsl:otherwise>
                             <xsl:value-of select="hash:hash($Patient_Id, $Tumor_Id, concat('gen', Tumor_Histologiedatum, string-join(Morphologie_ICD_O/Code, ''), Grading))"/>
                         </xsl:otherwise>
                     </xsl:choose>
                 </xsl:variable>
                 <xsl:attribute name="Histology_ID" select="concat('hist', $Histology_ID)"/>
                 <xsl:if test="Morphologie_ICD_O">
                     <xsl:for-each select="Morphologie_ICD_O">
                         <Morphologie_ICD_O>
                             <xsl:if test="Code">
                                 <Morphologie_Code>
                                     <xsl:value-of select="Code"/>
                                 </Morphologie_Code>
                             </xsl:if>
                             <xsl:if test="Version">
                                 <ICD-O_Katalog_Morphologie_Version>
                                     <xsl:value-of select="Version"/>
                                 </ICD-O_Katalog_Morphologie_Version>
                             </xsl:if>
                         </Morphologie_ICD_O>
                     </xsl:for-each>
                 </xsl:if>
                 <xsl:apply-templates select="Tumor_Histologiedatum | Morphologie_Freitext"/>
                 <xsl:if test="Grading"><Grading Grading_ID="{concat('grd', $Histology_ID)}"><xsl:value-of select="Grading"/></Grading></xsl:if>
                 <xsl:if test="LK_untersucht"><LK_untersucht LK_untersucht_ID="{concat('lku', $Histology_ID)}"><xsl:value-of select="LK_untersucht"/></LK_untersucht></xsl:if>
                 <xsl:if test="LK_befallen"><LK_befallen LK_befallen_ID="{concat('lkb', $Histology_ID)}"><xsl:value-of select="LK_befallen"/></LK_befallen></xsl:if>
                 <xsl:if test="Sentinel_LK_untersucht"><Sentinel_LK_untersucht Sentinel_LK_untersucht_ID="{concat('slku', $Histology_ID)}"><xsl:value-of select="Sentinel_LK_untersucht"/></Sentinel_LK_untersucht></xsl:if>
                 <xsl:if test="Sentinel_LK_befallen"><Sentinel_LK_befallen Sentinel_LK_befallen_ID="{concat('slkb', $Histology_ID)}"><xsl:value-of select="Sentinel_LK_befallen"/></Sentinel_LK_befallen></xsl:if>
             </Histology>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Fernmetastase">
        <xsl:param name="counter"/>
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="Lokalisation!='' and Diagnosedatum!=''">
           <Metastasis>
               <xsl:attribute name="Metastasis_ID">
                   <xsl:variable name="attribute" select="'gen',concat(Diagnosedatum,Lokalisation,$counter)"/>
                   <xsl:value-of select="concat('fm', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))" />
               </xsl:attribute>
               <Datum_diagnostische_Sicherung><xsl:value-of select="Diagnosedatum"/></Datum_diagnostische_Sicherung>
               <Lokalisation_Fernmetastasen><xsl:value-of select="Lokalisation"/></Lokalisation_Fernmetastasen>
               <Fernmetastasen_vorhanden>ja</Fernmetastasen_vorhanden>
          </Metastasis>
        </xsl:if>
    </xsl:template>

    <xsl:template match="cTNM | pTNM | TNM">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="Datum !=''">
            <xsl:variable name="attribute">
                <xsl:choose>
                    <xsl:when test="@ID"><xsl:value-of select="@ID"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="'gen',concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M,name(.))"/></xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <TNM>
                <xsl:attribute name="TNM_ID" select="concat('tnm', hash:hash($Patient_Id, $Tumor_Id, $attribute))" />
                <gesamtpraefix><xsl:value-of select="name(.)"/></gesamtpraefix>
                <xsl:apply-templates select="node()"/>
                <xsl:if test="not(UICC_Stadium!='')">
                    <xsl:for-each select="../Menge_Weitere_Klassifikation/Weitere_Klassifikation">
                        <xsl:if test="contains(lower-case(normalize-space(Name)), 'uicc')">
                            <UICC_Stadium><xsl:value-of select="Stadium"/></UICC_Stadium>
                        </xsl:if>
                    </xsl:for-each>
                </xsl:if>
            </TNM>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Genetische_Variante">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="Bezeichnung !=''">
            <Genetische_Variante>
                <xsl:attribute name="Gen_ID" select="concat('gen', hash:hash($Patient_Id, $Tumor_Id, concat(Datum, Bezeichnung, Auspraegung)))" />
                <xsl:if test="Datum"><Datum><xsl:value-of select="Datum"/></Datum></xsl:if>
                <xsl:if test="Bezeichnung"><Bezeichnung><xsl:value-of select="Bezeichnung"/></Bezeichnung></xsl:if>
                <xsl:if test="Auspraegung"><Auspraegung><xsl:value-of select="Auspraegung"/></Auspraegung></xsl:if>
            </Genetische_Variante>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Verlauf">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="attribute">
            <xsl:choose>
                <xsl:when test="@Verlauf_ID"><xsl:value-of select="@Verlauf_ID"/></xsl:when>
                <xsl:when test="Untersuchungsdatum_Verlauf"><xsl:value-of select="'gen',Untersuchungsdatum_Verlauf"/></xsl:when>
                <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <Verlauf>
            <xsl:variable name="Verlauf_ID" select="concat('vrl', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))" />
            <xsl:attribute name="Verlauf_ID" select="$Verlauf_ID" />
            <xsl:apply-templates select="Meldeanlass | Untersuchungsdatum_Verlauf | Gesamtbeurteilung_Tumorstatus | Verlauf_Lokaler_Tumorstatus | Verlauf_Tumorstatus_Lymphknoten | Verlauf_Tumorstatus_Fernmetastasen"/>
            <xsl:apply-templates select="Allgemeiner_Leistungszustand | Menge_Weitere_Klassifikation">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                <xsl:with-param name="Origin" select="concat(Untersuchungsdatum_Verlauf, $Verlauf_ID)"/>
            </xsl:apply-templates>
            <xsl:choose>
                <xsl:when test="TNM/@ID">
                    <xsl:apply-templates select="TNM[not(@ID=following::TNM/@ID)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="TNM[not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::TNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))]">
                         <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                         <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                     </xsl:apply-templates>
                 </xsl:otherwise>
            </xsl:choose>
            <xsl:choose>
                <xsl:when test="Histologie/@Histologie_ID">
                    <xsl:apply-templates select="Histologie[not(@Histologie_ID=following::Histologie/@Histologie_ID)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="Histologie[not(Tumor_Histologiedatum=following::Histologie/Tumor_Histologiedatum)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:for-each select="Menge_FM/Fernmetastase">
                <xsl:apply-templates select=".[not(concat(Diagnosedatum,Lokalisation)=following::Fernmetastase/concat(Diagnosedatum,Lokalisation))]">
                    <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Fernmetastase[concat(Diagnosedatum,Lokalisation)=current()/concat(Diagnosedatum,Lokalisation)])" /></xsl:with-param>
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
            </xsl:for-each>
            <xsl:for-each select="Menge_Genetik/Genetische_Variante">
                <xsl:apply-templates select=".[not(concat(Datum,Bezeichnung,Sonstige_Auspraegung)=following::Genetische_Variante/concat(Datum,Bezeichnung,Sonstige_Auspraegung))]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
            </xsl:for-each>
        </Verlauf>
    </xsl:template>

    <xsl:template match="Tumorkonferenz">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="attribute">
            <xsl:choose>
                <xsl:when test="@Tumorkonferenz_ID"><xsl:value-of select="@Tumorkonferenz_ID"/></xsl:when>
                <xsl:when test="Datum"><xsl:value-of select="'gen',Datum"/></xsl:when>
                <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <Therapieempfehlung>
            <xsl:attribute name="Tumorkonferenz_ID" select="concat('tkz', hash:hash($Patient_Id, $Tumor_Id, $attribute))" />
            <xsl:apply-templates select="Meldeanlass | Datum | Typ | Therapieempfehlung"/>
        </Therapieempfehlung>
    </xsl:template>

    <xsl:template match="OP">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="attribute">
            <xsl:choose>
                <xsl:when test="@OP_ID"><xsl:value-of select="@OP_ID"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="'gen',OP_Datum"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <OP>
            <xsl:attribute name="OP_ID" select="concat('op', hash:hash($Patient_Id, $Tumor_Id, $attribute))"/>
            <xsl:if test="Intention"><Intention_OP><xsl:value-of select="Intention"/></Intention_OP></xsl:if>
            <xsl:if test="Datum"><Datum><xsl:value-of select="Datum"/></Datum></xsl:if>
            <xsl:for-each select="Menge_OPS/OPS">
                <OPS>
                    <xsl:if test="Code"><Code><xsl:value-of select="Code"/></Code></xsl:if>
                    <xsl:if test="Version"><Version><xsl:value-of select="Version"/></Version></xsl:if>
                </OPS>
            </xsl:for-each>
            <xsl:if test="Komplikationen !=''">
                <Komplikationen>
                    <xsl:for-each select="Komplikationen/Komplikation_nein_oder_unbekannt[. != '']">
                        <Komplikation>
                            <xsl:value-of select="."/>
                        </Komplikation>
                    </xsl:for-each>
                    <xsl:for-each select="Komplikationen/Menge_Komplikation/Komplikation/Kuerzel[. != '']">
                        <Komplikation>
                            <xsl:value-of select="."/>
                        </Komplikation>
                    </xsl:for-each>
                    <xsl:for-each select="Komplikationen/Menge_Komplikation/Komplikation/ICD/Code[. != '']">
                        <ICD>
                            <Code>
                                <xsl:value-of select="."/>
                            </Code>
                            <xsl:if test="../Version !=''">
                                <Version>
                                    <xsl:value-of select="../Version"/>
                                </Version>
                            </xsl:if>
                        </ICD>
                    </xsl:for-each>
                </Komplikationen>
            </xsl:if>
            <xsl:apply-templates select="Residualstatus[not(concat(Lokale_Beurteilung_Residualstatus,Gesamtbeurteilung_Residualstatus)=following-sibling::*/concat(Lokale_Beurteilung_Residualstatus,Gesamtbeurteilung_Residualstatus))]"/>
            <xsl:apply-templates select="Menge_Weitere_Klassifikation">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            </xsl:apply-templates>
            <xsl:choose>
                <xsl:when test="Histologie/@Histologie_ID">
                    <xsl:apply-templates select="Histologie[not(@Histologie_ID=following::Histologie/@Histologie_ID)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="Histologie[not(Tumor_Histologiedatum=following::Histologie/Tumor_Histologiedatum)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:choose>
                <xsl:when test="TNM/@ID"><xsl:apply-templates select="TNM[
                    not(@ID=following::TNM/@ID) and
                    not(@ID=following::cTNM/@ID) and
                    not(@ID=following::pTNM/@ID)]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates></xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="TNM[
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::TNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::pTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::cTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:for-each select="Menge_Genetik/Genetische_Variante">
                <xsl:apply-templates select=".[not(concat(Datum,Bezeichnung,Sonstige_Auspraegung)=following::Genetische_Variante/concat(Datum,Bezeichnung,Sonstige_Auspraegung))]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
            </xsl:for-each>
        </OP>
    </xsl:template>

    <xsl:template match="ST">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <ST>
            <xsl:variable name="attribute">
                <xsl:choose>
                    <xsl:when test="@ST_ID"><xsl:value-of select="@ST_ID"/></xsl:when>
                    <xsl:when test="Menge_Bestrahlung[1]/Bestrahlung[1]/Beginn"><xsl:value-of select="'gen',Menge_Bestrahlung[1]/Bestrahlung[1]/Beginn"/></xsl:when>
                </xsl:choose>
            </xsl:variable>
            <xsl:attribute name="ST_ID" select="concat('st', concat($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
            <xsl:apply-templates select="Meldeanlass | Intention | Stellung_OP"/>
            <xsl:if test="Ende_Grund!=''"><Ende_Grund><xsl:value-of select="Ende_Grund"/></Ende_Grund></xsl:if>
            <xsl:apply-templates select="Nebenwirkungen">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                <xsl:with-param name="Therapy_Id" select="string-join($attribute, '')"/>
            </xsl:apply-templates>
            <xsl:apply-templates select="Menge_Bestrahlung">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            </xsl:apply-templates>
        </ST>
    </xsl:template>

    <xsl:template match="SYST">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="Beginn">
           <SYST>
               <xsl:variable name="attribute">
                   <xsl:choose>
                       <xsl:when test="@SYST_ID"><xsl:value-of select="@SYST_ID"/></xsl:when>
                       <xsl:otherwise><xsl:value-of select="'gen',Beginn"/></xsl:otherwise>
                   </xsl:choose>
               </xsl:variable>
               <xsl:attribute name="SYST_ID" select="concat('syst', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
               <xsl:apply-templates select="Meldeanlass | Intention | Stellung_OP | Therapieart"/>
               <xsl:if test="Protokoll"><Systemische_Therapie_Protokoll><xsl:value-of select="Protokoll"/></Systemische_Therapie_Protokoll></xsl:if>
               <xsl:if test="Beginn"><Systemische_Therapie_Beginn><xsl:value-of select="Beginn"/></Systemische_Therapie_Beginn></xsl:if>
               <xsl:apply-templates select="Menge_Substanz"/>
               <xsl:if test="Ende_Grund"><SYST_Ende_Grund><xsl:value-of select="Ende_Grund"/></SYST_Ende_Grund></xsl:if>
               <xsl:if test="Ende"><Systemische_Therapie_Ende><xsl:value-of select="Ende"/></Systemische_Therapie_Ende></xsl:if>
               <xsl:apply-templates select="Nebenwirkungen">
                   <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                   <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                   <xsl:with-param name="Therapy_Id" select="string-join($attribute, '')"/>
               </xsl:apply-templates>
           </SYST>
        </xsl:if>
    </xsl:template>

    <!-- Sub functions -->
    <xsl:template match="Nebenwirkungen">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Therapy_Id"/>
        <xsl:for-each select="Menge_Nebenwirkung/Nebenwirkung[Grad!='']">
            <Nebenwirkung>
                <xsl:attribute name="Nebenwirkung_ID" select="hash:hash($Patient_Id, $Tumor_Id, concat($Therapy_Id, Art/node(), Grad, Version))"/>
                <Grad><xsl:value-of select="Grad"/></Grad>
                <xsl:if test="Version"><Version><xsl:value-of select="Version"/></Version></xsl:if>
                <xsl:if test="Art/node()">
                    <Art><xsl:value-of select="Art/node()"/></Art>
                    <xsl:choose>
                        <xsl:when test="Art/MedDRA_Code!=''">
                            <Typ>MedDRA_Code</Typ>
                        </xsl:when>
                        <xsl:when test="Art/Bezeichnung!=''">
                            <Typ><xsl:value-of select="Art/Bezeichnung"/></Typ>
                        </xsl:when>
                        <xsl:otherwise>
                            <Typ>missing_system</Typ>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:if>
            </Nebenwirkung>
        </xsl:for-each>
        <xsl:for-each select="Grad_maximal2_oder_unbekannt">
            <Nebenwirkung>
                <xsl:attribute name="Nebenwirkung_ID" select="hash:hash($Patient_Id, $Tumor_Id, concat($Therapy_Id, .))"/>
                <Grad><xsl:value-of select="."/></Grad>
                <!--<Version>Art der Nebenwirkung nach CTC + Schweregrad (K|1|2|U)</Version>-->
                <Art>CTC</Art>
                <Typ>CTC</Typ>
            </Nebenwirkung>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="Tod">
        <xsl:if test="Sterbedatum !=''">
            <Tod>
                <xsl:apply-templates select="Sterbedatum | Tod_tumorbedingt | Menge_Todesursachen"></xsl:apply-templates>
            </Tod>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Menge_Todesursachen">
        <Menge_Todesursachen>
            <xsl:apply-templates select="Todesursache_ICD"/>
        </Menge_Todesursachen>
    </xsl:template>

    <xsl:template match="Residualstatus">
        <xsl:if test="Lokale_Beurteilung_Residualstatus | Gesamtbeurteilung_Residualstatus">
           <xsl:if test="Lokale_Beurteilung_Residualstatus"><Lokale_Beurteilung_Resttumor><xsl:value-of select="Lokale_Beurteilung_Residualstatus"/></Lokale_Beurteilung_Resttumor></xsl:if>
           <xsl:if test="Gesamtbeurteilung_Residualstatus"><Gesamtbeurteilung_Resttumor><xsl:value-of select="Gesamtbeurteilung_Residualstatus"/></Gesamtbeurteilung_Resttumor></xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Menge_Bestrahlung">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:for-each select="Bestrahlung[not(concat(Beginn,Ende,Applikationsart)=following::Bestrahlung/concat(Beginn,Ende,Applikationsart))]">
                <Bestrahlung>
                    <xsl:attribute name="Betrahlung_ID" select="concat('sts', hash:hash($Patient_Id, $Tumor_Id, concat(Beginn,Ende,Applikationsart)))"/>
                    <xsl:if test="Beginn!=''"><Beginn_Datum><xsl:value-of select="Beginn"/></Beginn_Datum></xsl:if>
                    <xsl:if test="Ende!=''"><Ende_Datum><xsl:value-of select="Ende"/></Ende_Datum></xsl:if>
                    <xsl:apply-templates select="Applikationsart/Perkutan | Applikationsart/Kontakt | Applikationsart/Metabolisch | Applikationsart/Sonstige"/>
                </Bestrahlung>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="Perkutan">
        <Applikationsart>P</Applikationsart>
        <xsl:if test="Radiochemo='RCJ'"><ApplikationsartTyp>RCJ</ApplikationsartTyp></xsl:if>
        <xsl:if test="Radiochemo='RCN'"><ApplikationsartTyp>RCN</ApplikationsartTyp></xsl:if>
        <xsl:if test="Stereotaktisch='ST'"><ApplikationsartTyp>ST</ApplikationsartTyp></xsl:if>
        <xsl:if test="Atemgetriggert='4D'"><ApplikationsartTyp>4D</ApplikationsartTyp></xsl:if>
        <ApplikationsartLegacy><xsl:value-of select="concat('P', Radiochemo, Stereotaktisch, Atemgetriggert)"/></ApplikationsartLegacy>
        <xsl:apply-templates select="Zielgebiet | Seite_Zielgebiet | Strahlenart | Gesamtdosis | Einzeldosis | Boost"/>
    </xsl:template>
    <xsl:template match="Kontakt">
        <Applikationsart><xsl:value-of select="Interstitiell_endokavitaer"/></Applikationsart><!--this value is either K or I - identical to ADT 2-->
        <ApplikationsartTyp><xsl:value-of select="Rate_Type"/></ApplikationsartTyp><!--this value is either HDR, LDR or PDR - identical to ADT 2-->
        <ApplikationsartLegacy><xsl:value-of select="concat(Interstitiell_endokavitaer, Rate_Type)"/></ApplikationsartLegacy>
        <xsl:apply-templates select="Zielgebiet | Seite_Zielgebiet | Strahlenart | Gesamtdosis | Einzeldosis | Boost"/>
    </xsl:template>
    <xsl:template match="Metabolisch">
        <Applikationsart>M</Applikationsart>
        <ApplikationsartTyp><xsl:value-of select="Metabolisch_Typ"/></ApplikationsartTyp><!--this value is either SIRT or PRRT - identical to ADT 2; additional PSMA, RJT or RIT-->
        <ApplikationsartLegacy><xsl:value-of select="concat('M', Metabolisch_Typ)"/></ApplikationsartLegacy>
        <xsl:apply-templates select="Zielgebiet | Seite_Zielgebiet | Strahlenart | Gesamtdosis | Einzeldosis"/>
    </xsl:template>
    <xsl:template match="Sonstige">
        <Applikationsart>S</Applikationsart>
        <ApplikationsartLegacy>S</ApplikationsartLegacy>
        <xsl:apply-templates select="Zielgebiet | Seite_Zielgebiet | Gesamtdosis | Einzeldosis"/>
    </xsl:template>
    <xsl:template match="Gesamtdosis">
        <Gesamtdosis>
            <xsl:if test="Dosis"><Dosis><xsl:value-of select="Dosis"/></Dosis></xsl:if>
            <xsl:if test="Einheit"><Einheit><xsl:value-of select="Einheit"/></Einheit></xsl:if>
        </Gesamtdosis>
    </xsl:template>
    <xsl:template match="Einzeldosis">
        <Einzeldosis>
            <xsl:if test="Dosis"><Dosis><xsl:value-of select="Dosis"/></Dosis></xsl:if>
            <xsl:if test="Einheit"><Einheit><xsl:value-of select="Einheit"/></Einheit></xsl:if>
        </Einzeldosis>
    </xsl:template>

    <xsl:template match="Menge_Weitere_Klassifikation">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:for-each select="Weitere_Klassifikation">
            <xsl:if test=".[not(concat(Datum, Name, Stadium)=following::Weitere_Klassifikation/concat(Datum, Name, Stadium))]">
                <Weitere_Klassifikation>
                    <xsl:attribute name="WeitereKlassifikation_ID" select="hash:hash($Patient_Id, $Tumor_Id, concat(Datum, Name, Stadium))"/>
                    <xsl:if test="Datum"><Datum><xsl:value-of select="Datum"/></Datum></xsl:if>
                    <xsl:if test="Name"><Name><xsl:value-of select="Name"/></Name></xsl:if>
                    <xsl:if test="Stadium"><Stadium><xsl:value-of select="Stadium"/></Stadium></xsl:if>
                </Weitere_Klassifikation>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="Menge_Substanz">
        <xsl:for-each select="Substanz">
            <xsl:if test="Bezeichnung"><SYST_Substanz><xsl:value-of select="Bezeichnung"/></SYST_Substanz></xsl:if>
            <xsl:if test="ATC">
                <SYST_Substanz-ATC>
                    <xsl:if test="ATC/Code"><Code><xsl:value-of select="ATC/Code"/></Code></xsl:if>
                    <xsl:if test="ATC/Version"><Version><xsl:value-of select="ATC/Version"/></Version></xsl:if>
                </SYST_Substanz-ATC>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="Therapieempfehlung">
        <xsl:for-each select="Menge_Typ_Therapieempfehlung/Typ_Therapieempfehlung">
            <Typ_Therapieempfehlung>
                <xsl:value-of select="."/>
            </Typ_Therapieempfehlung>
        </xsl:for-each>
        <xsl:if test="Abweichung_Patientenwunsch">
            <Abweichung_Patientenwunsch>
                <xsl:value-of select="Abweichung_Patientenwunsch"/>
            </Abweichung_Patientenwunsch>
        </xsl:if>
    </xsl:template>

    <!--!!!!!!!!!!STRUCTURE TRANSFORMATION COMPLETED!!!!!!!!!!-->


    <!--Rename elements according to MDS-->
    <xsl:template match="Geschlecht" >
        <Geschlecht>
            <xsl:apply-templates select="node()"/>
        </Geschlecht>
    </xsl:template>
    <xsl:template match="Geburtsdatum">
        <Geburtsdatum>
            <xsl:apply-templates select="node()"/>
        </Geburtsdatum>
    </xsl:template>
    <xsl:template match="Primaertumor_ICD" >
        <xsl:if test="Code">
            <Diagnose>
                <xsl:apply-templates select="Code"/>
            </Diagnose>
        </xsl:if>
        <xsl:if test="Version">
            <ICD-Katalog_Version>
                <xsl:value-of select="Version"/>
            </ICD-Katalog_Version>
        </xsl:if>
    </xsl:template>
    <xsl:template match="Primaertumor_Diagnosetext" >
        <Diagnose_Text>
            <xsl:apply-templates select="node() | @*"/>
        </Diagnose_Text>
    </xsl:template>
    <xsl:template match="Diagnosesicherung" >
        <Diagnosesicherung>
            <xsl:apply-templates select="node() | @*"/>
        </Diagnosesicherung>
    </xsl:template>
    <xsl:template match="Allgemeiner_Leistungszustand" >
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Origin"/>
        <xsl:variable name="ECOG" select="xsi:mapToECOG(node())"/>
        <xsl:if test="string-length($ECOG)>=1">
            <ECOG>
                <xsl:attribute name="ECOG_ID" select="hash:hash($Patient_Id, $Tumor_Id, concat($ECOG, $Origin))"/>
                <xsl:value-of select="$ECOG"/>
            </ECOG>
        </xsl:if>
    </xsl:template>
    <xsl:template match="Primaertumor_Topographie_Freitext" >
        <Primaertumor_Topographie_Freitext>
            <xsl:apply-templates select="node() | @*"/>
        </Primaertumor_Topographie_Freitext>
    </xsl:template>
    <xsl:template match="Primaertumor_Topographie_ICD_O" >
        <xsl:if test="Code">
            <Lokalisation>
                <xsl:apply-templates select="Code"/>
            </Lokalisation>
        </xsl:if>
        <xsl:if test="Version">
            <ICD-O_Katalog_Topographie_Version>
                <xsl:value-of select="Version"/>
            </ICD-O_Katalog_Topographie_Version>
        </xsl:if>
    </xsl:template>
    <xsl:template match="Seitenlokalisation" >
        <Seitenlokalisation>
            <xsl:apply-templates select="node() | @*"/>
        </Seitenlokalisation>
    </xsl:template>
    <xsl:template match="Morphologie_Freitext" >
        <Morphologie_Freitext>
            <xsl:apply-templates select="node() | @*"/>
        </Morphologie_Freitext>
    </xsl:template>
    <xsl:template match="Tumor_Histologiedatum" >
        <Tumor_Histologiedatum>
            <xsl:apply-templates select="node()"/>
        </Tumor_Histologiedatum>
    </xsl:template>
    <xsl:template match="Diagnosedatum">
        <Tumor_Diagnosedatum>
            <xsl:apply-templates select="node()"/>
        </Tumor_Diagnosedatum>
    </xsl:template>
    <xsl:template match="Datum">
        <Datum>
            <xsl:apply-templates select="node()"/>
        </Datum>
    </xsl:template>
    <xsl:template match="Version">
        <TNM-Version>
            <xsl:value-of select="node() | @*"/>
        </TNM-Version>
    </xsl:template>
    <xsl:template match="y_Symbol">
        <TNM-y-Symbol>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-y-Symbol>
    </xsl:template>
    <xsl:template match="r_Symbol">
        <TNM-r-Symbol>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-r-Symbol>
    </xsl:template>
    <xsl:template match="a_Symbol">
        <TNM-a-Symbol>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-a-Symbol>
    </xsl:template>
    <xsl:template match="c_p_u_Praefix_T">
        <c-p-u-Präfix_T>
            <xsl:apply-templates select="node() | @*"/>
        </c-p-u-Präfix_T>
    </xsl:template>
    <xsl:template match="T">
        <TNM-T>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-T>
    </xsl:template>
    <xsl:template match="m_Symbol">
        <TNM-m-Symbol>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-m-Symbol>
    </xsl:template>
    <xsl:template match="c_p_u_Praefix_N">
        <c-p-u-Präfix_N>
            <xsl:apply-templates select="node() | @*"/>
        </c-p-u-Präfix_N>
    </xsl:template>
    <xsl:template match="N">
        <TNM-N>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-N>
    </xsl:template>
    <xsl:template match="c_p_u_Praefix_M">
        <c-p-u-Präfix_M>
            <xsl:apply-templates select="node() | @*"/>
        </c-p-u-Präfix_M>
    </xsl:template>
    <xsl:template match="M">
        <TNM-M>
            <xsl:apply-templates select="node() | @*"/>
        </TNM-M>
    </xsl:template>
    <xsl:template match="L">
        <L>
            <xsl:apply-templates select="node() | @*"/>
        </L>
    </xsl:template>
    <xsl:template match="V">
        <V>
            <xsl:apply-templates select="node() | @*"/>
        </V>
    </xsl:template>
    <xsl:template match="Pn">
        <Pn>
            <xsl:apply-templates select="node() | @*"/>
        </Pn>
    </xsl:template>
    <xsl:template match="S">
        <S>
            <xsl:apply-templates select="node() | @*"/>
        </S>
    </xsl:template>
    <xsl:template match="UICC_Stadium">
        <UICC_Stadium>
            <xsl:apply-templates select="node() | @*"/>
        </UICC_Stadium>
    </xsl:template>
    <xsl:template match="Intention">
        <Intention>
            <xsl:apply-templates select="node() | @*"/>
        </Intention>
    </xsl:template>
    <xsl:template match="Stellung_OP">
        <Stellung_OP>
            <xsl:apply-templates select="node() | @*"/>
        </Stellung_OP>
    </xsl:template>
    <xsl:template match="Therapieart">
        <Therapieart>
            <xsl:apply-templates select="node() | @*"/>
        </Therapieart>
    </xsl:template>
    <xsl:template match="Zielgebiet">
        <Zielgebiet>
            <xsl:apply-templates select="node() | @*"/>
        </Zielgebiet>
    </xsl:template>
    <xsl:template match="Seite_Zielgebiet">
        <Seite_Zielgebiet>
            <xsl:apply-templates select="node() | @*"/>
        </Seite_Zielgebiet>
    </xsl:template>
    <xsl:template match="Strahlenart">
        <Strahlenart>
            <xsl:apply-templates select="node() | @*"/>
        </Strahlenart>
    </xsl:template>
    <xsl:template match="Boost">
        <Boost>
            <xsl:apply-templates select="node() | @*"/>
        </Boost>
    </xsl:template>
    <xsl:template match="Untersuchungsdatum_Verlauf">
        <Datum_Verlauf>
            <xsl:apply-templates select="node() | @*"/>
        </Datum_Verlauf>
    </xsl:template>
    <xsl:template match="Gesamtbeurteilung_Tumorstatus">
        <Gesamtbeurteilung_Tumorstatus>
            <xsl:apply-templates select="node() | @*"/>
        </Gesamtbeurteilung_Tumorstatus>
    </xsl:template>
    <xsl:template match="Verlauf_Lokaler_Tumorstatus">
        <Verlauf_Lokaler_Tumorstatus>
            <xsl:apply-templates select="node() | @*"/>
        </Verlauf_Lokaler_Tumorstatus>
    </xsl:template>
    <xsl:template match="Verlauf_Tumorstatus_Lymphknoten">
        <Verlauf_Tumorstatus_Lymphknoten>
            <xsl:apply-templates select="node() | @*"/>
        </Verlauf_Tumorstatus_Lymphknoten>
    </xsl:template>
    <xsl:template match="Verlauf_Tumorstatus_Fernmetastasen">
        <Verlauf_Tumorstatus_Fernmetastasen>
            <xsl:apply-templates select="node() | @*"/>
        </Verlauf_Tumorstatus_Fernmetastasen>
    </xsl:template>
    <xsl:template match="Typ">
        <Typ>
            <xsl:apply-templates select="node() | @*"/>
        </Typ>
    </xsl:template>

    <!-- remove ADT Namespace -->
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
            <xsl:if test="Code"><Code><xsl:value-of select="Code"/></Code></xsl:if>
            <xsl:if test="Version"><Version><xsl:value-of select="Version"/></Version></xsl:if>
        </Todesursache_ICD>
    </xsl:template>
    <xsl:template match="Todesursache_ICD_Version">
        <Todesursache_ICD_Version>
            <xsl:apply-templates select="node() | @*"/>
        </Todesursache_ICD_Version>
    </xsl:template>
    <xsl:template match="Meldeanlass">
        <Meldeanlass>
            <xsl:apply-templates select="node() | @*"/>
        </Meldeanlass>
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
        <Datum_des_letztbekannten_Vitalstatus>
            <xsl:choose>
                <xsl:when test="$meldungen/Meldung/Tod/Sterbedatum">
                    <xsl:value-of select="$meldungen/Meldung/Tod/Sterbedatum"/>
                </xsl:when>
                <xsl:when test="$meldungen/Meldung/Verlauf/Untersuchungsdatum_Verlauf">
                    <xsl:variable name="nodes" select="$meldungen/Meldung/Verlauf/Untersuchungsdatum_Verlauf"/>
                    <xsl:variable name="mostRecentNode" select="$nodes[xs:date(.) = max($nodes/xs:date(.))]"/>
                    <xsl:value-of select="$mostRecentNode"/>
                </xsl:when>
                <!--TODO check
                <xsl:when test="$meldungen/Meldung/OP/Datum">
                    <xsl:value-of select="max($meldungen/Meldung/OP/Datum)"/>
                </xsl:when>
                <xsl:when test="$meldungen/Meldung/ST/Menge_Bestrahlung/Bestrahlung/Beginn | $meldungen/Meldung/ST/Menge_Bestrahlung/Bestrahlung/Ende">
                    <xsl:value-of select="max($meldungen/Meldung/ST/Menge_Bestrahlung/Bestrahlung/Beginn | $meldungen/Meldung/ST/Menge_Bestrahlung/Bestrahlung/Ende)"/>
                </xsl:when>-->
                <xsl:otherwise>
                    <xsl:value-of select="max($meldungen/Meldung/Tumorzuordnung/Diagnosedatum)"/>
                </xsl:otherwise>
            </xsl:choose>
        </Datum_des_letztbekannten_Vitalstatus>
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

    <xsl:function name="xsi:date_diff">
        <xsl:param name="date1"/>
        <xsl:param name="date2"/>
        <xsl:variable name="year1" select="number(substring($date1,1,4))"/>
        <xsl:variable name="year2" select="number(substring($date2,1,4))"/>
        <xsl:variable name="diff" select="$year2 - $year1"/>
        <xsl:variable name="month1" select="number(substring($date1,6,2))"/>
        <xsl:variable name="month2" select="number(substring($date2,6,2))"/>
        <xsl:choose>
            <xsl:when test="$month2 &lt; $month1"><xsl:value-of select="$diff -1"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="$diff"/></xsl:otherwise>
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