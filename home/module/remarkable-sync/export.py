#!/usr/bin/env python3
"""Exporteer de documenten van een via USB aangesloten reMarkable naar PDF.

Praat met de USB-webinterface van xochitl (poort 80):

  GET /documents/                  -> JSON-lijst met ID/VisibleName/Parent/Type/
                                      fileType/ModifiedClient
  GET /download/<ID>/placeholder   -> de PDF, door het apparaat zelf gerenderd
                                      (inclusief de handgeschreven inkt)

Drie dingen zijn hier geen detail maar ontwerpeisen -- zie design.md:

* **Nooit een verzoek afbreken.** Een afgekapte download laat de QtWebApp-
  threadpool in xochitl hangen: daarna geeft *elk* verzoek 408 tot het apparaat
  herstart. Downloads gaan daarom strikt sequentieel en met een ruime timeout.
* **Alleen gewijzigde documenten opnieuw ophalen.** `ModifiedClient` wordt in een
  state-bestand bijgehouden. Zonder dat herschrijft elke run alle PDF's en
  upload nextcloudcmd het hele archief elke tien minuten opnieuw.
* **Afwezigheid is normaal.** Slaapt het apparaat of ligt de kabel eruit, dan
  stopt het script zonder fout (exit 0).
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

# Ruim bemeten: het apparaat rendert een groot document merkbaar langzamer dan
# het over de lijn stuurt. Liever wachten dan afbreken.
DOWNLOAD_TIMEOUT = "300"
LISTING_TIMEOUT = 20


def log(msg):
    print(f"remarkable-export: {msg}", file=sys.stderr)


def fetch_listing(host):
    """Haal de documentenlijst op. Geeft None als het apparaat er niet is."""
    url = f"http://{host}/documents/"
    try:
        with urllib.request.urlopen(url, timeout=LISTING_TIMEOUT) as r:
            if r.status != 200:
                log(f"listing gaf HTTP {r.status}")
                return None
            return json.loads(r.read().decode("utf-8"))
    except (urllib.error.URLError, OSError, json.JSONDecodeError) as e:
        log(f"listing niet beschikbaar: {e}")
        return None


def sanitize(name, doc_id):
    """Maak van een VisibleName een veilig padonderdeel.

    VisibleName is vrije gebruikerstekst en komt rechtstreeks in een pad
    terecht: schuine strepen zouden een mapniveau toevoegen, een leidende punt
    maakt het bestand verborgen, en een lege naam levert geen pad op.
    """
    name = name.replace("\0", "").replace("/", "_").strip()
    name = re.sub(r"\s+", " ", name)
    if name in ("", ".", ".."):
        return doc_id
    if name.startswith("."):
        name = "_" + name[1:]
    return name[:120]


def build_paths(items):
    """Reconstrueer de mappenboom uit de Parent-verwijzingen.

    Op schijf is alles plat en UUID-genoemd; de boom bestaat uitsluitend als
    Parent-pointers. Mappen zijn items met Type == "CollectionType" en hebben
    geen download-endpoint.

    Botsingen: krijgen twee documenten in dezelfde map dezelfde gesaneerde naam,
    dan krijgt *elk* lid van die groep een UUID-achtervoegsel. Zo verandert het
    pad van bestaande documenten niet wanneer er later een derde gelijknamige
    bijkomt.
    """
    by_id = {i["ID"]: i for i in items}
    folders = {i["ID"] for i in items if i.get("Type") == "CollectionType"}

    def folder_path(fid, seen=None):
        if not fid or fid not in by_id:
            return []
        seen = seen or set()
        if fid in seen:  # kringverwijzing: niet verder aflopen
            return []
        seen.add(fid)
        item = by_id[fid]
        return folder_path(item.get("Parent", ""), seen) + [
            sanitize(item.get("VisibleName", ""), fid)
        ]

    docs = [i for i in items if i["ID"] not in folders]

    # Tel per (map, naam) hoe vaak hij voorkomt, zodat we botsingen herkennen.
    counts = {}
    for d in docs:
        key = (d.get("Parent", ""), sanitize(d.get("VisibleName", ""), d["ID"]))
        counts[key] = counts.get(key, 0) + 1

    out = {}
    for d in docs:
        parent = d.get("Parent", "")
        base = sanitize(d.get("VisibleName", ""), d["ID"])
        if counts[(parent, base)] > 1:
            base = f"{base}-{d['ID'][:8]}"
        out[d["ID"]] = os.path.join(*(folder_path(parent) + [base + ".pdf"]))
    return out


def load_state(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        # Ontbrekend of kapot state-bestand: alles opnieuw exporteren.
        return {}


def save_state(path, state):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, sort_keys=True)
    os.replace(tmp, path)


def download(host, doc_id, dest):
    """Haal n document op. Schrijft atomisch: pas hernoemen als het klopt."""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(dest), suffix=".part")
    os.close(fd)
    url = f"http://{host}/download/{doc_id}/placeholder"
    try:
        res = subprocess.run(
            ["curl", "--silent", "--show-error", "--fail",
             "--max-time", DOWNLOAD_TIMEOUT, "--output", tmp, url],
            capture_output=True, text=True, check=False,
        )
        if res.returncode != 0:
            log(f"download mislukt ({doc_id}): {res.stderr.strip()}")
            return False
        with open(tmp, "rb") as f:
            if f.read(5) != b"%PDF-":
                log(f"geen PDF terug voor {doc_id}")
                return False
        os.replace(tmp, dest)
        return True
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def prune(docroot, keep):
    """Verwijder PDF's die niet meer op het apparaat staan, plus lege mappen.

    De map is een spiegel van het apparaat, geen prullenbak.
    """
    keep = {os.path.normpath(os.path.join(docroot, p)) for p in keep}
    for root, _dirs, files in os.walk(docroot, topdown=False):
        for name in files:
            full = os.path.join(root, name)
            if name.endswith(".pdf") and full not in keep:
                log(f"verwijderd (niet meer op het apparaat): {name}")
                os.unlink(full)
        if root != docroot and not os.listdir(root):
            os.rmdir(root)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--target", required=True, help="map voor de PDF's")
    ap.add_argument("--state", required=True, help="pad naar exported.json")
    args = ap.parse_args()

    items = fetch_listing(args.host)
    if items is None:
        # Apparaat slaapt of is losgekoppeld: dat is normaal, geen fout.
        return 0

    paths = build_paths(items)
    state = load_state(args.state)
    new_state = {}
    downloaded = skipped = failed = 0

    for item in items:
        doc_id = item["ID"]
        if doc_id not in paths:  # map, geen document
            continue
        rel = paths[doc_id]
        dest = os.path.join(args.target, rel)
        modified = item.get("ModifiedClient", "")
        previous = state.get(doc_id, {})

        unchanged = (
            previous.get("modified") == modified
            and previous.get("path") == rel
            and os.path.exists(dest)
        )
        if unchanged:
            skipped += 1
            new_state[doc_id] = previous
            continue

        if download(args.host, doc_id, dest):
            downloaded += 1
            new_state[doc_id] = {"modified": modified, "path": rel}
        else:
            failed += 1
            # Niets in de state schrijven: volgende run probeert opnieuw.

    prune(args.target, paths.values())
    save_state(args.state, new_state)
    log(f"{downloaded} gedownload, {skipped} ongewijzigd, {failed} mislukt")
    return 0


if __name__ == "__main__":
    sys.exit(main())
