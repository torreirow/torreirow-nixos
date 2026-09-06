## ADDED Requirements

### Requirement: JuiceFS-metadata wordt gedekt door de backup

Het systeem SHALL de JuiceFS-metadata van de Nextcloud-opslag op bobadela1 dekken in de dagelijkse
rustic→S3 backup, via twee onafhankelijke bronnen: een engine-onafhankelijke `juicefs dump`-export
en de gerepliceerde metadata-DB `juicefs_meta_replica` op malandro. De backup SHALL NIET de
JuiceFS-mount zelf als bron opnemen (voorkomt S3→S3-recursie).

#### Scenario: Engine-onafhankelijke metadata-dump in de backup
- **WHEN** de dagelijkse backup draait
- **THEN** bevat de snapshot een recente `juicefs dump`-export (JSON) van de JuiceFS-metadata

#### Scenario: Gerepliceerde metadata-DB in de cluster-dump
- **WHEN** `pg-dump.service` de PostgreSQL-cluster dumpt
- **THEN** bevat `pg-all.sql.zst` ook de gerepliceerde `juicefs_meta_replica`-database

#### Scenario: Geen S3-naar-S3-recursie
- **WHEN** de backup-bronnen (het manifest) worden geïnspecteerd
- **THEN** staat de JuiceFS-mount NIET in de bronnen, zodat de in S3 opgeslagen JuiceFS-data niet nogmaals naar S3 wordt geback-upt
