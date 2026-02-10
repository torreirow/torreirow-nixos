{ config, pkgs, lib, ... }:

let
  repoDir = "/var/www/notes";
  secretFile = "/run/keys/github-webhook-secret";

  hugo_01545 = pkgs.hugo.overrideAttrs (old: rec {
    version = "0.154.5";

    src = pkgs.fetchFromGitHub {
      owner = "gohugoio";
      repo = "hugo";
      rev = "v${version}";
      hash = "sha256-1wzsmg0v14ksqq3gf439dxc7rhw1bm595xma3zsnszbi3sfri4k0";
    };
  });
in
{
  ############################
  ## Packages
  ############################
  environment.systemPackages = with pkgs; [
    git
    hugo_01545
  ];

  ############################
  ## systemd: Hugo rebuild
  ############################
  systemd.services.hugo-rebuild = {
    description = "Rebuild Hugo site from GitHub repo";
    wantedBy = [ ];

    serviceConfig = {
      Type = "oneshot";
      User = "www-data";
      Group = "www-data";
      WorkingDirectory = repoDir;

      ExecStart = [
        "${pkgs.bash}/bin/bash -euo pipefail -c ''
          exec 9>/tmp/hugo-build.lock || exit 1
          flock -n 9 || exit 0

          git fetch origin main

          if [ \"$(git rev-parse HEAD)\" != \"$(git rev-parse origin/main)\" ]; then
            git pull --ff-only origin main

            ${hugo_01545}/bin/hugo \
              --minify \
              --cleanDestinationDir
          fi
        ''"
      ];
    };
  };

  ############################
  ## nginx + Lua webhook
  ############################
 services.nginx = {
  enable = true;

  package = pkgs.nginxMainline.override {
    modules = with pkgs.nginxModules; [ lua ];
  };

  virtualHosts."notes.toorren.net" = {
    forceSSL = true;
    useACMEHost = "toorren.net";

    root = "/var/www/notes/public";

    locations = {
      "/" = { };

      "/webhook/hugo" = {
        extraConfig = ''
          limit_except POST { deny all; }

          content_by_lua_block {
            local hmac = require "resty.hmac"
            local str  = require "resty.string"

            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            if not body then
              ngx.status = 400
              ngx.say("Missing body")
              return
            end

            local sig = ngx.req.get_headers()["X-Hub-Signature-256"]
            if not sig then
              ngx.status = 403
              ngx.say("Missing signature")
              return
            end

            local f = io.open("/run/keys/github-webhook-secret", "r")
            if not f then
              ngx.status = 500
              ngx.say("Secret unavailable")
              return
            end
            local secret = f:read("*l")
            f:close()

            local hm = hmac:new(secret, hmac.ALGOS.SHA256)
            hm:update(body)
            local digest = hm:final()
            local expected = "sha256=" .. str.to_hex(digest)

            if expected ~= sig then
              ngx.status = 403
              ngx.say("Invalid signature")
              return
            end

            local res = os.execute(
              "/run/current-system/sw/bin/systemctl start hugo-rebuild.service"
            )

            if res ~= 0 then
              ngx.status = 500
              ngx.say("Failed to trigger build")
              return
            end

            ngx.say("Build triggered")
          }
        '';
      };
    };
  };
};
 
  ############################
  ## sudo: nginx → systemd
  ############################
  security.sudo.extraRules = [
    {
      users = [ "www-data" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start hugo-rebuild.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

}

