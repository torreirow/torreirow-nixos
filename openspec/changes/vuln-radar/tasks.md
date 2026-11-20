# Tasks

## 1. Inventaris en configuratie

- [x] 1.1 Voeg `modules/vuln-radar.nix` toe met `enable`, `assets` en `extraAssetsFile`; verifieer met `nix eval` dat de opties bestaan en een build met lege assets slaagt.
- [x] 1.2 Definieer het asset-schema (`os`, `release`, `esm`, `dpkg`, `nix`, `upstream`) en schrijf `/etc/vuln-radar/assets.json`; verifieer dat de testassets er correct in staan.
- [x] 1.3 Genereer de inventaris voor alle eigen `nixosConfigurations` (nginx, PHP, kernel, OpenSSL) en geef die aan malandro mee; verifieer dat de JSON vier hosts bevat.
- [x] 1.4 Weiger ontbrekende releases/versies en dubbele packages over bronnen; verifieer dat een ongeldige config met duidelijke fout stopt en een geldige slaagt.
- [x] 1.5 Documenteer het schema en de voorbeeldconfiguratie in `docs/vuln-radar.md`; verifieer dat het voorbeeld letterlijk valide JSON/Nix is.

## 2. Matching-engine

- [x] 2.1 Implementeer dpkg-versievergelijking met `python-debian`; verifieer met tests voor epoch, `~`, `+deb13u` en de trixie-kernel.
- [x] 2.2 Haal de Debian Security Tracker op, cache die en match dpkg-packages per release; verifieer met OpenSSL/MariaDB dat alleen `installed < fixed` een treffer geeft.
- [x] 2.3 Implementeer de Ubuntu CVE/USN-API en de ESM-regel; verifieer met een jammy-nginx-fixture dat een ESM-only fix niet als opgelost telt zonder ESM.
- [x] 2.4 Implementeer NVD- en vendor-matching voor upstream/Nix (PHP-, nginx- en Apache-changelogs); verifieer de testmatrix: nginx 1.30.7 → 0, PHP 8.3.36 → 13, Apache 2.4.67 → ±36.
- [x] 2.5 Neem CISA KEV op als exploitatie-indicator; verifieer dat een KEV-CVE als zodanig verschijnt en niet als severity wordt verward.
- [x] 2.6 Repareer `vulnix-json.service` en lees het JSON-resultaat; verifieer dat de timer een bestand oplevert en dat de matcher zonder vulnix terugvalt op NVD.
- [x] 2.7 Voeg de cache, laatste-verversing en unknown-telling toe; verifieer dat een tweede run de bron niet opnieuw ophaalt en dat onbekend apart blijft.

## 3. Service en UI

- [x] 3.1 Bouw de Python-service die assets en cache laadt en op `127.0.0.1:9101` luistert; verifieer met een lege en een gevulde inventaris.
- [x] 3.2 Render de HTML per systeem/package met alleen toepasselijke CVE's; verifieer de testassets en dat een package zonder treffers als schoon verschijnt.
- [x] 3.3 Voeg `/vulns.json` toe met dezelfde data; verifieer dat de JSON valide is en dezelfde aantallen geeft als de HTML.
- [x] 3.4 Lees FreshRSS read-only voor titel/link/context; verifieer dat de query werkt en dat er geen schrijfactie op de DB plaatsvindt.
- [x] 3.5 Implementeer verouderings- en degradatiemeldingen; verifieer dat een gefaalde bron de pagina niet breekt en dat “nooit ververst” zichtbaar is.
- [x] 3.6 Documenteer de UI, `/vulns.json` en de unknown-telling in `docs/vuln-radar.md`; verifieer dat de beschreven URL's en velden kloppen.

## 4. Hosting en toegang

- [x] 4.1 Voeg de nginx-vhost `vulns.toorren.net` en de Authelia-regel voor groep `monitoring` toe; verifieer dat een anoniem verzoek naar de login gaat en een geauthenticeerd verzoek de pagina toont.
- [x] 4.2 Hardening: dedicated user, `ProtectSystem=strict`, alleen leesrechten op de FreshRSS-DB en geen firewallpoort; verifieer dat de service niet kan schrijven en niet van buiten bereikbaar is.
- [x] 4.3 Werk `PORTS.md` bij met poort 9101 en de vhost; verifieer dat de vermelding overeenkomt met de draaiende configuratie.

## 5. Integratie en oplevering

- [x] 5.1 Deploy op malandro en verifieer de volledige testmatrix: upstream nginx 0 / PHP 12, Debian PHP 0 / Apache ±36 / kernel achter, geen nginx op de Debian-host.
- [x] 5.2 Controleer dat FreshRSS, nginx, Authelia en de bestaande diensten ongewijzigd werken; verifieer met de bestaande healthchecks en een FreshRSS-login.
- [x] 5.3 Voeg een voorbeeldklant toe aan de JSON, valideer het schema en verifieer dat een ontbrekende of ongeldige klantregel de build/service niet stil laat doorgaan.
- [x] 5.4 Werk `CHANGELOG.md` en de `CLAUDE.md`-index bij; verifieer dat beide naar `docs/vuln-radar.md` verwijzen.

## Workflow follow-up

- Archiveer de change nadat de implementatie en de testmatrix zijn goedgekeurd.
- Verifieer na archivering dat de main specs `vuln-radar` bevatten.
