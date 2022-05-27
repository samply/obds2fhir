#!/usr/bin/env bash


export FILES_TO_PARSE="/etc/samply/adt2fhir.properties"

set -e

for file in $FILES_TO_PARSE
do
sed -i "s|{file_path}|${FILE_PATH:-/adt2fhir/clinical_data}|"                                                         $file
sed -i "s|{store_path}|${STORE_PATH:-http://host.docker.internal:8090/fhir}|"                                         $file
sed -i "s|{identifier_system}|${IDENTIFIER_SYSTEM:-http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS}|"    $file
sed -i "s|{mainzelliste_url}|${MAINZELLISTE_URL:-http://host.docker.internal:8080}|"                                  $file
sed -i "s|{mainzelliste_apikey}|${MAINZELLISTE_APIKEY}|"                                                              $file
done

if [ -d "/clinical_data/InputADT" ]; then
	echo "Found import dir"
	#else echo "Error - can not find dir: create dir /clinical_data/InputADT/"
	#exit
fi

if [ -d "/clinical_data/FHIR_Patients" ]; then
	echo "Found output dir"
	#else echo "Error - can not find dir: create dir /clinical_data/FHIR_Patients/"
	#exit
fi

java -jar /usr/local/bin/adt2fhir.jar