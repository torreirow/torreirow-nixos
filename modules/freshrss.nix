{ config, lib, pkgs, ... }:

# FreshRSS als CVE-/security-feedreader op feeds.toorren.net.
#
# Draait native (php-fpm + SQLite) via de NixOS-module; geen Docker. De feed-
# TTL staat op 15 minuten en cli/actualize_script.php draait elke 5 minuten,
# zodat elk kanaal binnen 15-30 minuten ververst.
#
# Auth: Authelia forward-auth op de web-UI, met FreshRSS op `http_auth` zodat
# REMOTE_USER uit Authelia de login is (geen tweede wachtwoord). De Google
# Reader-API onder /api/ blijft buiten Authelia: mobiele apps (Readrops)
# gebruiken het API-wachtwoord. Zie docs/freshrss.md.
{
  age.secrets.freshrss-password = {
    file = ../secrets/freshrss-password.age;
    owner = "freshrss";
    mode = "0400";
  };

  # agenix legt de secrets onder /run/keys/wouter (secretsDir van deze host); die
  # map is 0750 root:keys. Zonder de keys-groep kan freshrss het wachtwoord niet
  # lezen en maakt freshrss-config de gebruiker met een leeg wachtwoord aan.
  users.users.freshrss.extraGroups = [ "keys" ];

  services.freshrss = {
    enable = true;
    baseUrl = "https://feeds.toorren.net";
    defaultUser = "wouter";
    passwordFile = config.age.secrets.freshrss-password.path;
    language = "nl";
    webserver = "nginx";
    virtualHost = "feeds.toorren.net";
    database.type = "sqlite";
    api.enable = true;
    authType = "http_auth";
  };

  services.nginx.virtualHosts."feeds.toorren.net" =
    let
      authelia = import ./authelia-nginx.nix { inherit lib; };

      # FreshRSS vertrouwt HTTP_REMOTE_USER/HTTP_X_WEBAUTH_USER zodra REMOTE_ADDR
      # in trusted_sources valt; php-fpm ziet nginx als 127.0.0.1 en dus moet een
      # client deze headers niet kunnen injecteren.
      stripAuthHeaders = ''
        fastcgi_param HTTP_REMOTE_USER "";
        fastcgi_param HTTP_X_WEBAUTH_USER "";
        fastcgi_param REDIRECT_REMOTE_USER "";
      '';

      apiFastcgi = ''
        fastcgi_pass unix:${config.services.phpfpm.pools.freshrss.socket};
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        set $path_info $fastcgi_path_info;
        fastcgi_param PATH_INFO $path_info;
        include ${pkgs.nginx}/conf/fastcgi_params;
        include ${pkgs.nginx}/conf/fastcgi.conf;
        ${stripAuthHeaders}
      '';

      autheliaUi = ''
        auth_request /authelia;
        auth_request_set $authelia_user $upstream_http_remote_user;
        error_page 401 =302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
      '';
    in
    {
      forceSSL = true;
      useACMEHost = "toorren.net";

      locations."/authelia" = authelia.autheliaVerifyLocation;

      locations."/" = {
        extraConfig = autheliaUi;
      };

      locations."~ ^.+?\\.php(/.*)?$" = {
        extraConfig = ''
          ${autheliaUi}
          fastcgi_param REMOTE_USER $authelia_user;
          ${stripAuthHeaders}
        '';
      };

      # Google Reader- en Fever-API: eigen wachtwoord, geen Authelia.
      locations."^~ /api/" = {
        extraConfig = apiFastcgi;
      };

      locations."= /f.php" = {
        extraConfig = apiFastcgi;
      };
    };
}
