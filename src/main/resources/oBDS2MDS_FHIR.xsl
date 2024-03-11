<?xml version="1.0" encoding="utf-8" standalone="no"?>
<xsl:stylesheet xmlns="http://www.basisdatensatz.de/oBDS/XML"
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

    <!--Generate first Level PATIENT entity (Elements: Geschlecht | Geburtsdatum | Datum_des_letztbekannten_Vitalstatus | Vitalstatus | DKTK_ID | DKTK_LOCAL_ID)-->
    <xsl:template match="Patient">
        <Patient>
            <xsl:variable name="Patient_Id" select="@Patient_ID"/>
            <xsl:variable name="Patient_Pseudonym" select="xsi:Pseudonymize(Patienten_Stammdaten/Geschlecht, Patienten_Stammdaten/Vornamen, Patienten_Stammdaten/Nachname, Patienten_Stammdaten/Geburtsname, Patienten_Stammdaten/Geburtsdatum, @Patient_ID)"/>
            <xsl:attribute name="Patient_ID">
                <xsl:choose>
                    <xsl:when test="$keep_internal_id=true()"><xsl:value-of select="$Patient_Id"/></xsl:when>
                    <xsl:otherwise><xsl:value-of select="hash:hash($Patient_Id,'','')"/></xsl:otherwise>
                </xsl:choose>
            </xsl:attribute>
            <xsl:apply-templates select="Patienten_Stammdaten/Geschlecht"/>
            <xsl:apply-templates select="Patienten_Stammdaten/Geburtsdatum"/>
            <xsl:choose>
                <xsl:when test="./Patienten_Stammdaten/Vitalstatus_Datum"><Datum_des_letztbekannten_Vitalstatus><xsl:value-of select="./Patienten_Stammdaten/Vitalstatus_Datum"/></Datum_des_letztbekannten_Vitalstatus></xsl:when>
                <xsl:otherwise><xsl:copy-of select="xsi:Datum_des_letztbekannten_Vitalstatus(Menge_Meldung)"/></xsl:otherwise>
            </xsl:choose>
            <xsl:choose>
                <xsl:when test="Patienten_Stammdaten/Vitalstatus='verstorben'"><Vitalstatus>verstorben</Vitalstatus></xsl:when>
                <xsl:when test="Patienten_Stammdaten/Vitalstatus='lebend'"><Vitalstatus >lebend</Vitalstatus></xsl:when>
                <xsl:when test="Menge_Meldung/Meldung/Tod"><Vitalstatus>verstorben</Vitalstatus></xsl:when>
            </xsl:choose>
<!--            <DKTK_ID>TODO</DKTK_ID>-->
            <DKTK_LOCAL_ID><xsl:value-of select="$Patient_Pseudonym"/></DKTK_LOCAL_ID>
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
            <xsl:for-each select="./Menge_Meldung/Meldung[not(Tumorzuordnung/@Tumor_ID=preceding-sibling::*/Tumorzuordnung/@Tumor_ID)]">
                <xsl:apply-templates select="../../Menge_Meldung"><!--apply sequential tumor related reports -->
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="./Tumorzuordnung/@Tumor_ID"/>
                </xsl:apply-templates>
            </xsl:for-each>
        </Patient>
    </xsl:template>

    <!--Generate second Level DIAGNOSIS entity (Elements: Alter_bei_Erstdiagnose | Tumor_Diagnosedatum | Diagnose | ICD-Katalog_Version )-->
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
                <xsl:apply-templates select="$diagnoseDatum | $Tumor_Meldungen[1]/Tumorzuordnung/Primaertumor_ICD | $Tumor_Meldungen/Diagnose/Primaertumor_Diagnosetext | $Tumor_Meldungen/Diagnose/Primaertumor_Topographie_Freitext | $Tumor_Meldungen/Diagnose/Diagnosesicherung"/>
            </xsl:if>
            <!--Generate third Level TUMOR entity (Elements:  Lokalisation | ICD-O_Katalog_Topographie_Version |  Seitenlokalisation ) -->
            <Tumor>
                <xsl:attribute name="Tumor_ID" select="$Diagnosis_Id"/>
                <xsl:if test="$Tumor_Meldungen/Diagnose"><!-- don't create those elements if no Diagnose is delivered -->
                    <xsl:apply-templates select="$Tumor_Meldungen/Diagnose/Primaertumor_Topographie_ICD_O | $Tumor_Meldungen[1]/Tumorzuordnung/Seitenlokalisation"/>
                </xsl:if>
                <!--Initiate all TUMOR child nodes-->
                <xsl:apply-templates select="$Tumor_Meldungen/Diagnose">
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
        <xsl:for-each select="Histologie">
            <xsl:choose>
                <xsl:when test="@Histologie_ID"><xsl:apply-templates select=".[not(@Histologie_ID=following::*/Histologie/@Histologie_ID)]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select=".[not(Tumor_Histologiedatum=following::*/Histologie/Tumor_Histologiedatum)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="Menge_FM/Fernmetastase">
            <xsl:apply-templates select=".[not(concat(Diagnosedatum,Lokalisation)=following::*/Fernmetastase/concat(Diagnosedatum,Lokalisation))]">
                <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Fernmetastase[concat(Diagnosedatum,Lokalisation)=current()/concat(Diagnosedatum,Lokalisation)])" /></xsl:with-param>
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            </xsl:apply-templates>
        </xsl:for-each>
        <xsl:for-each select="cTNM|pTNM">
            <xsl:choose>
                <xsl:when test="@ID">
                    <xsl:apply-templates select=".[
                        not(@ID=following::*/TNM/@ID) and
                        not(@ID=following::*/cTNM/@ID) and
                        not(@ID=following::*/pTNM/@ID)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select=".[
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::*/TNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::*/pTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::*/cTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="Menge_Genetik/Genetische_Variante">
            <xsl:apply-templates select=".[not(concat(Datum,Bezeichnung,Sonstige_Auspraegung)=following::*/Genetische_Variante/concat(Datum,Bezeichnung,Sonstige_Auspraegung))]">
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
                 <xsl:attribute name="Histology_ID">
                     <xsl:variable name="attribute">
                         <xsl:choose>
                             <xsl:when test="@Histologie_ID"><xsl:value-of select="@Histologie_ID"/></xsl:when>
                             <xsl:otherwise>
                                 <xsl:value-of select="'gen',Tumor_Histologiedatum"/>
                             </xsl:otherwise>
                         </xsl:choose>
                     </xsl:variable>
                     <xsl:value-of select="concat('hist', hash:hash($Patient_Id, $Tumor_Id, $attribute))" />
                 </xsl:attribute>
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
                 <xsl:apply-templates select="Tumor_Histologiedatum | Morphologie_Freitext | Grading | LK_untersucht | LK_befallen | Sentinel_LK_untersucht | Sentinel_LK_befallen"/>
             </Histology>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Fernmetastase">
        <xsl:param name="counter"/>
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="Lokalisation and Diagnosedatum">
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
                    <xsl:otherwise><xsl:value-of select="'gen',concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)"/></xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <TNM>
                <xsl:attribute name="ID">
                    <xsl:value-of select="concat('tnm', hash:hash($Patient_Id, $Tumor_Id, $attribute))" />
                </xsl:attribute>
                <gesamtpraefix><xsl:value-of select="name(.)"/></gesamtpraefix>
                <xsl:apply-templates select="node()"/>
            </TNM>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Genetische_Variante">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:if test="Bezeichnung !=''">
            <Genetische_Variante>
                <xsl:attribute name="Gen_ID" select="concat('gen', hash:hash($Patient_Id, $Tumor_Id, Bezeichnung))" />
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
            <xsl:attribute name="Verlauf_ID" select="concat('vrl', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))" />
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

            <xsl:if test="Untersuchungsdatum_Verlauf !=''"><Datum_Verlauf><xsl:apply-templates select="Untersuchungsdatum_Verlauf/node()"/></Datum_Verlauf></xsl:if>



            <xsl:choose>
             <xsl:when test="TNM/@ID"><xsl:apply-templates select="TNM[
                 not(@ID=following::TNM[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@ID) and
                 not(@ID=following::Diagnose[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and @Tumor_ID=$Tumor_Id]/cTNM/@ID) and
                 not(@ID=following::Diagnose[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and @Tumor_ID=$Tumor_Id]/pTNM/@ID)]">
                 <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                 <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
             </xsl:apply-templates></xsl:when>
             <xsl:otherwise>
                     <xsl:apply-templates select="TNM[
                         not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::TNM[../../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and ../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                         not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::Diagnose[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and @Tumor_ID=$Tumor_Id]/pTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                         not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::Diagnose[../../../../Patienten_Stammdaten/@Patient_ID=$Patient_Id and @Tumor_ID=$Tumor_Id]/cTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))]">
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
                    not(concat(Diagnosedatum,Lokalisation)=following::*/Fernmetastase/concat(Diagnosedatum,Lokalisation))]">
                    <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Fernmetastase[concat(Diagnosedatum,Lokalisation)=current()/concat(Diagnosedatum,Lokalisation)])" /></xsl:with-param>
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
                <xsl:when test="OP_Datum"><xsl:value-of select="'gen',OP_Datum"/></xsl:when>
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
                <xsl:when test="TNM/@ID"><xsl:apply-templates select="TNM[
                    not(@ID=following::TNM[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@ID) and
                    not(@ID=following::Diagnose[@Tumor_ID=$Tumor_Id]/cTNM/@ID) and
                    not(@ID=following::Diagnose[@Tumor_ID=$Tumor_Id]/pTNM/@ID)]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates></xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="TNM[
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::TNM[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::Diagnose[@Tumor_ID=$Tumor_Id]/pTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))and
                        not(concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M)=following::Diagnose[@Tumor_ID=$Tumor_Id]/cTNM/concat(Datum,T,N,M,c_p_u_Praefix_T,c_p_u_Praefix_N,c_p_u_Praefix_M))]">
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
                    <xsl:when test="Menge_Bestrahlung[1]/Bestrahlung[1]/ST_Beginn_Datum[1]"><xsl:value-of select="'gen',Menge_Bestrahlung[1]/Bestrahlung[1]/ST_Beginn_Datum[1]"/></xsl:when>
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
                    <xsl:when test="SYST_Beginn_Datum"><xsl:value-of select="'gen',SYST_Beginn_Datum"/></xsl:when>
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
        <ST_Nebenwirkung>
            <xsl:attribute name="Nebenwirkung_ID" select="concat('stn', hash:hash($Patient_Id, $Tumor_Id, concat($Therapy_Id, Nebenwirkung_Art, Nebenwirkung_Grad, Nebenwirkung_Version)))"/>
            <xsl:if test="Nebenwirkung_Grad"><Nebenwirkung_Grad><xsl:value-of select="Nebenwirkung_Grad"/></Nebenwirkung_Grad></xsl:if>
            <xsl:if test="Nebenwirkung_Art"><Nebenwirkung_Art><xsl:value-of select="Nebenwirkung_Art"/></Nebenwirkung_Art></xsl:if>
            <xsl:if test="Nebenwirkung_Version"><Nebenwirkung_Version><xsl:value-of select="Nebenwirkung_Version"/></Nebenwirkung_Version></xsl:if>
        </ST_Nebenwirkung>
    </xsl:template>

    <xsl:template match="SYST_Nebenwirkung">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Therapy_Id"/>
        <SYST_Nebenwirkung>
            <xsl:attribute name="Nebenwirkung_ID" select="concat('syn', hash:hash($Patient_Id, $Tumor_Id, concat($Therapy_Id, Nebenwirkung_Art, Nebenwirkung_Grad, Nebenwirkung_Version)))"/>
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

    <xsl:template match="Menge_Substanz">
        <xsl:apply-templates select="SYST_Substanz"/>
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
    <xsl:template match="Grading">
        <Grading>
            <xsl:apply-templates select="node()"/>
        </Grading>
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
    <xsl:template match="LK_untersucht" >
        <LK_untersucht>
            <xsl:apply-templates select="node()"/>
        </LK_untersucht>
    </xsl:template>
    <xsl:template match="LK_befallen" >
        <LK_befallen>
            <xsl:apply-templates select="node()"/>
        </LK_befallen>
    </xsl:template>
    <xsl:template match="Sentinel_LK_untersucht" >
        <Sentinel_LK_untersucht>
            <xsl:apply-templates select="node()"/>
        </Sentinel_LK_untersucht>
    </xsl:template>
    <xsl:template match="Sentinel_LK_befallen" >
        <Sentinel_LK_befallen>
            <xsl:apply-templates select="node()"/>
        </Sentinel_LK_befallen>
    </xsl:template>
    <xsl:template match="Diagnosedatum">
        <Tumor_Diagnosedatum>
            <xsl:apply-templates select="node()"/>
        </Tumor_Diagnosedatum>
    </xsl:template>
    <xsl:template match="Datum">
        <Datum_der_TNM-Dokumentation-Datum_Befund>
            <xsl:apply-templates select="node() | @*"/>
        </Datum_der_TNM-Dokumentation-Datum_Befund>
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

</xsl:stylesheet>
