#!/bin/sh

echo "Checking required input and output directories..."
directories="InputData Processed tmp tmp/oBDS_Patients tmp/ADT_Patients tmp/FHIR_Patients tmp/erroneous"
for dir in $directories; do
  if [ -d "/obds2fhir/clinical_data/$dir" ]; then
    echo "$dir exists"
  else
    echo "$dir missing - creating at ./obds2fhir/clinical_data/"
    mkdir /obds2fhir/clinical_data/$dir/
  fi
done
echo -e "\x1b[32m...done\x1b[39m"

java -jar /obds2fhir/obds2fhir.jar
