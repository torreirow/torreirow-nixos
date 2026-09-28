#!/usr/bin/env python3
"""Tests voor check-frontmatter.py. Draait zonder corpus en zonder netwerk.

    python3 modules/linny-web-frontmatter/check_frontmatter_test.py

Elke test bouwt zijn eigen notitieboek in een tijdelijke map, zodat de tests
niets weten van de inhoud van het echte (privé) notitieboek.
"""

import importlib.util
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESULTS = []


def check(name, condition, detail=""):
    RESULTS.append(bool(condition))
    print(f"  [{'OK  ' if condition else 'FOUT'}] {name}" + (f" -- {detail}" if not condition else ""))


def load():
    spec = importlib.util.spec_from_file_location("cfm", HERE / "check-frontmatter.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def corpus(files: dict[str, str]) -> Path:
    root = Path(tempfile.mkdtemp())
    for rel, text in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return root


def fm(**fields) -> str:
    body = "\n".join(f"{k}: {v}" for k, v in fields.items())
    return f"---\n{body}\n---\n\ntekst\n"


def test_scalars(m):
    print("scalars")
    root = corpus({"content/a.md": fm(customer="Acme"), "content/b.md": fm(customer="acme corp")})
    out = m.check_corpus(root)
    check("hoofdletter wordt gemeld", any("'Acme' -> 'acme'" in f for f in out), str(out))
    check("spatie wordt gemeld", any("'acme corp' -> 'acme-corp'" in f for f in out), str(out))
    shutil.rmtree(root)


def test_inline_lijst(m):
    """Dit is het defect in het script uit de bean: dat las de hele lijst als
    één string en meldde 'frontmatter,-refactor' als variant."""
    print("inline lijst")
    root = corpus({"content/a.md": fm(customer="acme", tags="[frontmatter, refactor]")})
    out = m.check_corpus(root)
    check("geldige inline lijst levert GEEN melding", out == [], str(out))
    shutil.rmtree(root)

    root = corpus({"content/a.md": fm(customer="acme", tags="[frontmatter, Grote Klus]")})
    out = m.check_corpus(root)
    check("alleen het afwijkende element wordt gemeld", len(out) == 1, str(out))
    check("en met de canonieke vorm erbij",
          out and "'Grote Klus' -> 'grote-klus'" in out[0], str(out))
    shutil.rmtree(root)


def test_block_lijst(m):
    print("block lijst")
    root = corpus({"content/a.md": "---\ncustomer: acme\ntags:\n  - frontmatter\n  - Refactor\n---\n\nx\n"})
    out = m.check_corpus(root)
    check("één afwijkend element in een blocklijst", len(out) == 1, str(out))
    check("het goede element wordt niet gemeld",
          out and "Refactor" in out[0] and "frontmatter'" not in out[0], str(out))
    shutil.rmtree(root)


def test_geen_frontmatter(m):
    print("geen frontmatter")
    root = corpus({"content/a.md": "zomaar tekst\n"})
    out = m.check_corpus(root)
    check("wordt gemeld", len(out) == 1, str(out))
    check("met uitleg dat hij niet in de index komt",
          out and "NIET in de index" in out[0], str(out))
    shutil.rmtree(root)


def test_uitzonderingen(m):
    print("uitzonderingen")
    root = corpus({
        "content/_index.md": fm(title="sectie"),
        "content/a/_index.md": fm(title="dieper"),
        "content/search.md": fm(title="zoeken", type='"search"'),
    })
    out = m.check_corpus(root)
    check("_index.md zonder customer wordt NIET gemeld", out == [], str(out))
    shutil.rmtree(root)

    # De uitzondering geldt alleen voor het verplichte veld, niet voor de term.
    root = corpus({"content/_index.md": fm(title="sectie", project="Grote Klus")})
    out = m.check_corpus(root)
    check("maar een afwijkende term erin wél", len(out) == 1, str(out))
    shutil.rmtree(root)


def test_schoon(m):
    print("schoon corpus")
    root = corpus({"content/a.md": fm(customer="acme", project="dakkapel")})
    out = m.check_corpus(root)
    check("geen afwijkingen", out == [], str(out))
    check("main geeft exitcode 0", m.main(["x", str(root)]) == 0)
    shutil.rmtree(root)


def test_leest_alleen(m):
    """Een controle die zijn eigen invoer verandert is geen controle."""
    print("wijzigt niets")
    root = corpus({"content/a.md": fm(customer="Acme"), "content/b.md": "geen fm\n"})
    before = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in sorted(root.rglob("*.md"))}
    m.check_corpus(root)
    after = {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in sorted(root.rglob("*.md"))}
    check("inhoud en mtimes ongewijzigd", before == after)
    check("geen bestand bijgekomen of verdwenen", set(before) == set(after))
    shutil.rmtree(root)


def main():
    m = load()
    for test in (test_scalars, test_inline_lijst, test_block_lijst, test_geen_frontmatter,
                 test_uitzonderingen, test_schoon, test_leest_alleen):
        test(m)
    print()
    if all(RESULTS):
        print(f"alle {len(RESULTS)} tests geslaagd")
        return 0
    print(f"{RESULTS.count(False)} van de {len(RESULTS)} tests gefaald")
    return 1


if __name__ == "__main__":
    sys.exit(main())
