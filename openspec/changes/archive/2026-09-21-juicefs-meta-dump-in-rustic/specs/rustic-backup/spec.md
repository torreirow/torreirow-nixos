## MODIFIED Requirements

### Requirement: JuiceFS-metadata wordt gedekt door de backup

Het systeem SHALL de JuiceFS-metadata van de Nextcloud-opslag op bobadela1 dekken in de dagelijkse
rustic→S3 backup, via twee onafhankelijke representaties: de gerepliceerde metadata-DB
`juicefs_meta_replica` op malandro (via `pg_dumpall`) én een engine-onafhankelijke, `juicefs load`-bare
**plaintext JSON-export**. Omdat bobadela1 tijdens de backup (03:00) is uitgeschakeld, SHALL de
JSON-export NIET live tegen bobadela1 worden gegenereerd; ook SHALL de client-side versleutelde
`--backup-meta`-export uit de object-store NIET rauw worden gekopieerd (dat levert ciphertext, geen
bruikbare JSON). In plaats daarvan SHALL het systeem `juicefs dump` draaien tegen de lokale
`juicefs_meta_replica`-DB (Postgres-metadata is niet versleuteld) en de JSON naar de staging-dir
schrijven zodat die in de snapshot belandt. De backup SHALL NIET de JuiceFS-mount zelf als bron
opnemen (voorkomt S3→S3-recursie).

#### Scenario: Engine-onafhankelijke metadata-dump in de backup
- **WHEN** de dagelijkse backup draait
- **THEN** produceert `juicefs-meta-dump.service` via `juicefs dump` tegen `juicefs_meta_replica` een
  plaintext JSON naar `/var/backup/db/juicefs-meta-dump.json`
- **AND** bevat de rustic-snapshot dat bestand als engine-onafhankelijke (`juicefs load`-bare) export
  met de volledige `FSTree`/`Setting`/`Counters`/`Trash`
- **AND** bevat de export geen S3-secret-key (juicefs scrubt die bij het dumpen)

#### Scenario: Dump faalt zonder de backup te blokkeren
- **WHEN** de replica-DB onbereikbaar of leeg is
- **THEN** faalt alleen `juicefs-meta-dump.service` (met een Signal-melding via `OnFailure=`) en draait
  `rustic-backup.service` alsnog door met de overige bronnen (`Wants=`, geen `Requires=`)

#### Scenario: Gerepliceerde metadata-DB in de cluster-dump
- **WHEN** `pg-dump.service` de PostgreSQL-cluster dumpt
- **THEN** bevat `pg-all.sql.zst` ook de gerepliceerde `juicefs_meta_replica`-database

#### Scenario: Geen S3-naar-S3-recursie
- **WHEN** de backup-bronnen (het manifest) worden geïnspecteerd
- **THEN** staat de JuiceFS-mount NIET in de bronnen, zodat de in S3 opgeslagen JuiceFS-data niet
  nogmaals naar S3 wordt geback-upt
