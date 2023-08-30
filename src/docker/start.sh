#!/usr/bin/env sh

echo "Checking required input and output directories..."
directories="InputADT Processed tmp tmp/ADT_Patients tmp/FHIR_Patients tmp/erroneous"
for dir in $directories; do
  if [ -d "/adt2fhir/clinical_data/$dir" ]; then
    echo "$dir exists"
  else
    echo "$dir missing - creating at ./adt2fhir/clinical_data/"
    mkdir /adt2fhir/clinical_data/$dir/
  fi
done
echo -e "\x1b[32m...done\x1b[39m"

java -jar /adt2fhir/adt2fhir.jar
