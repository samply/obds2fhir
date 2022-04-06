#!/usr/bin/env bash

if [ -d "/clinical_data/InputADT" ]; then
	echo "Found import dir"
	else echo "Error - can not find dir: create dir /clinical_data/InputADT/"
	#exit
fi

if [ -d "/clinical_data/FHIR_Patients" ]; then
	echo "Found output dir"
	else echo "Error - can not find dir: create dir /clinical_data/FHIR_Patients/"
	#exit
fi

java -jar /usr/local/bin/adt2fhir.jar