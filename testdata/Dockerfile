# Built from the repository root, so the generator runs the obds2fhir of the same commit
FROM maven:3.9.16-eclipse-temurin-21 AS build

WORKDIR /app
COPY pom.xml ./
COPY src ./src
RUN mvn clean install -DskipTests

FROM bellsoft/liberica-openjre-alpine:21
RUN apk add --no-cache python3 py3-lxml
COPY --from=build /app/target/obds2fhir*with-dependencies.jar /obds2fhir/obds2fhir.jar
COPY src/main/resources/*.xsd /app/src/main/resources/
COPY testdata /app/testdata
WORKDIR /app/testdata

# The commit the image is built from, set by CI. It is stored with the data in
# Blaze, and data from another revision is replaced on the next start. Without
# it, as in local builds, data is regenerated on every start.
ARG REVISION=""
ENV REVISION=${REVISION} SALT=testdata PYTHONUNBUFFERED=1
ENTRYPOINT ["python3", "main.py"]
