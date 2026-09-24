#!/usr/bin/env python3
"""
merge-transcripts TEST -- draait zonder whisper, netwerk of audio.

Toetst de enige plek in home/module/meeting-record waar echte logica zit: het
samenvoegen van twee whisper-SRT's tot één tijdgeordend transcript. De rest van
de module is shell-lijmwerk dat door shellcheck (writeShellApplication) en de
end-to-end-proef gedekt wordt.

    python3 merge_transcripts_test.py
"""

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
MERGE = HERE / "merge-transcripts.py"

ANDEREN_SRT = """1
00:00:01,000 --> 00:00:03,500
Goedemorgen allemaal.

2
00:00:08,250 --> 00:00:10,000
Zullen we beginnen?
"""

IK_SRT = """1
00:00:04,000 --> 00:00:06,000
Goedemorgen, ik hoor je goed.

2
00:00:12,750 --> 00:00:15,000
Ja, prima wat mij betreft.
"""

# Twee regels die over meerdere regels in het SRT-blok staan; whisper doet dat
# bij lange zinnen.
MULTILINE_SRT = """1
00:01:05,000 --> 00:01:09,000
Dit is een lange zin die whisper
over twee regels heeft verdeeld.
"""


def load_module():
    spec = importlib.util.spec_from_file_location("merge_transcripts", MERGE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(name, condition, detail=""):
    status = "OK  " if condition else "FOUT"
    print(f"  [{status}] {name}" + (f" -- {detail}" if detail and not condition else ""))
    return bool(condition)


def test_parse(module):
    print("parse_srt")
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "anderen.srt"
        path.write_text(ANDEREN_SRT, encoding="utf-8")
        entries = module.parse_srt(path, "anderen")
        ok &= check("twee blokken gelezen", len(entries) == 2, f"kreeg {len(entries)}")
        ok &= check("starttijd in seconden", entries[0].start == 1.0, f"kreeg {entries[0].start}")
        ok &= check("eindtijd in seconden", entries[0].end == 3.5, f"kreeg {entries[0].end}")
        ok &= check("label meegegeven", entries[0].label == "anderen")
        ok &= check("tekst overgenomen", entries[0].text == "Goedemorgen allemaal.")

        multi = Path(tmp) / "multi.srt"
        multi.write_text(MULTILINE_SRT, encoding="utf-8")
        entries = module.parse_srt(multi, "ik")
        ok &= check("meerregelig blok wordt één regel", len(entries) == 1, f"kreeg {len(entries)}")
        ok &= check(
            "regels aaneengeplakt",
            entries[0].text == "Dit is een lange zin die whisper over twee regels heeft verdeeld.",
            entries[0].text if entries else "",
        )

        leeg = Path(tmp) / "leeg.srt"
        leeg.write_text("", encoding="utf-8")
        ok &= check("leeg spoor is geen fout", module.parse_srt(leeg, "ik") == [])
    return ok


def test_merge_ordering():
    """Het hele punt van twee sporen: de beurten moeten elkaar afwisselen."""
    print("samenvoegen")
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        (tmpdir / "anderen.srt").write_text(ANDEREN_SRT, encoding="utf-8")
        (tmpdir / "ik.srt").write_text(IK_SRT, encoding="utf-8")
        out = tmpdir / "transcript.txt"

        result = subprocess.run(
            [
                sys.executable,
                str(MERGE),
                "--track", f"ik={tmpdir / 'ik.srt'}",
                "--track", f"anderen={tmpdir / 'anderen.srt'}",
                "--output", str(out),
            ],
            capture_output=True,
            text=True,
        )
        ok &= check("exitcode 0", result.returncode == 0, result.stderr.strip())
        lines = out.read_text(encoding="utf-8").splitlines()
        ok &= check("vier regels", len(lines) == 4, f"kreeg {len(lines)}")

        labels = ["anderen" if "[anderen" in line else "ik" for line in lines]
        ok &= check(
            "sprekers wisselen elkaar af",
            labels == ["anderen", "ik", "anderen", "ik"],
            str(labels),
        )
        ok &= check("op tijd geordend", lines[0].startswith("[00:00:01]"), lines[0] if lines else "")
        ok &= check("laatste regel klopt", lines[-1].startswith("[00:00:12]"), lines[-1] if lines else "")
    return ok


def test_missing_track():
    """Een ontbrekend spoor mag het transcript niet tegenhouden."""
    print("ontbrekend spoor")
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        (tmpdir / "anderen.srt").write_text(ANDEREN_SRT, encoding="utf-8")
        out = tmpdir / "transcript.txt"

        result = subprocess.run(
            [
                sys.executable,
                str(MERGE),
                "--track", f"ik={tmpdir / 'ontbreekt.srt'}",
                "--track", f"anderen={tmpdir / 'anderen.srt'}",
                "--output", str(out),
            ],
            capture_output=True,
            text=True,
        )
        ok &= check("slaagt met één spoor", result.returncode == 0, result.stderr.strip())
        ok &= check("meldt het ontbrekende spoor", "ontbreekt" in result.stderr)
        ok &= check("transcript bevat het andere spoor", len(out.read_text().splitlines()) == 2)

        # Geen enkel spoor: dat is wél een fout.
        result = subprocess.run(
            [
                sys.executable, str(MERGE),
                "--track", f"ik={tmpdir / 'weg.srt'}",
                "--output", str(tmpdir / "leeg.txt"),
            ],
            capture_output=True,
            text=True,
        )
        ok &= check("zonder enig spoor faalt het", result.returncode != 0)
    return ok


# Overspraak: zat je op speakers, dan staat de tegenpartij ook in ik.srt. Whisper
# knipt beide sporen onafhankelijk, dus één blok bij `anderen` komt bij `ik` terug
# als twee halve blokken met net andere woorden -- precies het geval waarop
# SequenceMatcher.ratio() faalt en containment() moet slagen.
ECHO_ANDEREN_SRT = """1
00:00:10,000 --> 00:00:18,000
So there is another role called landing zone DevOps user,
which tech native users and mustard user, they both can assume.

2
00:00:30,000 --> 00:00:32,000
Dat was het wat mij betreft.
"""

ECHO_IK_SRT = """1
00:00:10,500 --> 00:00:14,000
So there is another role called landing zone DevOps user,

2
00:00:14,200 --> 00:00:18,500
which technical users and musterive users, they both can assume.

3
00:00:20,000 --> 00:00:24,000
Wacht even, dat is bij ons nog niet ingeregeld.
"""


def test_drop_echo(module):
    """De kern van het overspraakfilter, los van de CLI."""
    print("overspraakfilter")
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        (tmpdir / "anderen.srt").write_text(ECHO_ANDEREN_SRT, encoding="utf-8")
        (tmpdir / "ik.srt").write_text(ECHO_IK_SRT, encoding="utf-8")
        entries = module.parse_srt(tmpdir / "ik.srt", "ik")
        entries += module.parse_srt(tmpdir / "anderen.srt", "anderen")
        entries.sort(key=lambda entry: entry.start)

        kept, dropped = module.drop_echo(entries, "ik", 3.0, 0.65)
        dropped_text = " | ".join(entry.text for entry in dropped)

        ok &= check("beide helften herkend", len(dropped) == 2, f"kreeg {len(dropped)}: {dropped_text}")
        ok &= check(
            "een half blok telt ook als overspraak",
            any("which technical users" in entry.text for entry in dropped),
            dropped_text,
        )
        ok &= check(
            "eigen inbreng blijft staan",
            any("Wacht even" in entry.text for entry in kept),
            " | ".join(entry.text for entry in kept),
        )
        ok &= check(
            "het andere spoor wordt nooit geschrapt",
            all(entry.label == "ik" for entry in dropped),
            dropped_text,
        )
        ok &= check(
            "anderen blijft compleet",
            len([entry for entry in kept if entry.label == "anderen"]) == 2,
        )

        # Buiten het tijdvenster is dezelfde zin geen overspraak maar een herhaling.
        ver_weg = [
            module.Entry(0.0, 4.0, "anderen", "Precies dezelfde zin als straks."),
            module.Entry(600.0, 604.0, "ik", "Precies dezelfde zin als straks."),
        ]
        kept, dropped = module.drop_echo(ver_weg, "ik", 3.0, 0.65)
        ok &= check("buiten het tijdvenster blijft het staan", dropped == [], str(dropped))

        # Eén spoor kan per definitie niet overspreken.
        alleen = [module.Entry(0.0, 4.0, "ik", "Ik praat in mijn eentje.")]
        kept, dropped = module.drop_echo(alleen, "ik", 3.0, 0.65)
        ok &= check("zonder tweede spoor valt er niets af", dropped == [] and len(kept) == 1)
    return ok


def test_echo_cli():
    """Het filter staat alleen aan als --echo-track meegegeven wordt."""
    print("overspraakfilter via de CLI")
    ok = True
    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        (tmpdir / "anderen.srt").write_text(ECHO_ANDEREN_SRT, encoding="utf-8")
        (tmpdir / "ik.srt").write_text(ECHO_IK_SRT, encoding="utf-8")

        def run(extra):
            out = tmpdir / "transcript.txt"
            result = subprocess.run(
                [
                    sys.executable, str(MERGE),
                    "--track", f"ik={tmpdir / 'ik.srt'}",
                    "--track", f"anderen={tmpdir / 'anderen.srt'}",
                    "--output", str(out),
                ] + extra,
                capture_output=True,
                text=True,
            )
            return result, out.read_text(encoding="utf-8").splitlines()

        result, lines = run([])
        ok &= check("zonder vlag verandert er niets", len(lines) == 5, f"kreeg {len(lines)}")

        result, lines = run(["--echo-track", "ik"])
        ok &= check("exitcode 0", result.returncode == 0, result.stderr.strip())
        ok &= check("met vlag vallen twee regels af", len(lines) == 3, f"kreeg {len(lines)}")
        ok &= check("het aantal wordt gemeld", "2 regels overspraak" in result.stdout, result.stdout.strip())

        # Een drempel van 1.0 eist een exacte match; de halve blokken ontkomen.
        result, lines = run(["--echo-track", "ik", "--echo-threshold", "1.0"])
        ok &= check("drempel 1.0 schrapt alleen exacte overspraak", len(lines) == 4, f"kreeg {len(lines)}")

        # Een spoor dat niet bestaat is geen fout, maar wel een waarschuwing.
        result, lines = run(["--echo-track", "bestaatniet"])
        ok &= check("onbekend spoor faalt niet", result.returncode == 0, result.stderr.strip())
        ok &= check("onbekend spoor waarschuwt", "overgeslagen" in result.stderr, result.stderr.strip())
        ok &= check("onbekend spoor schrapt niets", len(lines) == 5, f"kreeg {len(lines)}")
    return ok


def main() -> int:
    if not MERGE.is_file():
        print(f"merge-transcripts.py niet gevonden naast {__file__}", file=sys.stderr)
        return 1

    module = load_module()
    results = [
        test_parse(module),
        test_merge_ordering(),
        test_missing_track(),
        test_drop_echo(module),
        test_echo_cli(),
    ]

    if all(results):
        print("\nalle tests geslaagd")
        return 0
    print("\nER ZIJN TESTS GEFAALD", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
