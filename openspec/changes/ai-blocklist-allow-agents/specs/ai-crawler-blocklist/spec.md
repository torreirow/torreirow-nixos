# Spec Delta

## Purpose

AI-crawlers weren van de publieke statische sites op malandro (403 in nginx plus een aanvulling op
de bestaande `robots.txt`), zonder gewone zoekmachines en gewenste link-preview-bots te raken.

## ADDED Requirements

### Requirement: Per site toegestane bots krijgen geen 403
Een site in `services.aiBlocklist.sites` SHALL een lijst `allowAgents` met botnamen kunnen opgeven.
Een verzoek waarvan de user-agent (hoofdletterongevoelig, als heel woord) een van die namen bevat,
MUST op die site niet met 403 geweigerd worden door de AI-blokkade. Standaard is de lijst leeg.

#### Scenario: Toegestane bot op cckafe.com
- **WHEN** `cckafe.com` `allowAgents = [ "facebookexternalhit" ]` heeft en een verzoek met
  user-agent `facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)` binnenkomt
  op `https://cckafe.com/`
- **THEN** antwoordt de site met 200 en de gewone pagina

#### Scenario: Hoofdletters maken niet uit
- **WHEN** dezelfde site een verzoek krijgt met user-agent `FacebookExternalHit/1.1`
- **THEN** antwoordt de site met 200

### Requirement: Uitzondering geldt alleen voor de eigen site
Een bot in de `allowAgents` van één site MUST op alle andere sites onder de blokkade de 403 blijven
krijgen, en andere AI-bots MUST op de site met de uitzondering de 403 blijven krijgen.

#### Scenario: Andere site blijft blokkeren
- **WHEN** alleen `cckafe.com` `facebookexternalhit` toestaat en een verzoek met user-agent
  `facebookexternalhit/1.1` binnenkomt op `https://toorren.net/`
- **THEN** antwoordt toorren.net met 403

#### Scenario: Andere AI-bot op dezelfde site blijft geblokkeerd
- **WHEN** een verzoek met user-agent `GPTBot/1.2` binnenkomt op `https://cckafe.com/`
- **THEN** antwoordt cckafe.com met 403

### Requirement: Toegestane bots ontbreken in de Disallow-groep van robots.txt
De gegenereerde `robots.txt` van een site MUST geen door de blokkade toegevoegde `User-agent`-regel
bevatten voor een bot uit de `allowAgents` van die site. Regels die al in de `robots.txt` van de
webroot staan, MUST ongewijzigd blijven.

#### Scenario: robots.txt van cckafe.com
- **WHEN** `https://cckafe.com/robots.txt` wordt opgehaald
- **THEN** bevat het bestand geen `User-agent: facebookexternalhit` en wel de overige AI-bots met
  `Disallow: /`

#### Scenario: robots.txt van een andere site
- **WHEN** `https://toorren.net/robots.txt` wordt opgehaald
- **THEN** bevat het bestand `User-agent: facebookexternalhit` in de Disallow-groep
