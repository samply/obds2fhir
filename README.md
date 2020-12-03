# adt2fhir

Using the two XSLT files, XML Files conforming to ADT/GEKID can be transformed into FHIR resources conforming to [de.dktk.oncology 1.0.4](https://simplifier.net/packages/de.dktk.oncology/1.0.4).
First apply ADT2MDS_FHIR to your ADT data, then MDS_FHIR2FHIR to the results of the first transformation.

**IMPORTANT**
You should modify line 6 in the MDS_FHIT2FHIR file (```<xsl:variable name="Lokal_DKTK_ID_Pat_System">http://fhir.example.org/LokaleTumorPatientenIds</xsl:variable>```, replace http://fhir.example.org/LokaleTumorPatientenIds
with a local URL. You can just make one up, but note that this URL will be used as Identifer.system in the resulting FHIR Patient resoures (Identifer.value will be the local ID from your ADT file, the value of *Patienten_Stammdaten/@Patient_ID*).
Also note that NO pseudonymization or anonymization takes place. If you need to e.g. pseudonymize the IDs, you should do so either by preprocessing the ADT or processing the FHIR resources before loading them into your local FHIR store. Note that the Patient id is also used als the technical (resource) id , not just in the identifer.
So if working with the FHIR resources, you also need to replace this id and update all references to the Patient.

Since not all entities in the XML schema have ids, some are generated by the XSLT processor. These will stay constant if the same file is transformed multiple times using the same processing engine, but may change if the structure
changes or another processor is used. Therefore, if you plan to load updates into your FHIR store, be carefull that all entities you plan to update have Ids explicitly set in the ADT (e.g. Patient_ID).

## Settings
    - _Lokal_DKTK_ID_Pat_System_ needs to conform to https://www.hl7.org/fhir/datatypes.html#uri
	
## Notes

Assumes: Patient, Sample, Diagnose alwaays have an Id, other Ids are optional.