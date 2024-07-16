<?xml version="1.0" encoding="utf-8" standalone="no"?>
<xsl:stylesheet xmlns="http://www.mds.de/namespace"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.mds.de/namespace MDS_Suchmodell_v4.xsd"
    xmlns:hash="java:de.samply.obds2fhir"
    exclude-result-prefixes="#default"
    version="2.0"
    xpath-default-namespace="http://www.gekid.de/namespace">

    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    <xsl:output omit-xml-declaration="no" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:param name="add_department" />
    <xsl:param name="keep_internal_id" />

    <xsl:template match="/ADT_GEKID/Menge_Patient">
        <Patienten>
            <xsl:apply-templates select="node()| @*"/>
        </Patienten>
    </xsl:template>

    <xsl:template match="Patient">
        <xsl:choose>
            <xsl:when test="Patienten_Stammdaten/@Patient_ID!=''">
                <Patient>
                    <xsl:variable name="Patient_Id" select="if ($keep_internal_id=true()) then Patienten_Stammdaten/@Patient_ID else hash:hash(Patienten_Stammdaten/@Patient_ID,'','')"/>
                    <xsl:variable name="Geburtsdatum" select="Patienten_Stammdaten/xsi:Get-FHIR-date(Patienten_Geburtsdatum)"/>
                    <xsl:variable name="Geburtstag" select="string(replace($Geburtsdatum,'^\d{4}-\d{2}-(\d{2})$','$1'))"/>
                    <xsl:variable name="Geburtsmonat" select="string(replace($Geburtsdatum,'^\d{4}-(\d{2})-\d{2}$','$1'))"/>
                    <xsl:variable name="Geburtsjahr" select="string(replace($Geburtsdatum,'^(\d{4})-\d{2}-\d{2}$','$1'))"/>
                    <xsl:variable name="Patient_Pseudonym" select="hash:pseudonymize(
                    xsi:ReplaceEmpty(Patienten_Stammdaten/Patienten_Geschlecht),
                    xsi:ReplaceEmpty(Patienten_Stammdaten/Patienten_Vornamen),
                    xsi:ReplaceEmpty(Patienten_Stammdaten/Patienten_Nachname),
                    xsi:ReplaceEmpty(Patienten_Stammdaten/Patienten_Geburtsname),
                    xsi:ReplaceEmpty($Geburtstag),
                    xsi:ReplaceEmpty($Geburtsmonat),
                    xsi:ReplaceEmpty($Geburtsjahr),
                    xsi:ReplaceEmpty(Patienten_Stammdaten/@Patient_ID))"/>
                    <xsl:attribute name="Patient_ID" select="$Patient_Id"/>
                    <Geschlecht>
                        <xsl:value-of select="if (Patienten_Stammdaten/Patienten_Geschlecht = 'D') then 'S' else Patienten_Stammdaten/Patienten_Geschlecht" />
                    </Geschlecht>
                    <Geburtsdatum>
                        <xsl:value-of select="$Geburtsdatum"/>
                    </Geburtsdatum>
                    <DKTK_LOCAL_ID>
                        <xsl:value-of select="$Patient_Pseudonym"/>
                    </DKTK_LOCAL_ID>
                    <xsl:choose>
                        <xsl:when test="lower-case(normalize-space(Patienten_Stammdaten/DKTK_Einwilligung_erfolgt)) = 'ja'"><DKTK_Einwilligung_erfolgt>true</DKTK_Einwilligung_erfolgt></xsl:when>
                        <xsl:when test="lower-case(normalize-space(Patienten_Stammdaten/DKTK_Einwilligung_erfolgt)) = 'true'"><DKTK_Einwilligung_erfolgt>true</DKTK_Einwilligung_erfolgt></xsl:when>
                        <xsl:otherwise><DKTK_Einwilligung_erfolgt>false</DKTK_Einwilligung_erfolgt></xsl:otherwise>
                    </xsl:choose>
                    <Vitalstatus_Gesamt Vitalstatus_ID="{concat('vital', $Patient_Id)}">
                        <Datum_des_letztbekannten_Vitalstatus>
                            <xsl:value-of select="if (Patienten_Stammdaten/Vitalstatus_Datum != '') then 'Patienten_Stammdaten/Vitalstatus_Datum' else xsi:Datum_des_letztbekannten_Vitalstatus(Menge_Meldung)"/>
                        </Datum_des_letztbekannten_Vitalstatus>
                        <Vitalstatus>
                            <xsl:choose>
                                <xsl:when test="lower-case(Patienten_Stammdaten/Vitalstatus)='verstorben'">verstorben</xsl:when>
                                <xsl:when test="lower-case(Patienten_Stammdaten/Vitalstatus)='lebend'">lebend</xsl:when>
                                <xsl:when test="Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Tod">verstorben</xsl:when>
                                <xsl:when test="not(Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Tod)">lebend</xsl:when>
                            </xsl:choose>
                        </Vitalstatus>
                        <xsl:apply-templates select="Menge_Meldung/Meldung/Menge_Verlauf/Verlauf/Tod[not(following::Tod)]"/>
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

                    <xsl:apply-templates select="Menge_Meldung/Meldung/Menge_Biomaterial/Biomaterial[not(@Biomaterial_ID=following::*/@Biomaterial_ID)]">
                        <xsl:with-param name="Patient_Id" select="Patienten_Stammdaten/@Patient_ID"/>
                    </xsl:apply-templates>
                    <xsl:for-each select="Menge_Meldung/Meldung[not(Tumorzuordnung/@Tumor_ID=preceding-sibling::*/Tumorzuordnung/@Tumor_ID) and not(Menge_Biomaterial)]">
                        <xsl:choose>
                            <xsl:when test="Tumorzuordnung/@Tumor_ID[.!='']">
                                <xsl:apply-templates select="../../Menge_Meldung"><!--apply sequential tumor related reports -->
                                    <xsl:with-param name="Tumor_Id" select="Tumorzuordnung/@Tumor_ID"/>
                                    <xsl:with-param name="Patient_Id" select="../../Patienten_Stammdaten/@Patient_ID"/>
                                </xsl:apply-templates>
                            </xsl:when>
                            <xsl:when test="Menge_Verlauf/Verlauf/Tod"/><!--do not throw error-->
                            <xsl:otherwise>
                                <xsl:message>
                                    WARN: Meldung ohne Tumorzuordnung in Patient <xsl:value-of select="../../Patienten_Stammdaten/@Patient_ID"/> !
                                </xsl:message>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </Patient>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes" select="'ERROR: Missing Patient_ID!'"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="Biomaterial">
        <xsl:param name="Patient_Id"/>
        <xsl:if test="(Fixierungsart|Probentyp|Probenart|Entnahmedatum)!=''">
            <xsl:variable name="Entnahmedatum" select="xsi:Get-FHIR-date(Entnahmedatum)"/>
            <Sample>
                <xsl:attribute name="Sample_ID" >
                    <xsl:variable name="attribute">
                    <xsl:choose>
                        <xsl:when test="@Biomaterial_ID!=''"><xsl:value-of select="@Biomaterial_ID"/></xsl:when>
                        <xsl:when test="Entnahmedatum!=''">gen:<xsl:value-of select="Entnahmedatum,position()"/></xsl:when>
                        <xsl:otherwise>gen:missing-ID-and-Date</xsl:otherwise>
                    </xsl:choose>
                    </xsl:variable>
                    <xsl:value-of select="concat('bio', hash:hash($Patient_Id, '', string-join($attribute, '')))" />
                </xsl:attribute>
                <xsl:if test="$Entnahmedatum!=''"><Entnahmedatum><xsl:value-of select="$Entnahmedatum"/></Entnahmedatum></xsl:if>
                <xsl:if test="Fixierungsart!=''"><Fixierungsart><xsl:value-of select="Fixierungsart"/></Fixierungsart></xsl:if>
                <xsl:if test="Probentyp!=''"><Probentyp><xsl:value-of select="Probentyp"/></Probentyp></xsl:if>
                <xsl:if test="Probenart!=''"><Probenart><xsl:value-of select="Probenart"/></Probenart></xsl:if>
            </Sample>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Menge_Meldung">
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Patient_Id"/>
        <xsl:variable name="Tumor_Meldung" select="Meldung[Tumorzuordnung/@Tumor_ID=$Tumor_Id]"/>
        <xsl:variable name="Diagnosis_Meldung" select="$Tumor_Meldung/Diagnose[not(@Tumor_ID=following::Diagnose/@Tumor_ID)]"/>
        <!--Some cases allow ambiguous "Diagnosedatum": therefore set unambiguous Variable "diagnoseDatum"-->
        <xsl:variable name="diagnoseDatum">
            <xsl:value-of select="if ($Diagnosis_Meldung/Diagnosedatum!='') then $Diagnosis_Meldung/Diagnosedatum else $Tumor_Meldung[1]/Tumorzuordnung/Diagnosedatum" />
        </xsl:variable>
        <Diagnosis>
            <xsl:attribute name="Diagnosis_ID" select="concat('dig', hash:hash($Patient_Id, $Tumor_Id, ''))"/>
            <xsl:if test="$Diagnosis_Meldung!=''"><!-- don't create those elements if no Diagnose is delivered -->
                <xsl:element name="Alter_bei_Erstdiagnose">
                    <xsl:variable name="geb" select="number(replace(../Patienten_Stammdaten/Patienten_Geburtsdatum,'\d\d\.\d\d\.(\d\d\d\d)$','$1'))"/>
                    <xsl:variable name="diag" select="number(replace($diagnoseDatum,'\d\d\.\d\d\.(\d\d\d\d)$','$1'))"/>
                    <xsl:variable name="dif" select="$diag - $geb"/>
                    <xsl:variable name="gebMonths" select="number(replace(../Patienten_Stammdaten/Patienten_Geburtsdatum,'(\d\d)\.(\d\d)\.\d\d\d\d','$2$1'))"/>
                    <xsl:variable name="diagMonths" select="number(replace($diagnoseDatum,'(\d\d)\.(\d\d)\.\d\d\d\d','$2$1'))"/>
                    <xsl:value-of select="if ($diagMonths &lt; $gebMonths) then $dif -1 else $dif"/>
                </xsl:element>
                <Tumor_Diagnosedatum><xsl:apply-templates select="xsi:Get-FHIR-date($diagnoseDatum)"/></Tumor_Diagnosedatum>
                <xsl:apply-templates select="$Diagnosis_Meldung/Primaertumor_ICD_Code | $Diagnosis_Meldung/Primaertumor_ICD_Version | $Diagnosis_Meldung/Primaertumor_Diagnosetext | $Diagnosis_Meldung/Primaertumor_Topographie_ICD_O_Freitext | $Diagnosis_Meldung/Diagnosesicherung"/>
                <xsl:apply-templates select="$Diagnosis_Meldung/Allgemeiner_Leistungszustand | $Diagnosis_Meldung/Menge_Weitere_Klassifikation">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    <xsl:with-param name="Origin" select="$Diagnosis_Meldung/Diagnosedatum"/>
                </xsl:apply-templates>
            </xsl:if>
            <Tumor>
                <xsl:attribute name="Tumor_ID" select="concat('tmr', hash:hash($Patient_Id, $Tumor_Id, ''))"/>
                <xsl:if test="$Diagnosis_Meldung!=''"><!-- don't create those elements if no Diagnose is delivered -->
                    <xsl:apply-templates select="$Diagnosis_Meldung/Primaertumor_Topographie_ICD_O | $Diagnosis_Meldung/Primaertumor_Topographie_ICD_O_Version | $Diagnosis_Meldung/Seitenlokalisation"/>
                </xsl:if>
                <xsl:apply-templates select="$Diagnosis_Meldung">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
                <xsl:for-each select="$Tumor_Meldung/Menge_OP/OP">
                    <xsl:choose>
                        <xsl:when test="@OP_ID!=''"><xsl:apply-templates select=".[not(@OP_ID=following::OP[../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@OP_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(OP_Datum=following::OP[../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/OP_Datum)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldung/Menge_ST/ST">
                    <xsl:choose>
                        <xsl:when test="@ST_ID!=''"><xsl:apply-templates select=".[not(@ST_ID=following::ST[../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@ST_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(Menge_Bestrahlung/Bestrahlung/ST_Beginn_Datum=following::ST[../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/Menge_Bestrahlung/Bestrahlung/ST_Beginn_Datum)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldung/Menge_SYST/SYST">
                    <xsl:choose>
                        <xsl:when test="@SYST_ID!=''"><xsl:apply-templates select=".[not(@SYST_ID=following::SYST[../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@SYST_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(SYST_Beginn_Datum=following::SYST[../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/SYST_Beginn_Datum)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:for-each select="$Tumor_Meldung/Menge_Verlauf/Verlauf">
                    <xsl:choose>
                        <xsl:when test="@Verlauf_ID!=''"><xsl:apply-templates select=".[not(@Verlauf_ID=following::Verlauf[../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@Verlauf_ID)]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise><xsl:apply-templates select=".[not(Untersuchungsdatum_Verlauf=following::Verlauf[../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/Untersuchungsdatum_Verlauf)]">
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
                <xsl:when test="@TNM_ID!=''">
                    <xsl:apply-templates select=".[
                        not(@TNM_ID = (following::TNM[../../../Tumorzuordnung/@Tumor_ID = $Tumor_Id])/@TNM_ID)]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select=".[
                        not(concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)=following::TNM[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="Menge_Histologie/Histologie">
            <xsl:choose>
                <xsl:when test="@Histologie_ID!=''"><xsl:apply-templates select=".[
                    not(@Histologie_ID=following::Histologie[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/@Histologie_ID)]">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                </xsl:apply-templates>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select=".[
                        not(concat(Tumor_Histologiedatum,Morphologie_Code,Grading)=following::Histologie[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(Tumor_Histologiedatum,Morphologie_Code,Grading))]">
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
        <xsl:for-each select="Menge_FM/Fernmetastase">
            <xsl:apply-templates select=".[
                not(concat(FM_Diagnosedatum,FM_Lokalisation)=following::Fernmetastase/concat(FM_Diagnosedatum,FM_Lokalisation))]">
                <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Fernmetastase[concat(FM_Diagnosedatum,FM_Lokalisation)=current()/concat(FM_Diagnosedatum,FM_Lokalisation)])" /></xsl:with-param>
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="Histologie">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="Histologiedatum" select="xsi:Get-FHIR-date(Tumor_Histologiedatum)"/>
        <xsl:if test="$Histologiedatum !=''">
             <Histology>
                 <xsl:variable name="Histology_ID">
                     <xsl:choose>
                         <xsl:when test="@Histologie_ID!=''"><xsl:value-of select="hash:hash($Patient_Id, $Tumor_Id, @Histologie_ID)"/></xsl:when>
                         <xsl:otherwise>
                             <xsl:value-of select="hash:hash($Patient_Id, $Tumor_Id, concat('gen', string-join(Tumor_Histologiedatum,''),Morphologie_Code,Grading))"/>
                         </xsl:otherwise>
                     </xsl:choose>
                 </xsl:variable>
                 <xsl:attribute name="Histology_ID" select="concat('hist', $Histology_ID)"/>
                 <xsl:apply-templates select="Morphologie_Code | Morphologie_ICD_O_Version | Morphologie_Freitext"/>
                 <xsl:if test="Grading!=''"><Grading Grading_ID="{concat('grd', $Histology_ID)}"><xsl:value-of select="Grading"/></Grading></xsl:if>
                 <Tumor_Histologiedatum><xsl:value-of select="$Histologiedatum"/></Tumor_Histologiedatum>
                 <xsl:if test="LK_untersucht!=''"><LK_untersucht LK_untersucht_ID="{concat('lku', $Histology_ID)}"><xsl:value-of select="LK_untersucht"/></LK_untersucht></xsl:if>
                 <xsl:if test="LK_befallen!=''"><LK_befallen LK_befallen_ID="{concat('lkb', $Histology_ID)}"><xsl:value-of select="LK_befallen"/></LK_befallen></xsl:if>
                 <xsl:if test="Sentinel_LK_untersucht!=''"><Sentinel_LK_untersucht Sentinel_LK_untersucht_ID="{concat('slku', $Histology_ID)}"><xsl:value-of select="Sentinel_LK_untersucht"/></Sentinel_LK_untersucht></xsl:if>
                 <xsl:if test="Sentinel_LK_befallen!=''"><Sentinel_LK_befallen Sentinel_LK_befallen_ID="{concat('slkb', $Histology_ID)}"><xsl:value-of select="Sentinel_LK_befallen"/></Sentinel_LK_befallen></xsl:if>
             </Histology>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Fernmetastase">
        <xsl:param name="counter"/>
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="FM_Diagnosedatum" select="xsi:Get-FHIR-date(FM_Diagnosedatum)"/>
        <xsl:if test="FM_Lokalisation!='' and $FM_Diagnosedatum!=''">
           <Metastasis>
               <xsl:attribute name="Metastasis_ID">
                   <xsl:variable name="attribute" select="'gen',concat(string-join($FM_Diagnosedatum,''),FM_Lokalisation,$counter)"/>
                   <xsl:value-of select="concat('fm', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))" />
               </xsl:attribute>
               <xsl:apply-templates select="FM_Diagnosedatum | FM_Lokalisation"/>
               <Fernmetastasen_vorhanden>ja</Fernmetastasen_vorhanden>
          </Metastasis>
        </xsl:if>
   </xsl:template>

    <xsl:template match="pTNM | cTNM | TNM">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="TNM_Datum" select="xsi:Get-FHIR-date(TNM_Datum)"/>
        <xsl:if test="$TNM_Datum !=''">
            <TNM>
                <xsl:attribute name="TNM_ID">
                    <xsl:variable name="attribute">
                        <xsl:choose>
                            <xsl:when test="@TNM_ID!=''"><xsl:value-of select="@TNM_ID"/></xsl:when>
                            <xsl:otherwise><xsl:value-of select="'gen',concat($TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M,name(.))"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <xsl:value-of select="concat('tnm', hash:hash($Patient_Id, $Tumor_Id, $attribute))" />
                </xsl:attribute>
                <gesamtpraefix><xsl:value-of select="name(.)"/></gesamtpraefix>
                <Datum><xsl:value-of select="$TNM_Datum"/></Datum>
                <xsl:if test="TNM_Version!=''"><TNM-Version><xsl:value-of select="TNM_Version"/></TNM-Version></xsl:if>
                <xsl:if test="TNM_y_Symbol!=''"><TNM-y-Symbol><xsl:value-of select="TNM_y_Symbol"/></TNM-y-Symbol></xsl:if>
                <xsl:if test="TNM_r_Symbol!=''"><TNM-r-Symbol><xsl:value-of select="TNM_r_Symbol"/></TNM-r-Symbol></xsl:if>
                <xsl:if test="TNM_a_Symbol!=''"><TNM-a-Symbol><xsl:value-of select="TNM_a_Symbol"/></TNM-a-Symbol></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_T!=''"><c-p-u-Präfix_T><xsl:value-of select="TNM_c_p_u_Praefix_T"/></c-p-u-Präfix_T></xsl:if>
                <xsl:if test="TNM_T!=''"><TNM-T><xsl:value-of select="TNM_T"/></TNM-T></xsl:if>
                <xsl:if test="TNM_m_Symbol!=''"><TNM-m-Symbol><xsl:value-of select="TNM_m_Symbol"/></TNM-m-Symbol></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_N!=''"><c-p-u-Präfix_N><xsl:value-of select="TNM_c_p_u_Praefix_N"/></c-p-u-Präfix_N></xsl:if>
                <xsl:if test="TNM_N!=''"><TNM-N><xsl:value-of select="TNM_N"/></TNM-N></xsl:if>
                <xsl:if test="TNM_c_p_u_Praefix_M!=''"><c-p-u-Präfix_M><xsl:value-of select="TNM_c_p_u_Praefix_M"/></c-p-u-Präfix_M></xsl:if>
                <xsl:if test="TNM_M!=''"><TNM-M><xsl:value-of select="TNM_M"/></TNM-M></xsl:if>
                <xsl:if test="TNM_L!=''"><L><xsl:value-of select="TNM_L"/></L></xsl:if>
                <xsl:if test="TNM_V!=''"><V><xsl:value-of select="TNM_V"/></V></xsl:if>
                <xsl:if test="TNM_Pn!=''"><Pn><xsl:value-of select="TNM_Pn"/></Pn></xsl:if>
                <xsl:if test="TNM_S!=''"><S><xsl:value-of select="TNM_S"/></S></xsl:if>
                <xsl:choose>
                    <xsl:when test="UICC!=''">
                        <UICC_Stadium><xsl:value-of select="UICC"/></UICC_Stadium>
                    </xsl:when>
                    <xsl:when test="../Menge_Weitere_Klassifikation">
                        <xsl:for-each select="../Menge_Weitere_Klassifikation/Weitere_Klassifikation">
                            <xsl:if test="contains(lower-case(normalize-space(Name)), 'uicc')">
                                <UICC_Stadium><xsl:value-of select="Stadium"/></UICC_Stadium>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:when>
                </xsl:choose>
            </TNM>
        </xsl:if>
    </xsl:template>

    <xsl:template match="Verlauf">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="Untersuchungsdatum_Verlauf" select="xsi:Get-FHIR-date(Untersuchungsdatum_Verlauf)"/>
        <xsl:if test="TNM or Histologie or Menge_FM or ($Untersuchungsdatum_Verlauf!='' and (
            xs:boolean(xsi:validVerlaufElement(Allgemeiner_Leistungszustand)) or xs:boolean(xsi:validVerlaufElement(Gesamtbeurteilung_Tumorstatus)) or xs:boolean(xsi:validVerlaufElement(Verlauf_Lokaler_Tumorstatus)) or
            xs:boolean(xsi:validVerlaufElement(Verlauf_Tumorstatus_Lymphknoten)) or xs:boolean(xsi:validVerlaufElement(Verlauf_Tumorstatus_Fernmetastasen))))">
            <xsl:variable name="attribute">
                <xsl:choose>
                    <xsl:when test="@Verlauf_ID!=''"><xsl:value-of select="@Verlauf_ID"/></xsl:when>
                    <xsl:when test="$Untersuchungsdatum_Verlauf!=''"><xsl:value-of select="'gen',$Untersuchungsdatum_Verlauf"/></xsl:when>
                    <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <Verlauf>
                <xsl:variable name="Verlauf_ID" select="concat('vrl', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
                <xsl:attribute name="Verlauf_ID" select="$Verlauf_ID" />
                <xsl:apply-templates select="Verlauf_Lokaler_Tumorstatus | Verlauf_Tumorstatus_Lymphknoten | Verlauf_Tumorstatus_Fernmetastasen | Gesamtbeurteilung_Tumorstatus"/>
                <xsl:if test="$Untersuchungsdatum_Verlauf !=''"><Datum_Verlauf><xsl:value-of select="$Untersuchungsdatum_Verlauf"/></Datum_Verlauf></xsl:if>
                <xsl:apply-templates select="Allgemeiner_Leistungszustand | Menge_Weitere_Klassifikation">
                    <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                    <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    <xsl:with-param name="Origin" select="concat($Untersuchungsdatum_Verlauf, $Verlauf_ID)"/>
                </xsl:apply-templates>
                <xsl:for-each select="TNM">
                    <xsl:choose>
                        <xsl:when test="@TNM_ID!=''">
                            <xsl:apply-templates select=".[not(@TNM_ID = (following::TNM[../../../Tumorzuordnung/@Tumor_ID = $Tumor_Id]/@TNM_ID,
                                                                          following::Diagnose[@Tumor_ID = $Tumor_Id]/(cTNM|pTNM)/@TNM_ID))]">
                                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                            </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:variable name="content" select="concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)"/>
                            <xsl:apply-templates select=".[not($content=following::TNM[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))and
                                                           not($content=following::Diagnose[@Tumor_ID=$Tumor_Id]/(cTNM|pTNM)/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))]">
                                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                            </xsl:apply-templates>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
                <xsl:choose>
                    <xsl:when test="Histologie/@Histologie_ID!=''">
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
                        not(concat(FM_Diagnosedatum,FM_Lokalisation)=following::Fernmetastase/concat(FM_Diagnosedatum,FM_Lokalisation))]">
                        <xsl:with-param name="counter"><xsl:value-of select="count(preceding-sibling::Fernmetastase[concat(FM_Diagnosedatum,FM_Lokalisation)=current()/concat(FM_Diagnosedatum,FM_Lokalisation)])" /></xsl:with-param>
                        <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                        <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                    </xsl:apply-templates>
                </xsl:for-each>
            </Verlauf>
        </xsl:if>
    </xsl:template>

    <xsl:template match="OP">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="attribute">
            <xsl:choose>
                <xsl:when test="@OP_ID!=''"><xsl:value-of select="@OP_ID"/></xsl:when>
                <xsl:when test="OP_Datum!=''"><xsl:value-of select="'gen',OP_Datum"/></xsl:when>
                <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <OP>
            <xsl:attribute name="OP_ID" select="concat('op', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
            <xsl:apply-templates select="OP_Intention | OP_Datum | Menge_OPS/OP_OPS | OP_OPS_Version"/>
            <xsl:if test="Menge_Komplikation/OP_Komplikation !=''">
                <Komplikationen>
                    <xsl:for-each select="Menge_Komplikation/OP_Komplikation[. != '']">
                        <Komplikation>
                            <xsl:value-of select="."/>
                        </Komplikation>
                    </xsl:for-each>
                </Komplikationen>
            </xsl:if>
            <xsl:apply-templates select="Residualstatus[not(concat(Lokale_Beurteilung_Residualstatus,Gesamtbeurteilung_Residualstatus)=following-sibling::*/concat(Lokale_Beurteilung_Residualstatus,Gesamtbeurteilung_Residualstatus))]"/>
            <xsl:for-each select="TNM">
                <xsl:choose>
                    <xsl:when test="@TNM_ID!=''">
                        <xsl:apply-templates select=".[not(@TNM_ID = (following::TNM[../../../Tumorzuordnung/@Tumor_ID = $Tumor_Id]/@TNM_ID,
                                                                      following::Diagnose[@Tumor_ID = $Tumor_Id]/(cTNM|pTNM)/@TNM_ID))]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:variable name="content" select="concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M)"/>
                        <xsl:apply-templates select=".[not($content=following::TNM[../../../Tumorzuordnung/@Tumor_ID=$Tumor_Id]/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))and
                                                       not($content=following::Diagnose[@Tumor_ID=$Tumor_Id]/(cTNM|pTNM)/concat(TNM_Datum,TNM_T,TNM_N,TNM_M,TNM_c_p_u_Praefix_T,TNM_c_p_u_Praefix_N,TNM_c_p_u_Praefix_M))]">
                            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                        </xsl:apply-templates>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
            <xsl:choose>
                <xsl:when test="Histologie/@Histologie_ID!=''">
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
                    <xsl:when test="@ST_ID!=''"><xsl:value-of select="@ST_ID"/></xsl:when>
                    <xsl:when test="Menge_Bestrahlung[1]/Bestrahlung[1]/ST_Beginn_Datum[1]!=''"><xsl:value-of select="'gen',Menge_Bestrahlung[1]/Bestrahlung[1]/ST_Beginn_Datum[1]"/></xsl:when>
                    <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:attribute name="ST_ID" select="concat('st', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
            <xsl:apply-templates select="ST_Intention | ST_Stellung_OP | ST_Ende_Grund | Residualstatus"/>
            <xsl:apply-templates select="Menge_Nebenwirkung">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                <xsl:with-param name="Therapy_Id" select="string-join($attribute, '')"/>
            </xsl:apply-templates>
            <xsl:for-each select="Menge_Bestrahlung/Bestrahlung">
                <xsl:apply-templates select=".[
                    not(concat(ST_Beginn_Datum, ST_Ende_Datum, ST_Applikationsart, ST_Zielgebiet, ST_Seite_Zielgebiet, ST_Gesamtdosis/Dosis, ST_Einzeldosis/Dosis)=following::Bestrahlung/concat(ST_Beginn_Datum, ST_Ende_Datum, ST_Applikationsart, ST_Zielgebiet, ST_Seite_Zielgebiet, ST_Gesamtdosis/Dosis, ST_Einzeldosis/Dosis))]">
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
        <xsl:variable name="SYST_Datum" select="xsi:Get-FHIR-date(SYST_Beginn_Datum[not(../SYST_Ende_Datum)]|SYST_Ende_Datum)"/>
        <SYST>
            <xsl:variable name="attribute">
                <xsl:choose>
                    <xsl:when test="@SYST_ID!=''"><xsl:value-of select="@SYST_ID"/></xsl:when>
                    <xsl:when test="$SYST_Datum!=''"><xsl:value-of select="'gen',$SYST_Datum"/></xsl:when>
                    <xsl:otherwise>gen:missing_ID_and_Date</xsl:otherwise>
                </xsl:choose></xsl:variable>
            <xsl:attribute name="SYST_ID" select="concat('syst', hash:hash($Patient_Id, $Tumor_Id, string-join($attribute, '')))"/>
            <xsl:apply-templates select="SYST_Intention | SYST_Stellung_OP | Menge_Therapieart | SYST_Ende_Grund | Residualstatus | SYST_Beginn_Datum | SYST_Ende_Datum | SYST_Protokoll | Menge_Substanz"/>
            <xsl:apply-templates select="Menge_Nebenwirkung">
                <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
                <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
                <xsl:with-param name="Therapy_Id" select="string-join($attribute, '')"/>
            </xsl:apply-templates>
        </SYST>
    </xsl:template>

    <!-- Sub functions -->

    <xsl:template match="Menge_Nebenwirkung">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Therapy_Id"/>
        <xsl:apply-templates select="ST_Nebenwirkung[not(concat(Nebenwirkung_Grad,Nebenwirkung_Art,Nebenwirkung_Version)=following::ST_Nebenwirkung/concat(Nebenwirkung_Grad,Nebenwirkung_Art,Nebenwirkung_Version))]">
            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            <xsl:with-param name="Therapy_Id" select="$Therapy_Id"/>
        </xsl:apply-templates>
        <xsl:apply-templates select="SYST_Nebenwirkung[not(concat(Nebenwirkung_Grad,Nebenwirkung_Art,Nebenwirkung_Version)=following::SYST_Nebenwirkung/concat(Nebenwirkung_Grad,Nebenwirkung_Art,Nebenwirkung_Version))]">
            <xsl:with-param name="Patient_Id" select="$Patient_Id"/>
            <xsl:with-param name="Tumor_Id" select="$Tumor_Id"/>
            <xsl:with-param name="Therapy_Id" select="$Therapy_Id"/>
        </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="ST_Nebenwirkung | SYST_Nebenwirkung">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Therapy_Id"/>
        <xsl:if test="Nebenwirkung_Grad!=''">
            <Nebenwirkung>
                <xsl:attribute name="Nebenwirkung_ID" select="concat('nbn', hash:hash($Patient_Id, $Tumor_Id, concat($Therapy_Id, Nebenwirkung_Art, Nebenwirkung_Grad, Nebenwirkung_Version)))"/>
                <Grad><xsl:value-of select="Nebenwirkung_Grad"/></Grad>
                <xsl:if test="Nebenwirkung_Version!=''"><Version><xsl:value-of select="Nebenwirkung_Version"/></Version></xsl:if>
                <xsl:if test="Nebenwirkung_Art!=''"><Art><xsl:value-of select="Nebenwirkung_Art"/></Art></xsl:if>
                <Typ>ADT2</Typ>
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
       <xsl:if test="Lokale_Beurteilung_Residualstatus!=''"><Lokale_Beurteilung_Resttumor><xsl:value-of select="Lokale_Beurteilung_Residualstatus"/></Lokale_Beurteilung_Resttumor></xsl:if>
       <xsl:if test="Gesamtbeurteilung_Residualstatus!=''"><Gesamtbeurteilung_Resttumor><xsl:value-of select="Gesamtbeurteilung_Residualstatus"/></Gesamtbeurteilung_Resttumor></xsl:if>
    </xsl:template>

    <xsl:template match="Bestrahlung">
        <xsl:param name="counter"/>
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:variable name="ST_Beginn_Datum" select="xsi:Get-FHIR-date(ST_Beginn_Datum)"/>
        <xsl:variable name="ST_Ende_Datum" select="xsi:Get-FHIR-date(ST_Ende_Datum)"/>
        <Bestrahlung>
            <xsl:attribute name="Betrahlung_ID" select="concat('sts', hash:hash($Patient_Id, $Tumor_Id, concat(ST_Beginn_Datum, ST_Ende_Datum, ST_Applikationsart, ST_Zielgebiet, ST_Seite_Zielgebiet, ST_Gesamtdosis/Dosis, ST_Einzeldosis/Dosis)),'-',$counter)"/>
            <xsl:if test="$ST_Beginn_Datum!=''"><Beginn_Datum><xsl:value-of select="$ST_Beginn_Datum"/></Beginn_Datum></xsl:if>
            <xsl:if test="$ST_Ende_Datum!=''"><Ende_Datum><xsl:value-of select="$ST_Ende_Datum"/></Ende_Datum></xsl:if>
            <xsl:if test="ST_Applikationsart!=''">
                <xsl:copy-of select="xsi:mapToApplicationtype(ST_Applikationsart)"/>
                <ApplikationsartLegacy><xsl:value-of select="ST_Applikationsart"/></ApplikationsartLegacy>
            </xsl:if>
            <xsl:if test="ST_Zielgebiet!=''"><Zielgebiet><xsl:value-of select="ST_Zielgebiet"/></Zielgebiet></xsl:if>
            <xsl:if test="ST_Seite_Zielgebiet!=''"><Seite_Zielgebiet><xsl:value-of select="ST_Seite_Zielgebiet"/></Seite_Zielgebiet></xsl:if>
            <xsl:apply-templates select="ST_Gesamtdosis"/>
            <xsl:apply-templates select="ST_Einzeldosis"/>
        </Bestrahlung>
    </xsl:template>

    <xsl:template match="ST_Gesamtdosis">
        <Gesamtdosis>
            <xsl:if test="Dosis!=''"><Dosis><xsl:value-of select="Dosis"/></Dosis></xsl:if>
            <xsl:if test="Einheit!=''"><Einheit><xsl:value-of select="Einheit"/></Einheit></xsl:if>
        </Gesamtdosis>
    </xsl:template>

    <xsl:template match="ST_Einzeldosis">
        <Einzeldosis>
            <xsl:if test="Dosis!=''"><Dosis><xsl:value-of select="Dosis"/></Dosis></xsl:if>
            <xsl:if test="Einheit!=''"><Einheit><xsl:value-of select="Einheit"/></Einheit></xsl:if>
        </Einzeldosis>
    </xsl:template>

    <xsl:template match="Menge_Weitere_Klassifikation">
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:for-each select="Weitere_Klassifikation">
            <xsl:if test=".[not(concat(Datum, Name, Stadium)=following::Weitere_Klassifikation/concat(Datum, Name, Stadium))]">
                <xsl:variable name="Datum" select="xsi:Get-FHIR-date(Datum)"/>
                <Weitere_Klassifikation>
                    <xsl:attribute name="WeitereKlassifikation_ID" select="hash:hash($Patient_Id, $Tumor_Id, concat(Datum, Name, Stadium))"/>
                    <xsl:if test="$Datum!=''"><Datum><xsl:value-of select="$Datum"/></Datum></xsl:if>
                    <xsl:if test="Name!=''"><Name><xsl:value-of select="Name"/></Name></xsl:if>
                    <xsl:if test="Stadium!=''"><Stadium><xsl:value-of select="Stadium"/></Stadium></xsl:if>
                </Weitere_Klassifikation>
            </xsl:if>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="Menge_Substanz">
        <xsl:apply-templates select="SYST_Substanz"/>
    </xsl:template>

    <!--!!!!!!!!!!STRUCTURE TRANSFORMATION COMPLETED!!!!!!!!!!-->

    <!--Rename elements according to MDS-->
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
    <xsl:template match="Seitenlokalisation" >
        <Seitenlokalisation>
            <xsl:apply-templates select="node() | @*"/>
        </Seitenlokalisation>
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
    <xsl:template match="Verlauf_Lokaler_Tumorstatus" >
        <Lokales-regionäres_Rezidiv>
            <xsl:apply-templates select="node() | @*"/>
        </Lokales-regionäres_Rezidiv>
    </xsl:template>
    <xsl:template match="Verlauf_Tumorstatus_Lymphknoten" >
        <Lymphknoten-Rezidiv>
            <xsl:apply-templates select="node() | @*"/>
        </Lymphknoten-Rezidiv>
    </xsl:template>
    <xsl:template match="Verlauf_Tumorstatus_Fernmetastasen" >
        <Fernmetastasen>
            <xsl:apply-templates select="node() | @*"/>
        </Fernmetastasen>
    </xsl:template>
    <xsl:template match="Gesamtbeurteilung_Tumorstatus" >
        <Ansprechen_im_Verlauf>
            <xsl:apply-templates select="node() | @*"/>
        </Ansprechen_im_Verlauf>
    </xsl:template>
    <xsl:template match="Allgemeiner_Leistungszustand" >
        <xsl:param name="Patient_Id"/>
        <xsl:param name="Tumor_Id"/>
        <xsl:param name="Origin"/>
        <xsl:if test=".!='U'"><!--reduce bloat-->
            <xsl:variable name="ECOG" select="xsi:mapToECOG(node())"/>
            <xsl:if test="string-length($ECOG)>=1">
                <ECOG>
                    <xsl:attribute name="ECOG_ID" select="hash:hash($Patient_Id, $Tumor_Id, concat($ECOG, $Origin))"/>
                    <xsl:value-of select="$ECOG"/>
                </ECOG>
            </xsl:if>
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
            <xsl:value-of select="xsi:Get-FHIR-date(.)"/>
        </Datum_diagnostische_Sicherung>
    </xsl:template>
    <xsl:template match="FM_Lokalisation" >
        <Lokalisation_Fernmetastasen>
            <xsl:apply-templates select="node() | @*"/>
        </Lokalisation_Fernmetastasen>
    </xsl:template>
    <xsl:template match="TNM_Datum" >
        <Datum>
            <xsl:value-of select="xsi:Get-FHIR-date(.)"/>
        </Datum>
    </xsl:template>
    <xsl:template match="Diagnosedatum">
        <Tumor_Diagnosedatum>
            <xsl:value-of select="xsi:Get-FHIR-date(.)"/>
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
        <Intention>
        <xsl:apply-templates select="node() | @*"/>
        </Intention>
    </xsl:template>
    <xsl:template match="SYST_Intention">
        <Intention_Chemotherapie>
        <xsl:apply-templates select="node() | @*"/>
        </Intention_Chemotherapie>
    </xsl:template>
    <xsl:template match="ST_Stellung_OP">
        <Stellung_OP>
            <xsl:apply-templates select="node() | @*"/>
        </Stellung_OP>
    </xsl:template>
    <xsl:template match="SYST_Stellung_OP">
        <Systemische_Therapie_Stellung_zu_operativer_Therapie>
            <xsl:apply-templates select="node() | @*"/>
        </Systemische_Therapie_Stellung_zu_operativer_Therapie>
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
    <xsl:template match="SYST_Beginn_Datum">
        <Systemische_Therapie_Beginn>
            <xsl:value-of select="xsi:Get-FHIR-date(.)"/>
        </Systemische_Therapie_Beginn>
    </xsl:template>
    <xsl:template match="SYST_Ende_Datum">
        <Systemische_Therapie_Ende>
            <xsl:value-of select="xsi:Get-FHIR-date(.)"/>
        </Systemische_Therapie_Ende>
    </xsl:template>
    <xsl:template match="SYST_Protokoll">
        <Systemische_Therapie_Protokoll>
            <xsl:apply-templates select="node() | @*"/>
        </Systemische_Therapie_Protokoll>
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
            <xsl:value-of select="xsi:Get-FHIR-date(.)"/>
        </OP_Datum>
    </xsl:template>
    <xsl:template match="ST_Ende_Grund">
        <Ende_Grund>
            <xsl:apply-templates select="node() | @*"/>
        </Ende_Grund>
    </xsl:template>
    <xsl:template match="Sterbedatum">
        <Sterbedatum>
            <xsl:apply-templates select="xsi:Get-FHIR-date(.)"/>
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
                <xsl:value-of select="max($meldungen/Meldung/Menge_Verlauf/Verlauf/Tod/xs:date(xsi:Get-FHIR-date(Sterbedatum)))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="max($meldungen//xs:date(xsi:Get-FHIR-date(Diagnosedatum|TNM_Datum|OP_Datum|ST_Beginn_Datum[not(../ST_Ende_Datum)]|ST_Ende_Datum|SYST_Beginn_Datum[not(../SYST_Ende_Datum)]|SYST_Ende_Datum|Untersuchungsdatum_Verlauf)))"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="xsi:Get-FHIR-date">
        <xsl:param name="date"/>
        <xsl:choose>
            <xsl:when test="matches($date, '^\d{2}\.\d{2}\.\d{4}$')">
                <xsl:value-of select="concat(substring($date, 7, 4), '-',
                    if (substring($date, 4, 2) = '00') then '01' else substring($date, 4, 2), '-',
                    if (substring($date, 1, 2) = '00') then '01' else substring($date, 1, 2))"/>
            </xsl:when>
            <xsl:when test="matches($date, '^\d{2}\.\d{4}$')">
                <xsl:value-of select="concat(substring($date, 4, 4), '-',
                    if (substring($date, 1, 2) = '00') then '01' else substring($date, 1, 2), '-01')"/>
            </xsl:when>
            <xsl:when test="matches($date, '^\d{4}$')">
                <xsl:value-of select="concat($date, '-01-01')"/>
            </xsl:when>
        </xsl:choose>
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
            </xsl:when><!-- done official schema mapping; to following mappings still occur for some reason (probably some oBDS migration reason)-->
            <xsl:when test="contains(string-join($toReplace, ','), 'CIZ')">
                <xsl:value-of select="'CIZ'"/>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'CI')">
                <xsl:value-of select="'CI'"/>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'CZ')">
                <xsl:value-of select="'CZ'"/>
            </xsl:when>
            <xsl:when test="contains(string-join($toReplace, ','), 'IZ')">
                <xsl:value-of select="'IZ'"/>
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
                    <xsl:message terminate="yes">
                        ERROR: wrong ECOG <xsl:value-of select="local-name($value)"/> !
                    </xsl:message>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>
    </xsl:function>

    <xsl:function name="xsi:mapToApplicationtype">
        <xsl:param name="applicationtype"/>
        <xsl:variable name="prefix" select="substring($applicationtype, 1, 1)" />
        <xsl:variable name="suffix" select="substring($applicationtype, 2)" />
        <xsl:if test="$prefix = 'P' or $prefix = 'K' or $prefix = 'I' or $prefix = 'M' or $prefix = 'S'">
            <Applikationsart><xsl:value-of select="$prefix"/></Applikationsart>
            <xsl:if test="string-length($applicationtype) > 1">
                <ApplikationsartTyp><xsl:value-of select="$suffix"/></ApplikationsartTyp>
            </xsl:if>
        </xsl:if>
    </xsl:function>

    <xsl:function name="xsi:validVerlaufElement">
        <xsl:param name="element"/>
        <xsl:value-of select="$element!='' and $element!='U' and $element!='X'"/>
    </xsl:function>
</xsl:stylesheet>
