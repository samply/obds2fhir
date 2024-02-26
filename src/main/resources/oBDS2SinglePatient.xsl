<?xml version="1.0" encoding="utf-8" standalone="no"?>
<xsl:stylesheet 
    xmlns="http://www.basisdatensatz.de/oBDS/XML"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:hash="java:de.samply.obds2fhir"
    exclude-result-prefixes="#default" 
    version="2.0"
    xpath-default-namespace="http://www.basisdatensatz.de/oBDS/XML">
    
    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    <xsl:output omit-xml-declaration="no" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <xsl:param name="filepath" />
    <xsl:param name="customPrefix" />

    <xsl:template match="/oBDS">
        <xsl:for-each select="Menge_Patient/Patient">
            <xsl:result-document method="xml" href="file:{$filepath}/tmp/oBDS_Patients/Patient_{hash:hash(Patienten_Stammdaten/@Patient_ID,'','')}_{$customPrefix}.xml">
            <oBDS Schema_Version="3.0.2">
                <xsl:copy-of select="/oBDS/@*" />
                    <Menge_Patient>
                        <xsl:copy-of select="../@* | ." />
                    </Menge_Patient>
                    <Menge_Melder>
                        <xsl:copy-of select="/oBDS/Menge_Melder/Melder"/>
                    </Menge_Melder>
                </oBDS>
                </xsl:result-document>
        </xsl:for-each>
    </xsl:template> 
    
</xsl:stylesheet>
