# Test data generator

Generates synthetic oBDS data, converts it with obds2fhir and loads it into
Blaze, so explorers and other components can be developed against realistic
FHIR data without real patients.

```sh
docker run --rm -e STORE_PATH=http://blaze:8080/fhir ghcr.io/samply/obds2fhir-testdata:main dktk --seed 1
```

- The first argument is the project, a directory here (`dktk/`) that describes
  the shape of that project's data.
- `--seed` makes the data reproducible. Different seeds give different patients,
  e.g. one seed per simulated site.
- Blaze must run with `ENFORCE_REFERENTIAL_INTEGRITY=false`, as in the
  bridgehead, because obds2fhir's bundles reference each other.

The run fails if obds2fhir rejects any file or Blaze holds no patients
afterwards.

## Reruns

A finished run leaves a `Basic/testdata` resource in Blaze naming the project,
seed and the commit the image was built from. A run that finds a matching one
does nothing, so the container can start with every `docker compose up`.
Otherwise it deletes all data written by obds2fhir and loads it again. Images
built locally have no commit and always reload.

## Development

The image builds obds2fhir from this repository, so build it from the root:

```sh
docker build -f testdata/Dockerfile -t obds2fhir-testdata .
```
