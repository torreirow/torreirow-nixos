#!/usr/bin/env python3
"""Voeg whisper-SRT's van meerdere sporen samen tot één tijdgeordend transcript.

Elk spoor is een aparte opname van één spreker (zie home/module/meeting-record):
`ik.srt` is de eigen microfoon, `anderen.srt` de inkomende audio. Omdat de sporen
gescheiden zijn opgenomen, komt de sprekerscheiding uit de bestandsindeling en is
er geen diarisatiemodel nodig.

De sporen lopen ~11 ms uit elkaar (gemeten, constante offset zonder drift), wat
ver onder de resolutie van een transcript ligt en dus genegeerd wordt.

Zat je op speakers, dan heeft je microfoon de tegenpartij meegenomen en staan hun
zinnen óók in `ik.srt`. `--echo-track` gooit die eruit; zie `drop_echo`.
"""

import argparse
import difflib
import re
import sys
from pathlib import Path
from typing import NamedTuple

TIMESTAMP = re.compile(
    r"(\d+):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d+):(\d{2}):(\d{2})[,.](\d{3})"
)

# Alles wat geen woordteken of witruimte is valt weg voordat er vergeleken wordt:
# whisper zet op het ene spoor een komma waar het op het andere een punt zet.
NON_WORD = re.compile(r"[^\w\s]", re.UNICODE)


class Entry(NamedTuple):
    start: float
    end: float
    label: str
    text: str


def to_seconds(hours, minutes, seconds, millis):
    return int(hours) * 3600 + int(minutes) * 60 + int(seconds) + int(millis) / 1000


def parse_srt(path, label):
    """Lees een SRT en geef een Entry per blok terug.

    Whisper schrijft nette SRT, maar een leeg spoor levert een leeg bestand op --
    dat is geen fout, dat is een deelnemer die niets gezegd heeft.
    """
    entries = []
    start = None
    end = None
    lines = []

    def flush():
        if start is not None and lines:
            text = " ".join(part.strip() for part in lines if part.strip())
            if text:
                entries.append(Entry(start, end, label, text))

    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        match = TIMESTAMP.search(line)
        if match:
            flush()
            start = to_seconds(*match.groups()[:4])
            end = to_seconds(*match.groups()[4:])
            lines = []
            continue
        if not line:
            flush()
            start = None
            end = None
            lines = []
            continue
        if start is not None and not line.isdigit():
            lines.append(line)

    flush()
    return entries


def normalize(text):
    """Woordenlijst om op te vergelijken: kleine letters, geen leestekens."""
    return NON_WORD.sub(" ", text.casefold()).split()


def containment(needle, haystack):
    """Welk deel van `needle` komt in `haystack` terug, als fractie 0..1.

    Bewust géén SequenceMatcher.ratio(): die deelt door de som van beide lengtes,
    dus een korte zin die volledig in een lange zit scoort laag. En dat is nu net
    het normale geval -- whisper knipt de twee sporen onafhankelijk van elkaar, dus
    één blok op het ene spoor staat als twee halve blokken op het andere.

    autojunk=False, anders schrapt difflib bij lange reeksen juist de veelgebruikte
    woorden als "ruis" en dat zijn hier de woorden die ertoe doen.
    """
    if not needle:
        return 0.0
    matcher = difflib.SequenceMatcher(None, needle, haystack, autojunk=False)
    matched = sum(block.size for block in matcher.get_matching_blocks())
    return matched / len(needle)


def drop_echo(entries, echo_label, window, threshold):
    """Haal uit spoor `echo_label` weg wat overgesproken is vanaf een ander spoor.

    Meeting-apps spelen je eigen microfoon niet terug, dus overspraak gaat maar één
    kant op: de anderen komen via je speakers je microfoon in, nooit andersom. Er
    wordt daarom alleen uit `echo_label` geschrapt.

    Een regel valt af als hij (a) in de tijd overlapt met wat het andere spoor zegt
    -- met `window` seconden speling, want de knippunten liggen niet gelijk -- en
    (b) grotendeels uit dezelfde woorden bestaat.

    Dit blijft een heuristiek: "ja" of "oké" tegelijk met de ander zeggen ziet er
    identiek uit als overspraak, en verdwijnt dus mee. De losse .srt-bestanden
    blijven ongemoeid, dus het origineel is er altijd nog.
    """
    others = [entry for entry in entries if entry.label != echo_label]
    kept = []
    dropped = []

    for entry in entries:
        if entry.label != echo_label:
            kept.append(entry)
            continue

        overlapping = []
        for other in others:
            if other.start - window <= entry.end and other.end + window >= entry.start:
                overlapping.extend(normalize(other.text))

        score = containment(normalize(entry.text), overlapping)
        if score >= threshold:
            dropped.append(entry)
        else:
            kept.append(entry)

    return kept, dropped


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
    parser.add_argument(
        "--echo-track",
        metavar="LABEL",
        help="schrap uit dit spoor wat van een ander spoor is overgesproken",
    )
    parser.add_argument(
        "--echo-window",
        type=float,
        default=3.0,
        metavar="SEC",
        help="speling op de overlap in de tijd (standaard 3.0)",
    )
    parser.add_argument(
        "--echo-threshold",
        type=float,
        default=0.65,
        metavar="FRACTIE",
        help="vanaf welke woordovereenkomst een regel als overspraak telt (standaard 0.65)",
    )
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

    entries.sort(key=lambda entry: entry.start)

    note = ""
    if args.echo_track:
        labels = {entry.label for entry in entries}
        if args.echo_track not in labels:
            print(
                f"merge-transcripts: spoor {args.echo_track!r} niet aanwezig, "
                "overspraakfilter overgeslagen",
                file=sys.stderr,
            )
        elif len(labels) < 2:
            print(
                "merge-transcripts: maar één spoor, overspraakfilter overgeslagen",
                file=sys.stderr,
            )
        else:
            entries, dropped = drop_echo(
                entries, args.echo_track, args.echo_window, args.echo_threshold
            )
            note = f", {len(dropped)} regels overspraak uit {args.echo_track} geschrapt"

    width = max((len(entry.label) for entry in entries), default=0)
    out = Path(args.output)
    with out.open("w", encoding="utf-8") as handle:
        for entry in entries:
            handle.write(
                f"[{format_timestamp(entry.start)}] "
                f"[{entry.label:<{width}}] {entry.text}\n"
            )

    print(f"merge-transcripts: {out} geschreven uit {', '.join(used)}{note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
