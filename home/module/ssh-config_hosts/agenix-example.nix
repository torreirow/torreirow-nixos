# Example configuration for using agenix with ssh-config_hosts module
#
# This file demonstrates how to configure encrypted SSH host configurations
# using agenix in your home-manager setup.
#
# Usage:
#   1. Add agenix secrets to your NixOS configuration (see below)
#   2. Import this file or copy the configuration to your home-manager modules
#   3. Adjust the paths and names to match your setup

{ config, ... }:

{
  # Configure agenix secrets for SSH host configurations
  #
  # IMPORTANT: Use the direct path string, not config.age.secrets.*.path
  # because agenix secrets are only available in NixOS config, not home-manager
  programs.ssh-config-hosts.agenixSecrets = [
    # Example 1: Customer A production servers
    {
      name = "customer-prod";
      path = "/run/secrets/ssh-hosts-customer-prod";  # Direct path to decrypted secret
    }

    # Example 2: Customer B sensitive environments
#    {
#      name = "customer-b-secret";
#      path = "/run/secrets/ssh-hosts-customer-b-secret";  # Direct path to decrypted secret
#    }

    # Add more agenix secrets as needed...
  ];
}

# Corresponding NixOS configuration (add to your hosts/*/configuration.nix or secrets file):
#
# age.secrets = {
#   ssh-hosts-customer-a-prod = {
#     file = ../../secrets/ssh-hosts-customer-a-prod.json.age;
#     path = "/run/secrets/ssh-hosts-customer-a-prod";
#     owner = "wtoorren";
#     mode = "0400";
#   };
#
#   ssh-hosts-customer-b-secret = {
#     file = ../../secrets/ssh-hosts-customer-b-secret.json.age;
#     path = "/run/secrets/ssh-hosts-customer-b-secret";
#     owner = "wtoorren";
#     mode = "0400";
#   };
# };

# The encrypted JSON files should have the same format as regular JSON files:
# [
#   {
#     "host": "prod-web",
#     "hostname": "web.customer-a.com",
#     "user": "deploy",
#     "identity_file": "customer-a-deploy-key",
#     "port": 22
#   },
#   {
#     "host": "prod-db",
#     "hostname": "db.customer-a.com",
#     "user": "admin",
#     "identity_file": "customer-a-admin-key",
#     "port": 2222
#   }
# ]
