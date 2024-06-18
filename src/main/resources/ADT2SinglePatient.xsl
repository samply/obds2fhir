<?xml version="1.0" encoding="utf-8" standalone="no"?>
<xsl:stylesheet 
    xmlns="http://www.gekid.de/namespace"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:hash="java:de.samply.obds2fhir"
    exclude-result-prefixes="#default" 
    version="2.0"
    xpath-default-namespace="http://www.gekid.de/namespace">
    
    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    <xsl:output omit-xml-declaration="no" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:param name="filepath" />
    <xsl:param name="customPrefix" />

    <xsl:template match="/ADT_GEKID">
        <xsl:for-each select="Menge_Patient/Patient">
            <xsl:result-document method="xml" href="file:{$filepath}/tmp/ADT_Patients/Patient_{hash:hash(Patienten_Stammdaten/@Patient_ID,'','')}_ADT_{$customPrefix}.xml">
            <!--<xsl:result-document method="xml" href="Patient_{Patienten_Stammdaten/@Patient_ID}.xml">-->
                <ADT_GEKID Schema_Version="2.2.3">
                    <xsl:copy-of select="/ADT_GEKID/@*" />
                    <Menge_Patient>
                        <xsl:copy-of select="../@* | ." />
                    </Menge_Patient>
                    <Menge_Melder>
                        <xsl:copy-of select="/ADT_GEKID/Menge_Melder/Melder"/>
                    </Menge_Melder>
                </ADT_GEKID>
                </xsl:result-document>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
