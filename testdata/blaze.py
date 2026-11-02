import json
import time
import urllib.error
import urllib.request
from concurrent.futures import Future, ThreadPoolExecutor
from typing import Any
from urllib.parse import urlsplit

MARKER = "Basic/testdata"
MARKER_SYSTEM = "https://github.com/samply/obds2fhir"


def request(method: str, url: str, body: Any = None) -> Any:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/fhir+json")
    if data:
        req.add_header("Content-Type", "application/fhir+json")
    with urllib.request.urlopen(req, timeout=600) as response:
        payload = response.read()
        return json.loads(payload) if payload else None


def wait(base: str) -> None:
    for _ in range(120):
        try:
            request("GET", f"{base}/metadata?_summary=true")
            return
        except (urllib.error.URLError, ConnectionError):
            time.sleep(2)
    raise SystemExit(f"Blaze at {base} did not come up")


def marker(base: str) -> str | None:
    try:
        resource = request("GET", f"{base}/{MARKER}")
    except urllib.error.HTTPError as e:
        if e.code in (404, 410):
            return None
        raise
    code: str = resource["code"]["coding"][0]["code"]
    return code


def write_marker(base: str, fingerprint: str) -> None:
    request(
        "PUT",
        f"{base}/{MARKER}",
        {
            "resourceType": "Basic",
            "id": "testdata",
            "code": {
                "coding": [{"system": MARKER_SYSTEM, "code": fingerprint}],
            },
        },
    )


def count(base: str, resource_type: str) -> int:
    total: int = request("GET", f"{base}/{resource_type}?_summary=count")["total"]
    return total


# Everything obds2fhir writes, plus the marker
TYPES = [
    "AdverseEvent",
    "Basic",
    "CarePlan",
    "ClinicalImpression",
    "Condition",
    "Encounter",
    "MedicationStatement",
    "Observation",
    "Patient",
    "Procedure",
    "Specimen",
]


def clear(base: str) -> None:
    # Pages come from a snapshot in Blaze, so deleting while paging is fine
    with ThreadPoolExecutor(8) as executor:
        deletions: list[Future[None]] = []
        for resource_type in TYPES:
            url: str | None = f"{base}/{resource_type}?_count=1000&_elements=id"
            while url:
                page = request("GET", url)
                ids = [entry["resource"]["id"] for entry in page.get("entry", [])]
                if ids:
                    deletions.append(executor.submit(delete, base, resource_type, ids))
                url = next_page(base, page)
        for deletion in deletions:
            deletion.result()


def next_page(base: str, page: Any) -> str | None:
    for link in page.get("link", []):
        if link["relation"] == "next":
            # Blaze links to its own BASE_URL, which may not be how we reach it
            url: str = link["url"]
            host = urlsplit(base)
            return urlsplit(url)._replace(scheme=host.scheme, netloc=host.netloc).geturl()
    return None


def delete(base: str, resource_type: str, ids: list[str]) -> None:
    entries = [{"request": {"method": "DELETE", "url": f"{resource_type}/{id}"}} for id in ids]
    request("POST", base, {"resourceType": "Bundle", "type": "batch", "entry": entries})
