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
        ok &= check("starttijd in seconden", entries[0][0] == 1.0, f"kreeg {entries[0][0]}")
        ok &= check("label meegegeven", entries[0][1] == "anderen")
        ok &= check("tekst overgenomen", entries[0][2] == "Goedemorgen allemaal.")

        multi = Path(tmp) / "multi.srt"
        multi.write_text(MULTILINE_SRT, encoding="utf-8")
        entries = module.parse_srt(multi, "ik")
        ok &= check("meerregelig blok wordt één regel", len(entries) == 1, f"kreeg {len(entries)}")
        ok &= check(
            "regels aaneengeplakt",
            entries[0][2] == "Dit is een lange zin die whisper over twee regels heeft verdeeld.",
            entries[0][2] if entries else "",
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


def main() -> int:
    if not MERGE.is_file():
        print(f"merge-transcripts.py niet gevonden naast {__file__}", file=sys.stderr)
        return 1

    module = load_module()
    results = [test_parse(module), test_merge_ordering(), test_missing_track()]

    if all(results):
        print("\nalle tests geslaagd")
        return 0
    print("\nER ZIJN TESTS GEFAALD", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
