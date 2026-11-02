import json
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlsplit

MARKER = "Basic/testdata"
MARKER_SYSTEM = "https://github.com/samply/obds2fhir"


def request(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/fhir+json")
    if data:
        req.add_header("Content-Type", "application/fhir+json")
    with urllib.request.urlopen(req, timeout=600) as response:
        payload = response.read()
        return json.loads(payload) if payload else None


def wait(base):
    for _ in range(120):
        try:
            request("GET", f"{base}/metadata?_summary=true")
            return
        except (urllib.error.URLError, ConnectionError):
            time.sleep(2)
    raise SystemExit(f"Blaze at {base} did not come up")


def marker(base):
    try:
        resource = request("GET", f"{base}/{MARKER}")
    except urllib.error.HTTPError as e:
        if e.code in (404, 410):
            return None
        raise
    return resource["code"]["coding"][0]["code"]


def write_marker(base, fingerprint):
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


def count(base, resource_type):
    return request("GET", f"{base}/{resource_type}?_summary=count")["total"]


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


def clear(base):
    # Pages come from a snapshot in Blaze, so deleting while paging is fine
    with ThreadPoolExecutor(8) as executor:
        deletions = []
        for resource_type in TYPES:
            url = f"{base}/{resource_type}?_count=1000&_elements=id"
            while url:
                page = request("GET", url)
                ids = [entry["resource"]["id"] for entry in page.get("entry", [])]
                if ids:
                    deletions.append(executor.submit(delete, base, resource_type, ids))
                url = next_page(base, page)
        for deletion in deletions:
            deletion.result()


def next_page(base, page):
    for link in page.get("link", []):
        if link["relation"] == "next":
            # Blaze links to its own BASE_URL, which may not be how we reach it
            host = urlsplit(base)
            return urlsplit(link["url"])._replace(scheme=host.scheme, netloc=host.netloc).geturl()
    return None


def delete(base, resource_type, ids):
    entries = [{"request": {"method": "DELETE", "url": f"{resource_type}/{id}"}} for id in ids]
    request("POST", base, {"resourceType": "Bundle", "type": "batch", "entry": entries})
