# DocuSeal-aanpassingen (onzeovereenkomst.wereldvanbegrip.nl)

`modules/docseal.nix` mount deze bestanden read-only over de views in het gepinde
DocuSeal-image. Ze vervangen het upstream-bestand volledig, dus bij een upgrade blijft
onze oude kopie actief, ook als upstream die view heeft veranderd.

| Pad                                       | Vervangt in image                         |
| ----------------------------------------- | ----------------------------------------- |
| `templates/pages/landing.html.erb`        | `/app/app/views/pages/landing.html.erb`   |
| `templates/shared/_title.html.erb`        | `/app/app/views/shared/_title.html.erb`   |
| `assets/`                                 | `/app/public/custom/`                     |
| `assets/wvb-logo-notxt.png`               | `/app/public/apple-icon-180x180.png`      |

`upstream-2.5.1/` bevat de originele views uit het nu gepinde image (DocuSeal 2.5.1,
digest `a43e629c…`), als basis voor een driewegvergelijking.

## Upgraden

```bash
NEW=docuseal/docuseal:<versie>
for f in pages/landing.html.erb shared/_title.html.erb; do
  mkdir -p upstream-<versie>/$(dirname $f)
  docker run --rm --entrypoint cat $NEW /app/app/views/$f > upstream-<versie>/$f
  diff -u upstream-2.5.1/$f upstream-<versie>/$f   # wat upstream veranderde
done
```

Neem de upstream-wijzigingen over in `templates/`, zet de nieuwe digest in
`modules/docseal.nix`, verwijder de oude `upstream-*`-map en test login, landingspagina
en het ondertekenen van een document.

De loginpagina is bewust niet meer overschreven: die was op een testregel na gelijk aan
upstream (verwijderd 2026-11-11).
