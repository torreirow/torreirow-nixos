{ config, lib, ... }:

# HTTP/2 is op verzoek uitgeschakeld op malandro, voor alle vhosts op dezelfde
# 443-listener. Nginx 1.25+ zet `http2 on;` per serverblok; zolang één vhost op
# hetzelfde IP/poort HTTP/2 aan heeft, kan de verbinding alsnog h2 onderhandelen.
# Daarom expliciet alle vhosts op false.
#
# Nieuwe vhost? De assertion hieronder laat de build falen tot de naam in deze
# lijst staat (en dus http2=false krijgt).
let
  vhosts = [
    "adresses.toorren.net"
    "agenda.toorren.net"
    "alertmanager.toorren.net"
    "auth.toorren.net"
    "auth.wereldvanbegrip.nl"
    "blocky.toorren.net"
    "boaz.toorren.net"
    "cap.toorren.net"
    "cckafe.com"
    "cockpit.toorren.net"
    "contacts.toorren.net"
    "cv-jolijn.toorren.net"
    "docs.toorren.net"
    "eghupload.toorren.net"
    "fail2ban.toorren.net"
    "feeds.toorren.net"
    "filesender.toorren.net"
    "grafana.dutchyland.net"
    "grafana.toorren.net"
    "grainwork.dutchyland.net"
    "homeassistant.toorren.net"
    "id.dutchyland.net"
    "invoices.wereldvanbegrip.nl"
    "ittools.toorren.net"
    "kpn.toorren.net"
    "linny-mcp.toorren.net"
    "linny.toorren.net"
    "mailer.toorren.net"
    "mails.toorren.net"
    "markmysteps.toorren.net"
    "nxc.toorren.net"
    "onzeovereenkomst.wereldvanbegrip.nl"
    "opsknight.toorren.net"
    "pdftools.toorren.net"
    "photos.toorren.net"
    "podcast.toorren.net"
    "prometheus.toorren.net"
    "reis.toorren.net"
    "stats.toorren.net"
    "status.toorren.net"
    "stichtingwittevelden.nl"
    "subscriptions.toorren.net"
    "tasks.toorren.net"
    "test.cckafe.com"
    "toorren.net"
    "upload.toorren.net"
    "url.toorren.net"
    "vw.toorren.net"
    "vulns.toorren.net"
    "wereldvanbegrip.nl"
    "wg.toorren.net"
    "wildcard-placeholder"
    "wouter.toorren.net"
    "www.cckafe.com"
    "www.toorren.net"
    "www.wereldvanbegrip.nl"
    "zigbee2mqtt.toorren.net"
  ];
in
{
  services.nginx.virtualHosts = lib.genAttrs vhosts (_: { http2 = false; });

  assertions = [
    {
      assertion = lib.all (vhost: !vhost.http2) (lib.attrValues config.services.nginx.virtualHosts);
      message = "HTTP/2 staat nog aan voor een nginx-vhost op malandro; voeg de vhost toe aan modules/nginx-no-http2.nix.";
    }
  ];
}
