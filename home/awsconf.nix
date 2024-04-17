{ lib, pkgs,config, ... }:

let

  ## NOTE RUN aws --profile=web_dns s3 cp s3://docs-mcs.technative.eu-longhorn/managed_service_accounts.json ~/.aws/

  technative_profiles = "${config.home.homeDirectory}/.aws/managed_service_accounts.json";

  aws_accounts = builtins.fromJSON (lib.readFile technative_profiles);

  groups = {
    mustad_hoofcare.color = "e5a50a";
    technative.color = "9141ac";
    ddgc.color = "1c71d8";
    ddgc.ignore = true;
    improvement_it.color = "1c71d8";
    dreamlines.ignore = true;
    default.color = "cccccc";
    tracklib.ignore = true; 
    pastbook.ignore = true;
    splitser.ignore = true;
    taskhero.ignoge = true;
  };

  account_names = {
    GitBackup.ignore = true;
    ct_lz_audit.ignore = true;
    ct_lz_log_archive.ignore = true;
    finops.ignore = true;
    playground-student18.ignore = true;
    playground-student17.ignore = true;
    playground-student16.ignore = true;
    playground-student15.ignore = true;
    playground-student14.ignore = true;
    playground-student13.ignore = true;
    playground-student12.ignore = true;
    playground-student11.ignore = true;
    playground-student10.ignore = true;
    playground-student09.ignore = true;
    playground-student08.ignore = true;
    playground-student07.ignore = true;
    playground-student06.ignore = true;
    playground-student05.ignore = true;
    playground-student04.ignore = true;
    playground-student03.ignore = true;
    playground-student02.ignore = true;
  };

  alternative_regions = {
    "221539347604" = "us-east-2"; #mustad 
    "925937276627" = "us-east-2"; #mustad 
  };
  alternative_names = {
    "760178553019" = "playground wtoorren";
    "992382674167" = "iit-nonprod";
    "730335585156" = "iit-prod";
  };

  normalize_group = group : __concatStringsSep "_" (builtins.filter (x: builtins.typeOf x == "string") (__split " " (lib.strings.toLower group)));

  account_name = account :
      if builtins.hasAttr account.account_id alternative_names then alternative_names."${account.account_id}" else account.account_name;

#  show_account = account :
#    let
#      groupnorm = normalize_group account.customer_name;
#    in
#
#    if builtins.hasAttr groupnorm groups && builtins.hasAttr "ignore" groups.${groupnorm} && groups.${groupnorm}.ignore == true then false
#    else true;

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
in
{
  imports = [
    ./custom_modules/awscli_custom.nix
  ];

 programs.awscli_custom = {
    package = pkgs.awscli2;
    enable = true;
    settings = {

      "technative" = {
        aws_account_id = "technativebv";
        account_id = "technativebv";
        region = "eu-central-1";
        output = "table";
      };
    }
    // builtins.listToAttrs (builtins.map (account: {
       name = "profile ${account_name account}";
       value = tn_profile { account_id = account.account_id; group = account.customer_name; };
    }) (builtins.filter (account: show_account account) aws_accounts));

  };
}
