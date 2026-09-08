# juicefs-nextcloud-storage Specification

## Purpose
Levert de Nextcloud AIO-datadir op bobadela1 als een POSIX-veilige, S3-backed JuiceFS-filesystem
met lokale PostgreSQL-metadata en een gerepliceerde DR-kopie op malandro, inclusief een gedekt
herstelpad voor zowel de metadata- als de datalaag.
## Requirements
### Requirement: POSIX-veilige S3-opslag onder de Nextcloud-datadir

Het systeem SHALL de Nextcloud AIO-datadir aanbieden via een JuiceFS-mount die volledige POSIX-semantiek
(atomic rename, `flock`/POSIX-locking, symlinks, close-to-open consistency) garandeert, met de
bestandsdata opgeslagen in AWS S3. Het systeem SHALL GEEN naïeve FUSE-over-S3-mount
(s3fs/mountpoint-s3/goofys) gebruiken voor de datadir.

#### Scenario: Atomic rename werkt op de mount
- **WHEN** een proces een bestand op de JuiceFS-mount hernoemt via `rename(2)`
- **THEN** is de rename atomair en zichtbaar zonder tussenliggende halve staat

#### Scenario: File-locking wordt gehonoreerd
- **WHEN** twee processen tegelijk een `flock`/POSIX-lock op hetzelfde bestand aanvragen
- **THEN** krijgt slechts één proces de lock en wacht de ander

#### Scenario: Geen FUSE-over-S3 voor de datadir
- **WHEN** de mount onder de Nextcloud-datadir wordt geïnspecteerd
- **THEN** is het een JuiceFS-mount en NIET een s3fs/mountpoint-s3/goofys-mount

### Requirement: Datalaag op eigen S3-prefix met gescoopte IAM-credentials

Het systeem SHALL de JuiceFS-objecten opslaan in `s3://wto-s3-bucket` onder een eigen prefix
`juicefs/`, gescheiden van de rustic-backup-prefix `rustic-backup/malandro`. Het systeem SHALL
daarvoor een aparte IAM-user/policy gebruiken die uitsluitend `s3:GetObject`, `s3:PutObject`,
`s3:DeleteObject` en `s3:ListBucket` op de `juicefs/`-prefix toestaat, en NIET de rustic-IAM-user
(`hasio`) hergebruiken.

#### Scenario: Objecten op eigen prefix
- **WHEN** JuiceFS data naar S3 schrijft
- **THEN** verschijnen de objecten onder `juicefs/` en niet onder `rustic-backup/malandro`

#### Scenario: Credentials komen niet uit de nix-store of proceslijst
- **WHEN** de JuiceFS-mount-configuratie en het draaiende mount-proces worden geïnspecteerd
- **THEN** staan de S3-secret-key en het JuiceFS-format-secret niet leesbaar in de nix-store, unit of `ps`-output, maar worden ze via een agenix-secret geladen

### Requirement: Metadata lokaal op bobadela1, host blijft zelfstandig

Het systeem SHALL de JuiceFS-metadata opslaan in een lokale PostgreSQL 16-instance op bobadela1,
benaderd via de unix-socket, disk-durable (WAL + fsync). De Nextcloud-opslag SHALL blijven werken
als malandro of de LAN wegvalt.

#### Scenario: Mount gebruikt lokale metadata-DB
- **WHEN** de JuiceFS-mount metadata-operaties uitvoert
- **THEN** gaan die naar de lokale PostgreSQL op bobadela1 via de unix-socket, zonder netwerk-round-trip

#### Scenario: Zelfstandig bij uitval malandro
- **WHEN** malandro of de LAN onbereikbaar is
- **THEN** blijven lezen en schrijven op de JuiceFS-mount (en dus Nextcloud) functioneren

### Requirement: Live DR-kopie van de metadata via logical replication

Het systeem SHALL de JuiceFS-metadata-DB op bobadela1 als PostgreSQL-publisher publiceren en op de
bestaande PostgreSQL 16-master op malandro als subscriber live repliceren naar een doel-DB
`juicefs_meta_replica`. De subscriber SHALL de verbinding uitgaand naar bobadela1:5432 opzetten.

#### Scenario: Changes stromen naar malandro
- **WHEN** op bobadela1 een bestand wordt aangemaakt dat metadata-rijen toevoegt
- **THEN** verschijnen die rijen kort daarna in `juicefs_meta_replica` op malandro

#### Scenario: Publisher schrijft door tijdens subscriber-downtime
- **WHEN** malandro tijdelijk onbereikbaar is en daarna terugkomt
- **THEN** blijft bobadela1 lokaal schrijven en haalt de subscriber de gemiste changes bij herstel in

### Requirement: Boot-ordering — mount vóór de Nextcloud-containers

Het systeem SHALL garanderen dat de JuiceFS-mount beschikbaar is voordat de Nextcloud AIO-containers
starten, zodat de containers nooit op een lege of niet-gemounte datadir opstarten.

#### Scenario: Container start pas na mount
- **WHEN** bobadela1 opstart
- **THEN** start de Nextcloud AIO-stack pas nadat de JuiceFS-mount (en dus de lokale PostgreSQL) actief is

### Requirement: Herstelpad dekt metadata én data

Het systeem SHALL een gedocumenteerd, getest herstelpad hebben waarbij de JuiceFS-filesystem
herbouwd kan worden uit (a) een metadata-bron — de gerepliceerde DB op malandro óf een
engine-onafhankelijke `juicefs dump` — en (b) de S3-datalaag, met S3-bucket-versioning aan op de
`juicefs/`-prefix.

#### Scenario: Restore uit metadata-dump + S3
- **WHEN** een beheerder een `juicefs dump`-export en de S3-`juicefs/`-prefix beschikbaar heeft
- **THEN** kan de JuiceFS-filesystem via `juicefs load` in een lege metadata-engine worden hersteld en opnieuw gemount

#### Scenario: Versioning beschermt de datalaag
- **WHEN** een object op de `juicefs/`-prefix wordt overschreven of verwijderd
- **THEN** blijft een eerdere versie herstelbaar dankzij S3-bucket-versioning

