# oBDS2FHIR / ADT2FHIR

oBDS2FHIR (also called ADT2FHIR) is a tool to transform files exported by German tumor documentation systems into FHIR bundles for use in the [Bridgehead](https://github.com/samply/bridgehead) (or other FHIR-based software).

The transformation is performed using two XSLT files:
- **[oBDS2MDS.xsl](https://github.com/samply/obds2fhir/blob/main/src/main/resources/oBDS2MDS_FHIR.xsl)** (maps oBDS to a research-oriented Meldedatensatz structure)
- **[MDS2FHIR.xsl](https://github.com/samply/obds2fhir/blob/main/src/main/resources/MDS2FHIR.xsl)** (converts MDS into interoperable FHIR resources)

This software was originally created for the [German Cancer Consortium's Clinical Communication Platform](https://dktk.dkfz.de/) and has since been made open source.

## Two names, one software

**ADT2FHIR** was originally developed in 2020 to integrate the ADT/GEKID dataset, which was hence renamed to Onkologischer Basisdatensatz ([oBDS](https://www.basisdatensatz.de/basisdatensatz)). Thus, ADT2FHIR is now also known as **oBDS2FHIR** (terms are used synonymously).

---

## Usage

oBDS2FHIR converts oBDS-compliant data into FHIR bundles. To use it:
1. Place your oBDS XML files in the input directory:  
   ```/clinical_data/Input_oBDS/```
2. Optionally:
    - Pseudonymize patient identifiers (e.g., with [Mainzelliste](https://bitbucket.org/medicalinformatics/mainzelliste))
    - Import transformed data into a FHIR server (e.g., [Blaze](https://github.com/samply/blaze))

### Docker

oBDS2FHIR is designed for use with docker compose. To run, put the oBDS xml files in ```/clinical_data/Input_oBDS/``` and run:
```sh
docker compose up
```

You need at least docker-compose version `1.29.2`.
The configuration is set in the [`docker-compose.yml`](./docker-compose.yml) file and is preconfigured with sane defaults (you probably won't need to set **#commented** parameters).


### Configuration:

Set the environment variables either directly in Java oder via docker compose (start with the default values from the Dockerfile):

#### Basic Configuration

##### FHIR 

* ```IDENTIFIER_SYSTEM``` defines the system of the FHIR identifiers.
  You can use the default value or set your own system URL.

* ```SALT``` defines a random additional input for the hashing applied in generating the FHIR ids from oBDS. **Please do change this**

* ```KEEP_INTERNAL_ID``` If *true*, then no hash is applied to the FHIR Patient id, otherwise a has is applied. Defaults to *false*.

* ```USE_PSEUDONYM``` If *true*, then the pseudonym of the Patient (= FHIR identifier) is applied to the FHIR Patient id, otherwise the Patient_ID is used. Defaults to *false*.
This can be combined with *KEEP_INTERNAL_ID*

##### BLAZE
* ```STORE_PATH``` defines the URL of the FHIR server API.
  You can use the default value, when using the default BLAZE server (https://github.com/samply/blaze).

* ```STORE_AUTH``` sets the FHIR server authentication. *Leave it empty if there is no authentication.*

##### MAINZELLISTE

* ```MAINZELLISTE_URL``` for pseudonymization in the transformation step; sets the URL of the pseudonymization service. *Leave it empty if there is no pseudonymization.*

* ```MAINZELLISTE_APIKEY``` sets the pseudonymization service authentication. *Leave it empty if there is no pseudonymization.*

* ```IDTYPE``` sets the pseudonym type. *Leave it empty if there is no pseudonymization.*



#### Advanced Options (Optional)

* ```FILE_PATH``` defines the directory of the clinical oBDS data in the docker container.
There souldn't be a reason to change this for docker.


* ```SSL_CERTIFICATE_VALIDATION``` can be set to false **IF** your FHIR server is only accessible via https and you do **NOT** have a valid SSL certificate. Not recommended!

* ```ADD_DEPARTMENTS``` can be set to true if you want to add the departments that commited the patient report (=oBDS Melder). *Probably not  necessary*.

* ```PATIENT_ID_PLAINTEXT``` can be set to true if you want oBDS (or ADT) @Patient_ID as identifier.

###### Properties:

Some configurations are set during runtime (due to [oBDS2FHIR-REST](https://github.com/samply/obds2fhir-rest/)) directly as Java system properties. You can define them in your docker-compose.yml like this:

```yaml
command: [
  "-Dkeep.internal.id=false",         # Keep cleartext Patient/@Patient_ID as FHIR Patient.id (default: false)
  "-Duse.pseudonym=false",            # Use pseudonym as Patient.id instead of Patient/@Patient_ID (default: false)
  "-Dmainzelliste.external.id=true"   # Provide Patient/@Patient_ID as locallyUniqueId to Mainzelliste (default: true)
]
```
E.g. if you want to generate the same Patient.id based on the pseudonym for tumor documentation and sample data in separate imports.

###### Volumes:

* ```./clinical_data:/obds2fhir/clinical_data``` You can use the default value, which then mounts the host ```clinical_data``` directory to the docker container.

* ```/etc/bridgehead/traefik-tls:/.../:ro``` If you use https, please set the correct certificate path here (should work out of the box for use with Bridgeheads).

###### Network - extra_hosts:
* ``"host.docker.internal:host-gateway"`` If you run oBDS2FHIR in an additional docker-compose file on the same host and don't manage the docker network yourself, then use this configuration to enable access to other services (FHIR server; pseudonymization service).


## Notes

    Assumes: Patient, Sample, Diagnose always have an Id, other Ids are optional.
    
    -_Lokal_DKTK_ID_Pat_System_ needs to conform to https://www.hl7.org/fhir/datatypes.html#uri

You should modify the identifier system (replace http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS with
a local URL). You can just make one up (or use the default), but note that this URL will be used as ```Identifier.system```
in the resulting FHIR Patient resources (```Identifer.value``` will either be (a) a hash based on patient master data or, if pseudonymization 
is configured, (b) be replaced by a Mainzelliste-generated pseudonym).

Since ids are required in FHIR but optional in the oBDS XML schema, they are generated via content hashing
if not present. However, it is recommended to provide all optional ids in the imported oBDS XML files.
Additionally, ```Patient_ID```, ```Diagnosis_ID``` and ```Sample_ID``` are required. 
