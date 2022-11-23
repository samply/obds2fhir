#!/usr/bin/env sh

export FILES_TO_PARSE="/etc/samply/adt2fhir.properties"

set -e

for file in $FILES_TO_PARSE; do
  sed -i "s|{file_path}|${FILE_PATH:-/adt2fhir/clinical_data}|" $file
  sed -i "s|{store_path}|${STORE_PATH:-http://host.docker.internal:8090/fhir}|" $file
  sed -i "s|{store_auth}|${STORE_AUTH}|" $file
  sed -i "s|{identifier_system}|${IDENTIFIER_SYSTEM:-http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS}|" $file
  sed -i "s|{mainzelliste_url}|${MAINZELLISTE_URL:-http://host.docker.internal:8080}|" $file
  sed -i "s|{mainzelliste_apikey}|${MAINZELLISTE_APIKEY}|" $file
  sed -i "s|{idtype}|${IDTYPE}|" $file
  sed -i "s|{ssl_certificate_validation}|${SSL_CERTIFICATE_VALIDATION:-true}|" $file
done

echo "Checking required input and output directories..."
directories="InputADT ADT_Patients FHIR_Patients Processed"
for dir in $directories; do
  if [ -d "/adt2fhir/clinical_data/$dir" ]; then
    echo "$dir exists"
  else
    echo "$dir missing - creating at ./adt2fhir/clinical_data/"
    mkdir /adt2fhir/clinical_data/$dir/
  fi
done
echo -e "\x1b[32m...done\x1b[39m"

java -jar /usr/local/bin/adt2fhir.jar
