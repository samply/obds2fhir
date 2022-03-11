#!/usr/bin/env bash

if [ -d "/clinical_data/InputADT" ]; then
	echo "Found import folder"
	else echo "create folder /clinical_data/InputADT/"
	exit
fi

if [ -d "/clinical_data/FHIR_Patients" ]; then
	echo "Found output folder"
	else echo "create folder /clinical_data/FHIR_Patients/"
	exit
fi

java -jar /usr/local/bin/adt2fhir.jar