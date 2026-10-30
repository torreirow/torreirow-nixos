{ config, lib, ... }:

# Umami: anonieme bezoekmeting (land/stad, geen IP-adressen, geen cookies) voor de publieke
# sites op malandro en Cloudflare Pages. Zie docs/umami.md.
#
# stats.toorren.net:
#   - publiek:     het tracker-script en het meldadres (neutrale namen tegen adblockers)
#   - Authelia:    al het andere, dus het dashboard (groep monitoring, modules/authelia.nix)

let
  port = 8103;
  # Neutrale namen: geen "umami"/"analytics"/"stats"/"track" in de URL's.
  scriptName = "s.js";
  collectPath = "/api/e";
  upstream = "http://127.0.0.1:${toString port}";

  # Gemeten sites op malandro: vhost -> Umami-website-ID. Niet geheim (staat in elke pagina).
  # De Cloudflare-sites (noraly, devos, recepten, www.stichtingwittevelden) zetten het script
  # zelf in hun broncode; hun ID's staan in docs/umami.md.
  trackedSites = {
    "toorren.net" = "6bdab9b3-a439-475b-aedc-d97bd11d880c";
    "wereldvanbegrip.nl" = "39cda487-8794-4414-89fc-f7e3070f0cc1";
    "cckafe.com" = "9dea5922-4439-43f7-9545-d362eb9e58db";
    "cv-jolijn.toorren.net" = "acab2514-2605-401f-a2b4-7e4713cf8e56";
    "boaz.toorren.net" = "dbcaa556-bf85-41ed-8670-ed4af36d230c";
    "eghupload.toorren.net" = "1e0423de-8655-4832-8956-b0dbd78f0251";
  };
  # Locations die HTML leveren, als het niet alleen "/" is.
  htmlLocations = { "toorren.net" = [ "/" "~ \\.php$" ]; };
  # Proxied sites: de backend moet ongecomprimeerd antwoorden, anders kan sub_filter niets.
  proxiedSites = [ "eghupload.toorren.net" ];
  # Bewust niet: onzeovereenkomst.wereldvanbegrip.nl (DocuSeal). Een app met vertrouwelijke
  # documenten, en de strikte CSP (script-src met nonce) blokkeert het script terecht.

  # Vóór </body> en niet </head>: de geminificeerde Hugo-pagina van toorren.net heeft geen
  # </head>. data-domains zorgt dat kopieën van de pagina elders niet meetellen.
  trackSnippet = site: id: ''
    sub_filter '</body>' '<script defer src="https://stats.toorren.net/${scriptName}" data-website-id="${id}" data-domains="${site}"></script></body>';
    sub_filter_once on;
  '' + lib.optionalString (lib.elem site proxiedSites) ''
    proxy_set_header Accept-Encoding "";
  '';
in
{
  age.secrets.umami-app-secret = {
    file = ../secrets/umami-app-secret.age;
    mode = "0400"; # root; de module geeft hem via LoadCredential door aan de DynamicUser
  };

  services.umami = {
    enable = true;
    createPostgresqlDatabase = true; # database + gebruiker umami, peer-auth via /run/postgresql
    settings = {
      APP_SECRET_FILE = config.age.secrets.umami-app-secret.path;
      HOSTNAME = "127.0.0.1";
      PORT = port;
      TRACKER_SCRIPT_NAME = [ scriptName ];
      COLLECT_API_ENDPOINT = collectPath;
      # nginx zet X-Real-IP op het bezoekers-IP; Umami gebruikt het alleen voor GeoIP en de
      # anonieme sessie-hash en bewaart het niet.
      CLIENT_IP_HEADER = "x-real-ip";
      DISABLE_TELEMETRY = true;
    };
  };

  services.nginx = {
    commonHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=umami:10m rate=60r/m;
    '';

    virtualHosts = lib.mkMerge [
      (lib.mapAttrs (site: id: {
        locations = lib.genAttrs (htmlLocations.${site} or [ "/" ]) (_: {
          extraConfig = trackSnippet site id;
        });
      }) trackedSites)
      {
        "stats.toorren.net" = {
          forceSSL = true;
          useACMEHost = "toorren.net";

          # Publiek: tracker-script en meldadres, zonder login.
          locations."= /${scriptName}" = {
            proxyPass = upstream;
            extraConfig = ''
              expires 1h;
            '';
          };
          locations."= ${collectPath}" = {
            proxyPass = upstream;
            extraConfig = ''
              limit_except POST OPTIONS { deny all; }
              limit_req zone=umami burst=30 nodelay;
              client_max_body_size 16k;
            '';
          };

          # Dashboard: Authelia forward-auth (patroon uit cockpit.nix).
          locations."/" = {
            proxyPass = upstream;
            extraConfig = ''
              auth_request /authelia;
              auth_request_set $user $upstream_http_remote_user;
              auth_request_set $groups $upstream_http_remote_groups;
              auth_request_set $name $upstream_http_remote_name;
              auth_request_set $email $upstream_http_remote_email;

              error_page 401 = @authelia_portal;

              proxy_set_header Remote-User $user;
              proxy_set_header Remote-Groups $groups;
              proxy_set_header Remote-Name $name;
              proxy_set_header Remote-Email $email;
            '';
          };

          locations."@authelia_portal".extraConfig = ''
            return 302 https://auth.toorren.net/?rd=$scheme://$http_host$request_uri;
          '';

          locations."/authelia" = {
            proxyPass = "http://127.0.0.1:9091/api/verify";
            extraConfig = ''
              internal;
              proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
              proxy_set_header X-Forwarded-Method $request_method;
              proxy_set_header X-Forwarded-Host $http_host;
              proxy_set_header X-Forwarded-Uri $request_uri;
              proxy_set_header X-Forwarded-For $remote_addr;
              proxy_set_header Content-Length "";
              proxy_pass_request_body off;
            '';
          };
        };
      }
    ];
  };
}
