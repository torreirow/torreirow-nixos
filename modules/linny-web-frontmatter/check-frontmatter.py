#!/usr/bin/env python3
"""Toetst de frontmatter van een Linny-notitieboek op de canonieke termvorm.

    check-frontmatter.py [corpus-map]        # standaard: de huidige map

Meldt drie soorten afwijkingen en sluit dan af met exitcode 1:

  * een taxonomie-term die niet canoniek is;
  * een notitie zonder het verplichte veld `customer`;
  * een notitie zonder frontmatter -- die belandt NIET in de index en is
    daardoor onzichtbaar voor de agent, ook al bestaat het bestand.

Leest alleen. Schrijft nooit, en is bewust géén voorwaarde voor de bouw van de
site: een notitieboek met een schoonheidsfoutje hoort gewoon gepubliceerd te
worden. Zie openspec/specs/linny-frontmatter-guard.
"""

from __future__ import annotations

import fnmatch
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# DE CANONIEKE REGEL IS NIET VAN ONS.
#
# Hij komt uit linny-mcp, dat elke term normaliseert vóór het indexeren:
#
#     strings.ReplaceAll(strings.ToLower(term), " ", "-")
#
# Daarom is wat je schrijft niet per se wat je terugkrijgt. Wijkt upstream ooit
# af, dan is dit de regel die mee moet -- en dan is het een gerichte wijziging
# in plaats van een zoektocht.
# ---------------------------------------------------------------------------
def normalise(term: str) -> str:
    return term.lower().replace(" ", "-")


# Velden die een taxonomie-term bevatten. `tag` en `tags` staan er allebei in
# omdat beide in het corpus voorkomen.
TAXONOMY_FIELDS = ("customer", "doctype", "type", "project", "tag", "tags", "owner")

REQUIRED_FIELD = "customer"

# Bestanden zonder eigen taxonomie. `_index.md` zijn sectie-indexpagina's,
# `search.md` is Hugo's zoekpagina (`type: "search"`).
#
# De uitzondering geldt UITSLUITEND voor het verplichte veld, niet voor de
# termvorm: staat er tóch een taxonomie-term in, dan moet die canoniek zijn.
# Anders zou de uitzondering een gat zijn in plaats van een verfijning.
EXEMPT_FROM_REQUIRED = ("**/_index.md", "content/search.md")

FRONT_MATTER = re.compile(r"\A---\n(.*?)\n---\s*(?:\n|\Z)", re.S)


def is_exempt(relpath: str, patterns=EXEMPT_FROM_REQUIRED) -> bool:
    """Bewust eigen matching in plaats van fnmatch op het hele pad: daar matcht
    `*` ook een `/`, en dan zou `**/_index.md` per ongeluk veel meer vangen."""
    for pattern in patterns:
        if pattern.startswith("**/"):
            if fnmatch.fnmatch(Path(relpath).name, pattern[3:]):
                return True
        elif fnmatch.fnmatch(relpath, pattern):
            return True
    return False


def unquote(value: str) -> str:
    """Alleen de omsluitende quotes weghalen."""
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def semantic(raw: str) -> str:
    """De waarde zoals een YAML-lezer hem ziet: zonder quotes, zonder rand-witruimte."""
    return unquote(raw.strip()).strip()


def has_edge_space(raw: str) -> bool:
    """Rand-witruimte op een scalar is een afwijking op zichzelf.

    Een YAML-lezer strijkt hem weg, dus de betekenis verandert niet -- maar de
    bron wordt er onnauwkeurig van, en je ziet het nergens terug. Gemeten in het
    echte corpus: één `customer: torreirow ` met een spatie erachter, die geen
    enkele controle opmerkte omdat iedereen hem stilzwijgend wegstreek.

    LET OP: geldt alleen voor scalars en block-lijstelementen. In een inline
    lijst (`[a, b]`) is de witruimte rond een element structureel en geen
    onderdeel van de waarde, dus daar is het géén afwijking.
    """
    return raw != raw.strip()


def parse_fields(block: str) -> dict[str, list[tuple[str, bool]]]:
    """Frontmatter ontleden zonder YAML-bibliotheek.

    Bewust met de hand: dit script moet juist óók werken op een corpus waarvan
    de frontmatter stuk is -- dat is een van de gevallen die het moet melden.
    Een YAML-parser werpt daar een uitzondering, en dan gaat het onderscheid
    tussen "geen frontmatter" en "kapotte frontmatter" verloren.

    De prijs is dat we lijstwaarden zelf moeten herkennen, in allebei de vormen:

        tags: [frontmatter, refactor]        inline
        tags:                                block
          - frontmatter
          - refactor

    Elk element telt afzonderlijk. Een lijst als één term behandelen is precies
    de fout die dit script moet vermijden.
    """
    found: dict[str, list[tuple[str, bool]]] = {}
    lines = block.split("\n")
    index = 0
    while index < len(lines):
        line = lines[index]
        index += 1
        match = re.match(r"^([A-Za-z_][\w-]*)\s*:\s*(.*)$", line)
        if not match:
            continue
        key, raw_rest = match.group(1).lower(), match.group(2)
        rest = raw_rest.strip()
        if key not in TAXONOMY_FIELDS:
            continue

        if rest.startswith("[") and rest.endswith("]"):
            # Inline lijst: witruimte rond een element is structureel.
            values = [(semantic(v), False) for v in rest[1:-1].split(",")]
        elif rest:
            values = [(semantic(rest), has_edge_space(raw_rest))]
        else:
            # Blokvorm: de ingesprongen `- `-regels die hierop volgen.
            values = []
            while index < len(lines):
                item = re.match(r"^\s+-\s+(.*)$", lines[index])
                if not item:
                    break
                raw = item.group(1)
                values.append((semantic(raw), has_edge_space(raw)))
                index += 1

        values = [(v, sp) for v, sp in values if v]
        if values:
            found.setdefault(key, []).extend(values)
    return found


def check_file(path: Path, relpath: str) -> list[str]:
    findings: list[str] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    match = FRONT_MATTER.match(text)

    if not match:
        findings.append(
            f"{relpath}: geen frontmatter -- deze notitie komt NIET in de index "
            f"en is dus onvindbaar voor de agent"
        )
        return findings

    fields = parse_fields(match.group(1))

    if REQUIRED_FIELD not in fields and not is_exempt(relpath):
        findings.append(f"{relpath}: geen {REQUIRED_FIELD}")

    for key in sorted(fields):
        for value, edge_space in fields[key]:
            canonical = normalise(value)
            if value != canonical:
                findings.append(f"{relpath}: {key}: {value!r} -> {canonical!r}")
            elif edge_space:
                findings.append(
                    f"{relpath}: {key}: {value!r} met witruimte eromheen -- "
                    f"weghalen, anders staat er in de bron iets anders dan in de index"
                )
    return findings


def check_corpus(root: Path) -> list[str]:
    content = root / "content"
    base = content if content.is_dir() else root
    findings: list[str] = []
    for path in sorted(base.rglob("*.md")):
        findings.extend(check_file(path, str(path.relative_to(root))))
    return findings


def main(argv: list[str]) -> int:
    root = Path(argv[1] if len(argv) > 1 else ".").resolve()
    if not root.is_dir():
        print(f"check-frontmatter: {root} is geen map", file=sys.stderr)
        return 2

    findings = check_corpus(root)
    for line in findings:
        print(line)
    if findings:
        print(f"\n{len(findings)} afwijking(en)")
        return 1
    print("frontmatter is canoniek; geen afwijkingen")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
