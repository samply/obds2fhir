"""The shape of DKTK tumor documentation."""

import random
from datetime import date, timedelta
from pathlib import Path

import obds
from obds import E

XSD = Path(__file__).parents[2] / "src/main/resources/oBDS_v3.0.2-dktk_v1.0.0.xsd"

# Ages and dates are relative to this, not to today, so data doesn't drift
REFERENCE_DATE = date(2025, 7, 1)

# ICD-10 code, sexes it occurs in, weight, ICD-O-3 morphologies
DIAGNOSES = [
    ("C50.4", "W", 14, ["8500/3", "8520/3"]),
    ("C50.9", "W", 6, ["8500/3"]),
    ("C61", "M", 13, ["8140/3"]),
    ("C34.1", "MW", 7, ["8140/3", "8070/3"]),
    ("C34.3", "MW", 4, ["8070/3", "8041/3"]),
    ("C18.7", "MW", 5, ["8140/3"]),
    ("C20", "MW", 4, ["8140/3"]),
    ("C43.5", "MW", 5, ["8721/3", "8743/3"]),
    ("C25.0", "MW", 3, ["8500/3"]),
    ("C64", "MW", 3, ["8312/3"]),
    ("C67.9", "MW", 3, ["8120/3"]),
    ("C71.1", "MW", 2, ["9440/3"]),
    ("C16.0", "MW", 2, ["8140/3", "8490/3"]),
    ("C56", "W", 2, ["8441/3"]),
    ("C92.0", "MW", 2, ["9861/3"]),
]

SAMPLE_TYPES = {
    "tissue-ffpe": 10,
    "tissue-frozen": 4,
    "blood-plasma": 5,
    "blood-serum": 3,
    "whole-blood": 3,
    "buffy-coat": 1,
    "dna": 2,
    "rna": 1,
    "urine": 1,
}


PATIENTS_PER_FILE = 100


def generate(seed, directory):
    """Writes oBDS files for one seed into directory."""
    schema = obds.schema(XSD)
    count = round(1000 * random.Random(seed).uniform(0.9, 1.1))
    for start in range(0, count, PATIENTS_PER_FILE):
        indexes = range(start, min(start + PATIENTS_PER_FILE, count))
        patients = [patient(random.Random(f"{seed}-{index}"), f"{seed}-{index}") for index in indexes]
        obds.write(directory / f"{start // PATIENTS_PER_FILE:05}.xml", patients, schema)


def patient(rng, patient_id):
    sex = rng.choices("MWDU", weights=[480, 500, 2, 18])[0]
    age_at_diagnosis = min(max(round(rng.gauss(64, 13)), 18), 95)
    diagnosed = REFERENCE_DATE - timedelta(days=rng.randint(30, 20 * 365))
    born = diagnosed - timedelta(days=age_at_diagnosis * 365 + rng.randint(0, 364))

    candidates = [d for d in DIAGNOSES if sex in d[1]] or DIAGNOSES
    icd, _, _, morphologies = rng.choices(candidates, weights=[d[2] for d in candidates])[0]
    tumor_id = "1"

    reports = [diagnosis(rng, tumor_id, icd, rng.choice(morphologies), diagnosed)]
    if rng.random() < 0.6:
        reports.append(samples(rng, tumor_id, icd, diagnosed))
    death_risk = 0.35 + (age_at_diagnosis - 64) / 100
    if rng.random() < death_risk:
        died = diagnosed + timedelta(days=rng.randint(30, 6 * 365))
        if died < REFERENCE_DATE:
            reports.append(death(rng, tumor_id, icd, diagnosed, died))

    for number, report in enumerate(reports):
        report.set("Meldung_ID", f"{patient_id}-{number}")

    return E(
        "Patient",
        E(
            "Patienten_Stammdaten",
            E("Versichertendaten_Sonstige"),
            E("Nachname", "Test"),
            E("Vornamen", "Test"),
            E("Geschlecht", sex),
            E("Geburtsdatum", born.isoformat(), Datumsgenauigkeit="E"),
            E("Adresse", E("Land", "DE")),
        ),
        E("Menge_Meldung", *reports),
        Patient_ID=patient_id,
    )


def report(tumor_id, icd, diagnosed, content, morphology=None):
    return E(
        "Meldung",
        E("Meldebegruendung", "I"),
        E("Eigene_Leistung", "J"),
        E(
            "Tumorzuordnung",
            E("Primaertumor_ICD", E("Code", icd), E("Version", "10 2024 GM")),
            E("Diagnosedatum", diagnosed.isoformat(), Datumsgenauigkeit="E"),
            morphology and E("Morphologie_ICD_O", E("Code", morphology), E("Version", "33")),
            Tumor_ID=tumor_id,
        ),
        content,
        Melder_ID="1",
    )


def diagnosis(rng, tumor_id, icd, morphology, diagnosed):
    tnm = None
    if not icd.startswith(("C71", "C92")):
        tnm = E(
            "cTNM",
            E("Datum", diagnosed.isoformat()),
            E("Version", "8"),
            E("T", rng.choices(["1", "2", "3", "4"], weights=[35, 35, 20, 10])[0]),
            E("N", rng.choices(["0", "1", "2"], weights=[60, 30, 10])[0]),
            E("M", rng.choices(["0", "1"], weights=[80, 20])[0]),
        )
    return report(
        tumor_id,
        icd,
        diagnosed,
        E(
            "Diagnose",
            E("Primaertumor_Topographie_ICD_O", E("Code", topography(icd)), E("Version", "33")),
            E("Diagnosesicherung", "7"),
            tnm,
            E("Allgemeiner_Leistungszustand", rng.choices("01234U", weights=[40, 30, 12, 6, 2, 10])[0]),
        ),
        morphology,
    )


def samples(rng, tumor_id, icd, diagnosed):
    kinds = rng.choices(list(SAMPLE_TYPES), weights=SAMPLE_TYPES.values(), k=rng.randint(1, 4))
    return report(
        tumor_id,
        icd,
        diagnosed,
        E(
            "Samples",
            *[
                E(
                    "Sample",
                    E("Status", "available"),
                    E("Sampletype", kind),
                    E("Collectiontime", (diagnosed + timedelta(days=rng.randint(0, 60))).isoformat()),
                    Sample_ID=f"{tumor_id}-{number}",
                )
                for number, kind in enumerate(kinds)
            ],
        ),
    )


def death(rng, tumor_id, icd, diagnosed, died):
    return report(
        tumor_id,
        icd,
        diagnosed,
        E(
            "Tod",
            E("Sterbedatum", died.isoformat()),
            E("Tod_tumorbedingt", rng.choices("JN", weights=[80, 20])[0]),
        ),
    )


def topography(icd):
    """ICD-O topography always has a subcode, e.g. C61 becomes C61.9."""
    return icd if "." in icd else f"{icd}.9"
