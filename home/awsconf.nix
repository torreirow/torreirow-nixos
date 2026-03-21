{ lib, pkgs,config, unstable, ... }:

let
  ## JSON wordt ingelezen vanaf home directory tijdens build met --impure flag
  ## Fallback naar empty list als file niet bestaat
  json_path = /. + "${config.home.homeDirectory}/.aws/managed_service_accounts.json";

  ## Helper om AWS accounts in te lezen met waarschuwingen
  aws_accounts =
    let
      accounts_data =
        if builtins.pathExists json_path
        then builtins.fromJSON (builtins.readFile json_path)
        else [];

      account_count = builtins.length accounts_data;
    in
      # Waarschuwing als bestand niet bestaat (waarschijnlijk geen --impure flag)
      if !builtins.pathExists json_path
      then builtins.warn ''

        ⚠️  AWS CONFIG WARNING ⚠️
        JSON file not found: ${json_path}

        This likely means you're running without --impure flag.
        AWS profiles cannot be generated without reading this file.

        → Run: home-manager switch --flake .#wtoorren@linuxdesktop --impure

        Only static profiles will be available.
        ''
        []
      # Waarschuwing als bestand leeg is
      else if account_count == 0
      then builtins.warn ''

        ⚠️  AWS CONFIG WARNING ⚠️
        JSON file is empty: ${json_path}

        → Run: systemctl --user start aws-accounts-sync.service

        Only static profiles will be available.
        ''
        []
      # Waarschuwing als er verdacht weinig accounts zijn
      else if account_count < 50
      then builtins.warn ''

        ⚠️  AWS CONFIG WARNING ⚠️
        Only ${toString account_count} accounts found in JSON (expected 100+)
        The JSON file might be outdated.

        → Consider running: systemctl --user start aws-accounts-sync.service

        Generating ${toString account_count} dynamic profiles...
        ''
        accounts_data
      # Alles is goed, geen waarschuwing
      else accounts_data;

groups = {
  mustad_hoofcare.color = "e5a50a";
  mustad_hoofcare.shortname = "mus";
  technative.color = "9141ac";
  ddgc.color = "1c71d8";
  ddgc.ignore = false;
  improvement_it.color = "1c71d8";
  improvement_it.shortname = "iit";
  dreamlines.ignore = true;
  default.color = "cccccc";
  tracklib.ignore = false; 
  pastbook.ignore = false;
  splitser.ignore = false;
  taskhero.ignoge = true;
  technative.shortname = "tn";
  innofaith.color="03a5fc";
  innofaith.shortname="inf";
  innofaith.ignore = true;
};

account_names = {
  GitBackup.ignore = true;
  ct_lz_audit.ignore = true;
  ct_lz_log_archive.ignore = true;
  finops.ignore = true;
  playground-student18.ignore = false;
  playground-student17.ignore = false;
  playground-student16.ignore = false;
  playground-student15.ignore = false;
  playground-student14.ignore = false;
  playground-student13.ignore = false;
  playground-student12.ignore = false;
  playground-student11.ignore = false;
  playground-student10.ignore = false;
  playground-student09.ignore = false;
  playground-student08.ignore = false;
  playground-student07.ignore = false;
  playground-student06.ignore = false;
  playground-student05.ignore = false;
  playground-student04.ignore = false;
  playground-student03.ignore = false;
  playground-student02.ignore = false;
  playground-student01.ignore = false;
  technative_workload_internal_tools_nonprod.ignore = false;
  prod.ignore = true;
  test.ignore = true;
};

alternative_regions = {
  "221539347604" = "us-east-2"; #mustad 
  "925937276627" = "us-east-2"; #mustad 
  "906347402442" = "us-west-2"; #pastbook
  "353319268640" = "eu-west-1"; #docrev
  "255217714588" = "eu-west-1"; #docrev
  "189796657102" = "eu-west-1"; #docrev
  "945695383844" = "eu-west-1"; #docrev
  "975050060686" = "eu-west-1"; #docrev
};
  alternative_names = {
    #"760178553019" = "pg_wtoorren";
    "992382674167" = "iit-rrs-nonprod";
    "730335585156" = "iit-rrs-prod";
#    "911828776050" = "minecraft";
#    "992382674167" = "iit-nonprod";
#    "730335585156" = "iit-prod";
  };

  normalize_group = group : __concatStringsSep "_" (builtins.filter (x: builtins.typeOf x == "string") (__split " " (lib.strings.toLower group)));

  shortname_group = account :
  let
    shortname_temp = if builtins.hasAttr groupnorm groups && builtins.hasAttr "shortname" groups.${groupnorm} then 
    groups.${groupnorm}.shortname 
    else 
    builtins.substring 0 3 groupnorm;

    groupnorm = normalize_group account.customer_name;

  in
  lib.toUpper shortname_temp;

  # Remove spaces in profile names
  normalize_name = name: builtins.replaceStrings [" "] ["_"] name;
  account_name = account:
  normalize_name (
    if builtins.hasAttr account.account_id alternative_names
    then alternative_names."${account.account_id}"
    else account.account_name
    );

    show_account = account:
    let
    groupnorm = normalize_group account.customer_name;
    accountnorm = account_name account;
    in
    if (builtins.hasAttr groupnorm groups && builtins.hasAttr "ignore" groups.${groupnorm} && groups.${groupnorm}.ignore == true) ||
    (builtins.hasAttr accountnorm account_names && builtins.hasAttr "ignore" account_names.${accountnorm} && account_names.${accountnorm}.ignore == true)
    then false
    else true;

    tn_profile = {account_id, group } :
    let
      groupnorm = normalize_group group;
    in
    {
      inherit group;
      source_profile = "technative";
      role_arn = "arn:aws:iam::${account_id}:role/landing_zone_devops_administrator";
      region = if builtins.hasAttr account_id alternative_regions then alternative_regions."${account_id}" else "eu-central-1";
      color = if builtins.hasAttr groupnorm groups && builtins.hasAttr "color" groups.${groupnorm}
      then groups.${groupnorm}.color
      else groups.default.color;
    };

  # Sync script to download AWS accounts JSON from S3
  awsAccountsSyncScript = pkgs.writeShellScript "sync-aws-accounts" ''
    set -euo pipefail

    AWS_DIR="$HOME/.aws"
    JSON_FILE="$AWS_DIR/managed_service_accounts.json"
    S3_PATH="s3://docs-mcs.technative.eu-longhorn/managed_service_accounts.json"
    AWS_PROFILE="TN-web_dns"

    # Function to send GNOME notification
    notify() {
        local urgency="$1"
        local summary="$2"
        local body="$3"

        if command -v ${pkgs.libnotify}/bin/notify-send &> /dev/null; then
            ${pkgs.libnotify}/bin/notify-send --urgency="$urgency" "$summary" "$body"
        fi
    }

    # Ensure .aws directory exists
    mkdir -p "$AWS_DIR"

    # Try to download from S3
    echo "📥 Downloading AWS accounts JSON from S3..."
    echo "   Profile: $AWS_PROFILE"
    echo "   Source: $S3_PATH"
    echo "   Target: $JSON_FILE"

    if ${pkgs.awscli2}/bin/aws --profile="$AWS_PROFILE" s3 cp "$S3_PATH" "$JSON_FILE" 2>&1; then
        # Success - count accounts
        if [ -f "$JSON_FILE" ]; then
            account_count=$(${pkgs.jq}/bin/jq '. | length' "$JSON_FILE" 2>/dev/null || echo "unknown")

            echo "✓ Successfully downloaded $account_count accounts"
            notify "normal" \
                   "AWS Accounts Sync - Success" \
                   "Downloaded $account_count managed service accounts"

            exit 0
        else
            echo "❌ Download succeeded but file not found"
            notify "critical" \
                   "AWS Accounts Sync - Error" \
                   "Download succeeded but file not found at $JSON_FILE"
            exit 1
        fi
    else
        # Failed - check for common errors
        exit_code=$?

        if [[ $exit_code -eq 255 ]] || grep -q "ExpiredToken\|InvalidAccessKeyId\|SignatureDoesNotMatch" "$JSON_FILE" 2>/dev/null; then
            echo "❌ Authentication failed - AWS session expired or invalid credentials"
            notify "critical" \
                   "AWS Accounts Sync - Auth Failed" \
                   "AWS session expired for profile '$AWS_PROFILE'. Please refresh your credentials."
        elif [[ $exit_code -eq 1 ]]; then
            echo "❌ Profile not found or AWS CLI error"
            notify "critical" \
                   "AWS Accounts Sync - Profile Error" \
                   "Profile '$AWS_PROFILE' not found or AWS CLI error"
        else
            echo "❌ Download failed with exit code $exit_code"
            notify "critical" \
                   "AWS Accounts Sync - Failed" \
                   "Download failed with exit code $exit_code. Check logs with: journalctl --user -u aws-accounts-sync"
        fi

        exit $exit_code
    fi
  '';

in
  {
    imports = [
      ./custom_modules/awscli_custom.nix
    ];

    programs.awscli_custom = {
      package = unstable.awscli2;
      enable = true;
      settings = {

        "technative" = {
          aws_account_id = "technativebv";
          account_id = "technativebv";
          region = "eu-central-1";
          output = "table";
          group = "Technative";
        };

        "profile ActiFlow" = {
          role_arn = "arn:aws:iam::337810061405:role/TechnativeFullAccessRole";
          region = "eu-north-1";
          group = "ActiFlow";
          output = "json";
          source_profile = "technative";
        };

        "499164406685-wouter" = {
          region = "eu-central-1";
          output = "json";
          group = "toorren";
        };

        "255418484322-waardenburg" = {
          region = "eu-central-1";
          output = "json";
          group = "waardenburg";
        };

        "bedrock" = {
          region = "eu-central-1";
          output = "json";
          group = "bedrock";
        };


        "profile mustad-developer"= {
          role_arn = "arn:aws:iam::925937276627:role/developer";
          region = "us-east-2";
          output = "json";
          group = "mustad-pg";
          source_profile = "mustad";
        };

        "profile moooi"= {
          role_arn = "arn:aws:iam::014756588884:role/TechnativeRole";
          region = "eu-west-1";
          output = "json";
          group = "moooi";
          source_profile = "technative";
        };

        "profile mustad-jumphost"= {
          role_arn = "arn:aws:iam::925937276627:role/jumphost";
          region = "us-east-2";
          output = "json";
          group = "mustad-pg";
          source_profile = "mustad";
        };
        "profile DOC-docrevolution-readonly" = {
            group = "DocRevolution";
            output = "json";
            region = "eu-central-1";
            role_arn = "arn:aws:iam::267166554494:role/TechnativeRole";
            source_profile = "technative";
          };
      }
      // builtins.listToAttrs (builtins.map (account: {
        name = "profile ${shortname_group account}-${account_name account}";
        value = tn_profile { account_id = account.account_id; group = account.customer_name; };
      }) (builtins.filter (account: show_account account) aws_accounts));

    };

    # Systemd service for syncing AWS accounts (manual only, no timer)
  systemd.user.services.aws-accounts-sync = {
    Unit = {
      Description = "Sync AWS managed service accounts JSON from S3";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${awsAccountsSyncScript}";
    };
  };
}
