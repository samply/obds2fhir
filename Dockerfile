FROM maven:3.9.9-eclipse-temurin-17 AS build

WORKDIR /app
COPY pom.xml ./
COPY src ./src
RUN mvn clean install -U -DskipTests

FROM bellsoft/liberica-openjre-alpine:17
COPY --from=build /app/target/obds2fhir*with-dependencies.jar /obds2fhir/obds2fhir.jar
COPY src/docker/start.sh                        /obds2fhir/
RUN chmod +x                                    /obds2fhir/start.sh
ENTRYPOINT ["obds2fhir/start.sh"]


ENV FILE_PATH="/obds2fhir/clinical_data" \
    STORE_PATH="http://blaze:8090/fhir" \
    STORE_AUTH="" \
    IDENTIFIER_SYSTEM="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS" \
    LOG_LEVEL="INFO" \
    MAINZELLISTE_URL="http://host.docker.internal:8080" \
    MAINZELLISTE_APIKEY="" \
    MAINZELLISTE_EXTERNAL_ID="false" \
    IDTYPE="" \
    SALT="createLocalCustomSalt" \
    SSL_CERTIFICATE_VALIDATION="true" \
    ADD_DEPARTMENTS="false" \
    WAIT_FOR_CONNECTION="false" \
    KEEP_INTERNAL_ID="false" \
    USE_PSEUDONYM="false"