from pathlib import Path

from lxml import etree

NS = "http://www.basisdatensatz.de/oBDS/XML"


def E(tag: str, *children: etree._Element | str | None, **attrs: str) -> etree._Element:
    """Builds an oBDS element. Strings become text, None children are skipped."""
    element = etree.Element(f"{{{NS}}}{tag}", nsmap={None: NS})
    for key, value in attrs.items():
        element.set(key, value)
    for child in children:
        if child is None:
            continue
        if isinstance(child, etree._Element):
            element.append(child)
        else:
            element.text = child
    return element


def document(patients: list[etree._Element]) -> etree._Element:
    return E(
        "oBDS",
        E(
            "Absender",
            E("Bezeichnung", "Testdaten"),
            Absender_ID="1",
            Software_ID="obds2fhir-testdata",
            Software_Version="1",
            Installations_ID="1",
        ),
        E("Meldedatum", "2025-07-01"),
        E("Menge_Patient", *patients),
        E("Menge_Melder", E("Melder", E("Arztname", "Testdaten"), ID="1")),
        Schema_Version="3.0.2",
    )


def write(path: Path, patients: list[etree._Element], schema: etree.XMLSchema) -> None:
    doc = document(patients)
    schema.assertValid(doc)
    etree.ElementTree(doc).write(path, xml_declaration=True, encoding="UTF-8")


def schema(xsd_path: Path) -> etree.XMLSchema:
    return etree.XMLSchema(etree.parse(xsd_path))
