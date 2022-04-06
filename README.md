# adt2fhir

Using the two XSLT files (/src/main/resources/ADT2MDS_FHIR.xsl and /src/main/resources/MDS2FHIR.xsl), XML Files 
conforming to ADT/GEKID (/src/main/resources/ ADT_GEKID_v2.1.*x*-dktk_v1.0.0.xsd ) can be transformed into FHIR 
resources conforming to [de.dktk.oncology 1.0.4](https://simplifier.net/packages/de.dktk.oncology/1.0.4).


##Usage

The main method transforms ADT/GEKID conform data into FHIR bundles and posts them to a FHIR server (```store_path``` in ```adt2fhir.properties```).
Therefore, put your ADT/GEKID data in the input directory ```/clincial_data/Input_Patients```. 
Additionally, you need an accessible FHIR server running (e.g. see https://github.com/samply/blaze)

You can run the transformation using Docker, Java or manually.


###Docker

To run ADT2FHIR, put the ADT/GEKID xml files in ```/clinical_data/Input_ADT/``` and run:
```sh
docker-compose pull
docker-compose up
```
#####Docker - Notes:

Set the configuration in ```/src/docker/adt2fhir.properties```:

```file_path``` defines the directory of the clinical data on the docker host.
You can use the default value, which then mounts the ```clinical_data``` directory to docker.

```store_path``` defines the BLAZE FHIR server import URL.
You can use the default value, when using the default BLAZE server (https://github.com/samply/blaze).

```identifier_system``` defines the system of the FHIR identifiers.
You can use the default value or set your own system URL.


###Java

To run ADT2FHIR, put the ADT/GEKID xml files in ```/clinical_data/Input_ADT/``` and run:

```sh
mvn clean install
```
The file **adt2fhir-** *version-number* **-jar-with-dependencies.jar** is then generated in your target folder and can be used via:


```sh
java -jar adt2fhir-*version-number*-jar-with-dependencies.jar
```
#####Java - Notes:
Set the configuration in ```/src/main/resources/adt2fhir.properties```:

see **Docker - Notes**

###Manual - deprecated:

For a manual transformation check out the branch **main_original**. 

First apply ADT2MDS_FHIR.xsl to your ADT.xml data, then MDS2FHIR.xsl to the results of the first transformation.
You can download the Saxon XSL processor [here](http://saxon.sourceforge.net/#F10HE) (Java Version). Unpack and find the JAR called saxon-he-[version].jar
Call the JAR from the command line: ´java -jar path/to/jar/saxon-he-[version].jar -s:sorceFile.xml -xsl:tranformationFile.xsl`. Additional documentation can be found [here](https://www.saxonica.com/documentation/index.html#!using-xsl/commandline).

## Notes

    Assumes: Patient, Sample, Diagnose always have an Id, other Ids are optional.
    
    -_Lokal_DKTK_ID_Pat_System_ needs to conform to https://www.hl7.org/fhir/datatypes.html#uri

You should modify the identifier system (replace http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS with
a local URL). You can just make one up (or use the default), but note that this URL will be used as Identifier.system
in the resulting FHIR Patient resources (Identifer.value will be a **hash** based on patient master data - will
be replaced by Mainzelliste pseudonymization).

Since ids are required in FHIR but optional in the ADT/GEKID XML schema, they are generated via content hashing
if not present. However, it is recommended to provide all optinal ids in the importet ADT/GEKID XML files.
Additionally, ```Patient_ID```, ```Diagnosis_ID``` and ```Sample_ID``` are required. 