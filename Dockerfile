ARG OPENJDK_VERSION=17-jre-alpine
FROM eclipse-temurin:${OPENJDK_VERSION}
ADD target/adt2fhir*jar-with-dependencies.jar   /usr/local/bin/adt2fhir.jar
ADD src/docker/adt2fhir.properties              /etc/samply/

ADD src/docker/start.sh                         /adt2fhir/
RUN chmod +x                                    /adt2fhir/start.sh
#RUN	apt-get update && apt-get install -y curl iputils-ping wget
ENTRYPOINT ["adt2fhir/start.sh"]
RUN echo adt2fhir