"""Generates oBDS test data for a project, converts it with obds2fhir and
loads it into Blaze, unless Blaze already holds exactly this data."""

import argparse
import os
import shutil
import subprocess
import time
from pathlib import Path

import blaze
import dktk

FILE_PATH = Path("/tmp/clinical_data")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", choices=["dktk"])
    parser.add_argument("--seed", type=int, required=True)
    args = parser.parse_args()

    store = os.environ["STORE_PATH"].rstrip("/")
    revision = os.environ.get("REVISION", "")
    fingerprint = f"{args.project} seed={args.seed} revision={revision}"

    blaze.wait(store)
    if revision and blaze.marker(store) == fingerprint:
        print(f"Blaze already holds {fingerprint}")
        return
    print("Clearing Blaze")
    blaze.clear(store)

    start = time.monotonic()
    shutil.rmtree(FILE_PATH, ignore_errors=True)
    input_dir = FILE_PATH / "InputData"
    input_dir.mkdir(parents=True)
    match args.project:
        case "dktk":
            dktk.generate(args.seed, input_dir)
    print(f"Generated in {time.monotonic() - start:.0f}s")

    start = time.monotonic()
    convert(store)
    print(f"Converted and loaded in {time.monotonic() - start:.0f}s")

    erroneous = list((FILE_PATH / "tmp/erroneous").iterdir())
    if erroneous:
        raise SystemExit(f"obds2fhir failed on {len(erroneous)} files")
    if not blaze.count(store, "Patient"):
        raise SystemExit("Blaze holds no patients")

    blaze.write_marker(store, fingerprint)
    print(f"Loaded {fingerprint}")


def convert(store: str) -> None:
    for directory in [
        "Processed",
        "tmp/oBDS_Patients",
        "tmp/ADT_Patients",
        "tmp/FHIR_Patients",
        "tmp/erroneous",
    ]:
        (FILE_PATH / directory).mkdir(parents=True, exist_ok=True)
    env = os.environ | {"FILE_PATH": str(FILE_PATH), "STORE_PATH": store}
    subprocess.run(["java", "-jar", "/obds2fhir/obds2fhir.jar"], env=env, check=True)


if __name__ == "__main__":
    main()
