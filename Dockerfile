ARG OPENJDK_VERSION=8u282-slim
FROM openjdk:${OPENJDK_VERSION}
ADD target/adt2fhir*jar-with-dependencies.jar   /usr/local/bin/adt2fhir.jar
ADD src/docker/adt2fhir.properties              /etc/samply/

ADD src/docker/start.sh                         /adt2fhir/
RUN chmod +x                                    /adt2fhir/start.sh

ENTRYPOINT ["adt2fhir/start.sh"]
RUN echo adt2fhir