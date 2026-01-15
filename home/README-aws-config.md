# AWS Config Synchronisatie

Dit document beschrijft hoe de automatische AWS config generatie werkt voor TechNative managed accounts.

## Overzicht

Het systeem synchroniseert AWS account informatie van een centrale website en genereert automatisch AWS CLI profiles voor alle managed accounts. Dit elimineert handmatig onderhoud van de `~/.aws/config` file.

## Architectuur

```
┌─────────────────────────────────────────────────────────────┐
│ Centraal AWS Account Management Systeem                     │
│ (TechNative intranet website)                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ HTTPS (authenticatie vereist)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ sync-aws-accounts.py                                        │
│ - Authenticeert met website                                │
│ - Download account JSON                                     │
│ - Schrijft naar ~/.aws/managed_service_accounts.json       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ awsconf.nix (home-manager module)                          │
│ - Leest JSON met builtins.readFile                         │
│ - Past filters toe (ignore lists)                          │
│ - Genereert profile configuraties                          │
│ - Voegt custom names en colors toe                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ ~/.aws/config                                               │
│ - 103 dynamisch gegenereerde profiles                       │
│ - Beheerd door home-manager                                │
└─────────────────────────────────────────────────────────────┘
```

## Bestanden

### Locaties

- **Source data**: `~/.aws/managed_service_accounts.json` (35KB, 133 accounts)
- **Sync script**: `home/scripts/sync-aws-accounts.py`
- **Update script**: `home/scripts/update-aws-config.sh`
- **Nix module**: `home/awsconf.nix`
- **Output**: `~/.aws/config` (742 lines, 103 profiles)

### JSON Structuur

```json
[
  {
    "account_id": "975050051976",
    "account_name": "NonProduction",
    "customer_name": "Technative",
    "disabled": "False",
    "roles": "landing_zone_devops_administrator, landing_zone_devops_user, ..."
  }
]
```

## Gebruik

### Normale Update

Wanneer AWS accounts zijn toegevoegd/gewijzigd:

```bash
./home/scripts/update-aws-config.sh
```

Dit script:
1. Synchroniseert accounts van website → `~/.aws/managed_service_accounts.json`
2. Rebuild home-manager met `--impure` flag
3. Genereert nieuwe `~/.aws/config`

### Manuele Sync (met login)

Als je opnieuw moet authenticeren:

```bash
python3 home/scripts/sync-aws-accounts.py --login
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

### Profile Structuur

Gegenereerde profiles volgen dit patroon:

```ini
[profile TN-NonProduction]
color=9141ac
group=Technative
region=eu-central-1
role_arn=arn:aws:iam::975050051976:role/landing_zone_devops_administrator
source_profile=technative
```

Waarbij:
- **Profile naam**: `{SHORTNAME}-{account_name}`
  - `TN` = Technative (3-letter shortname)
  - Custom shortnames gedefinieerd in `awsconf.nix`
- **color**: Hex kleurcode per customer group
- **group**: Customer naam voor visuele herkenning
- **region**: Default `eu-central-1`, custom per account mogelijk
- **role_arn**: IAM role voor assume role
- **source_profile**: Base profile voor authenticatie

## Configuratie

### Filters (awsconf.nix)

**Ignored Groups** (hele customer wordt geskipt):
```nix
groups = {
  dreamlines.ignore = true;
  innofaith.ignore = true;
  taskhero.ignore = true;
};
```

**Ignored Accounts** (specifieke accounts):
```nix
account_names = {
  GitBackup.ignore = true;
  ct_lz_audit.ignore = true;
  ct_lz_log_archive.ignore = true;
  finops.ignore = true;
  prod.ignore = true;    # Technative prod account
  test.ignore = true;    # Technative test account
};
```

**Result**: 133 accounts in JSON → 99 accounts na filtering → 103 profiles (99 + 4 static)

### Custom Shortnames

```nix
groups = {
  technative.shortname = "tn";
  improvement_it.shortname = "iit";
  mustad_hoofcare.shortname = "mus";
  # Default: eerste 3 letters lowercase
};
```

### Alternative Names

Voor specifieke accounts met afwijkende namen:

```nix
alternative_names = {
  "992382674167" = "iit-rrs-nonprod";
  "730335585156" = "iit-rrs-prod";
};
```

### Alternative Regions

Accounts met afwijkende default regions:

```nix
alternative_regions = {
  "221539347604" = "us-east-2";  # Mustad development
  "925937276627" = "us-east-2";  # Mustad production
  "906347402442" = "us-west-2";  # Pastbook QA
};
```

### Colors

Kleur per customer group (hex zonder #):

```nix
groups = {
  technative.color = "9141ac";        # Paars
  improvement_it.color = "1c71d8";    # Blauw
  mustad_hoofcare.color = "e5a50a";   # Geel
  default.color = "cccccc";           # Grijs fallback
};
```

## Beveiliging

### Gevoelige Data

⚠️ **BELANGRIJK**: De `managed_service_accounts.json` bevat gevoelige informatie:
- Alle TechNative klantnamen
- AWS account structuren
- Account IDs
- Business intelligence

### Git Bescherming

Het JSON bestand:
- Staat **NIET** in git (toegevoegd aan `.gitignore`)
- Is **verwijderd** uit git history met `git-filter-repo`
- Wordt **alleen** lokaal opgeslagen in `~/.aws/`
- Wordt **direct** gelezen door Nix met `--impure` flag

### Workflow Veiligheid

```bash
# ✅ GOED - Veilig updaten
./home/scripts/update-aws-config.sh

# ❌ FOUT - Geen git commands op JSON file
git add home/managed_service_accounts.json
git commit -m "update accounts"  # DOE DIT NOOIT
```

## Troubleshooting

### Sync Faalt

**Symptoom**: `sync-aws-accounts.py` geeft authenticatie error

**Oplossing**:
```bash
python3 home/scripts/sync-aws-accounts.py --login
```

### Profiles Niet Gegenereerd

**Symptoom**: `~/.aws/config` bevat maar 4 profiles

**Mogelijke oorzaken**:
1. JSON file niet aanwezig: `ls -la ~/.aws/managed_service_accounts.json`
2. Home-manager zonder `--impure`: voeg flag toe
3. Syntax error in awsconf.nix: check met `nix eval --impure --json '.#homeConfigurations."wtoorren@linuxdesktop".config.programs.awscli_custom.settings'`

**Oplossing**:
```bash
# Verify JSON exists
test -f ~/.aws/managed_service_accounts.json && echo "OK" || echo "MISSING"

# Test Nix evaluation
cd ~/data/git/torreirow/torreirow-nixos
nix eval --impure --expr 'let awsconf = import ./home/awsconf.nix {
  lib = (import <nixpkgs> {}).lib;
  pkgs = import <nixpkgs> {};
  config.home.homeDirectory = "/home/wtoorren";
  unstable = import <nixpkgs> {};
}; in builtins.length (builtins.attrNames awsconf.programs.awscli_custom.settings)'
# Verwacht: 107

# Rebuild
home-manager switch --flake .#wtoorren@linuxdesktop --impure
```

### Account Ontbreekt

**Check filters**:
```bash
# Zoek account in JSON
jq '.[] | select(.account_name == "MyAccount")' ~/.aws/managed_service_accounts.json

# Check ignore settings in awsconf.nix
grep -A 5 "groups = {" home/awsconf.nix
grep -A 30 "account_names = {" home/awsconf.nix
```

## Statistieken

**Huidige configuratie** (2026-01-15):
- **Source accounts**: 133 (in JSON)
- **Filtered accounts**: 99 (na ignore filters)
- **Total profiles**: 103 (99 dynamic + 4 static)
- **Config size**: 742 lines
- **Customer groups**: 15+ actieve klanten

**Filter breakdown**:
- Ignored groups: 3 (Dreamlines, Innofaith, Taskhero)
- Ignored accounts: 6 (GitBackup, audit/log archives, finops, test/prod)
- Filtered out: 34 accounts totaal

## Statische Profiles

Naast dynamische profiles zijn er 4 handmatig geconfigureerde profiles:

1. **technative** - Base profile voor authentication
2. **ActiFlow** - Custom role mapping
3. **moooi** - Custom role mapping
4. **mustad-developer** / **mustad-jumphost** - Special mustad roles

Deze worden gedefinieerd in `awsconf.nix` lines 209-266.

## Development

### Wijzigen van Filters

1. Edit `home/awsconf.nix`
2. Voeg toe aan ignore lists:
   ```nix
   groups = {
     newcustomer.ignore = true;  # Hele klant skippen
   };

   account_names = {
     specific_account.ignore = true;  # Specifiek account
   };
   ```
3. Rebuild: `home-manager switch --flake .#wtoorren@linuxdesktop --impure`

### Toevoegen Custom Shortname

1. Edit `home/awsconf.nix`:
   ```nix
   groups = {
     customer_name.shortname = "cst";
     customer_name.color = "ff0000";
   };
   ```
2. Rebuild: `home-manager switch --flake .#wtoorren@linuxdesktop --impure`

### Testen

```bash
# Test zonder rebuild
nix eval --impure --json '.#homeConfigurations."wtoorren@linuxdesktop".config.programs.awscli_custom.settings' | jq 'keys | length'

# Show all profile names
nix eval --impure --json '.#homeConfigurations."wtoorren@linuxdesktop".config.programs.awscli_custom.settings' | jq 'keys'
```

## Referenties

- **awscli_custom module**: `home/custom_modules/awscli_custom.nix`
- **Sync script**: `home/scripts/sync-aws-accounts.py`
- **Update script**: `home/scripts/update-aws-config.sh`
- **Main config**: `home/awsconf.nix`
- **Imported in**: `home/linux-desktop.nix:4`

## Zie Ook

- AWS CLI Profiles: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html
- AWS AssumeRole: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html
- Nix Impure Evaluation: https://nixos.wiki/wiki/Flakes#Impure_evaluation
