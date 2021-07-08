ARG OPENJDK_VERSION=8u282-slim
FROM openjdk:${OPENJDK_VERSION}
ADD target/adt2fhir*.jar /usr/local/bin/adt2fhir.jar
ENTRYPOINT ["java", "-jar", "/usr/local/bin/adt2fhir.jar"]