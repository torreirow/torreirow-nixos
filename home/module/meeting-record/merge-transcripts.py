#!/usr/bin/env python3
"""Voeg whisper-SRT's van meerdere sporen samen tot één tijdgeordend transcript.

Elk spoor is een aparte opname van één spreker (zie home/module/meeting-record):
`ik.srt` is de eigen microfoon, `anderen.srt` de inkomende audio. Omdat de sporen
gescheiden zijn opgenomen, komt de sprekerscheiding uit de bestandsindeling en is
er geen diarisatiemodel nodig.

De sporen lopen ~11 ms uit elkaar (gemeten, constante offset zonder drift), wat
ver onder de resolutie van een transcript ligt en dus genegeerd wordt.
"""

import argparse
import re
import sys
from pathlib import Path

TIMESTAMP = re.compile(
    r"(\d+):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d+):(\d{2}):(\d{2})[,.](\d{3})"
)


def to_seconds(hours, minutes, seconds, millis):
    return int(hours) * 3600 + int(minutes) * 60 + int(seconds) + int(millis) / 1000


def parse_srt(path, label):
    """Lees een SRT en geef (start, label, tekst) per blok terug.

    Whisper schrijft nette SRT, maar een leeg spoor levert een leeg bestand op --
    dat is geen fout, dat is een deelnemer die niets gezegd heeft.
    """
    entries = []
    start = None
    lines = []

    def flush():
        if start is not None and lines:
            text = " ".join(part.strip() for part in lines if part.strip())
            if text:
                entries.append((start, label, text))

    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        match = TIMESTAMP.search(line)
        if match:
            flush()
            start = to_seconds(*match.groups()[:4])
            lines = []
            continue
        if not line:
            flush()
            start = None
            lines = []
            continue
        if start is not None and not line.isdigit():
            lines.append(line)

    flush()
    return entries


def format_timestamp(seconds):
    total = int(seconds)
    return f"{total // 3600:02d}:{(total % 3600) // 60:02d}:{total % 60:02d}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--track",
        action="append",
        default=[],
        metavar="LABEL=PAD",
        help="spoor om mee te nemen, bv. ik=/pad/ik.srt (herhaalbaar)",
    )
    parser.add_argument("--output", required=True, help="pad van het samengevoegde transcript")
    args = parser.parse_args()

    entries = []
    used = []
    for spec in args.track:
        if "=" not in spec:
            parser.error(f"--track verwacht LABEL=PAD, kreeg {spec!r}")
        label, _, raw_path = spec.partition("=")
        path = Path(raw_path)
        if not path.is_file():
            print(f"merge-transcripts: {path} ontbreekt, spoor overgeslagen", file=sys.stderr)
            continue
        found = parse_srt(path, label)
        entries.extend(found)
        used.append(f"{label} ({len(found)} regels)")

    if not used:
        print("merge-transcripts: geen enkel spoor gevonden", file=sys.stderr)
        return 1

    entries.sort(key=lambda item: item[0])

    width = max((len(label) for _, label, _ in entries), default=0)
    out = Path(args.output)
    with out.open("w", encoding="utf-8") as handle:
        for start, label, text in entries:
            handle.write(f"[{format_timestamp(start)}] [{label:<{width}}] {text}\n")

    print(f"merge-transcripts: {out} geschreven uit {', '.join(used)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
