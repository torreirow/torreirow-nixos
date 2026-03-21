{ pkgs, ... }:
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    port = 9115;
    configFile = pkgs.writeText "blackbox.yml" ''
      modules:
        # Externe HTTPS checks (SSL certificaat + bereikbaarheid)
        http_2xx:
          prober: http
          timeout: 15s
          http:
            fail_if_not_ssl: true
            ip_protocol_fallback: false
            method: GET
            no_follow_redirects: false
            preferred_ip_protocol: "ip4"
            valid_http_versions:
              - "HTTP/1.1"
              - "HTTP/2.0"

        # Interne HTTP checks (localhost endpoints, geen SSL vereist)
        http_2xx_internal:
          prober: http
          timeout: 10s
          http:
            fail_if_not_ssl: false
            ip_protocol_fallback: false
            method: GET
            no_follow_redirects: false
            preferred_ip_protocol: "ip4"
            valid_status_codes: [200, 302]
            valid_http_versions:
              - "HTTP/1.0"
              - "HTTP/1.1"
              - "HTTP/2.0"
    '';
  };

  systemd.services.prometheus-blackbox-exporter.serviceConfig.Environment = [
    "SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt"
  ];
}

