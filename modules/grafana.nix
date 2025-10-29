{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.grafana;
  sslCheckerEnabled = config.services.ssl-checker.enable;
in {
  options = {
    services.ssl-checker = {
      enable = mkEnableOption "SSL certificate expiration checker";
      
      domains = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of domains to check SSL certificates for";
      };
      
      alertThresholdDays = mkOption {
        type = types.int;
        default = 30;
        description = "Alert when certificates are about to expire within this many days";
      };
      
      checkInterval = mkOption {
        type = types.str;
        default = "12h";
        description = "How often to check certificates";
      };
    };
  };

  config = {
    services.grafana = {
      enable = true;
      domain = "grafana.local";
      port = 3000;
      addr = "127.0.0.1";
      
      # Basic authentication settings
      auth.anonymous.enable = false;
      
      # Secure installation
      settings = {
        security = {
          admin_user = "admin";
          admin_password = "$__file{/var/lib/grafana/admin_password}";
        };
      };
      
      # Provision dashboards and data sources
      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:9090";
            isDefault = true;
          }
        ];
        
        dashboards.settings.providers = [
          {
            name = "default";
            options.path = "/var/lib/grafana/dashboards";
          }
        ];
      };
    };
    
    # Prometheus for metrics collection
    services.prometheus = {
      enable = true;
      port = 9090;
      
      # Basic scrape configs
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "localhost:9100" ];
            }
          ];
        }
      ] ++ lib.optionals sslCheckerEnabled [
        {
          job_name = "blackbox_ssl";
          metrics_path = "/probe";
          params = {
            module = [ "https_ssl" ];
          };
          static_configs = [
            {
              targets = config.services.ssl-checker.domains;
              labels = {
                job = "ssl";
              };
            }
          ];
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              target_label = "__address__";
              replacement = "localhost:9115"; # Blackbox exporter address
            }
          ];
        }
      ];
      
      # SSL certificate expiration alerts
      rules = lib.optionals sslCheckerEnabled [
        {
          groups = [{
            name = "ssl";
            rules = [{
              alert = "SSLCertificateExpiringSoon";
              expr = "probe_ssl_earliest_cert_expiry - time() < ${toString (config.services.ssl-checker.alertThresholdDays * 24 * 60 * 60)}";
              for = "10m";
              labels = {
                severity = "warning";
              };
              annotations = {
                summary = "SSL certificate expiring soon for {{ $labels.instance }}";
                description = "SSL certificate for {{ $labels.instance }} expires in less than ${toString config.services.ssl-checker.alertThresholdDays} days.";
              };
            }];
          }];
        }
      ];
    };
    
    # Node exporter for system metrics
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [ "systemd" ];
      port = 9100;
    };
    
    # Blackbox exporter for SSL certificate checks
    services.prometheus.exporters.blackbox = lib.mkIf sslCheckerEnabled {
      enable = true;
      configFile = pkgs.writeText "blackbox-exporter.yml" ''
        modules:
          http_2xx:
            prober: http
            timeout: 5s
            http:
              method: GET
              preferred_ip_protocol: "ip4"
              tls_config:
                insecure_skip_verify: false
          
          https_ssl:
            prober: http
            timeout: 5s
            http:
              method: GET
              preferred_ip_protocol: "ip4"
              fail_if_ssl: false
              fail_if_not_ssl: true
              tls_config:
                insecure_skip_verify: false
      '';
    };
    
    # Systemd timer for website availability checks
    systemd.services.website-availability-check = lib.mkIf sslCheckerEnabled {
      description = "Check website availability";
      script = ''
        ${pkgs.curl}/bin/curl -s --fail --max-time 10 \
          ${concatStringsSep " " (map (domain: "https://${domain}") config.services.ssl-checker.domains)} \
          > /dev/null || echo "Website check failed at $(date)" >> /var/log/website-check.log
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "nobody";
      };
    };
    
    systemd.timers.website-availability-check = lib.mkIf sslCheckerEnabled {
      description = "Timer for website availability check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = config.services.ssl-checker.checkInterval;
      };
    };
    
    # Firewall settings
    networking.firewall.allowedTCPPorts = [ 
      config.services.grafana.port 
      config.services.prometheus.port
    ];
    
    # Create initial admin password file if it doesn't exist
    system.activationScripts.grafana-init = ''
      if [ ! -f /var/lib/grafana/admin_password ]; then
        mkdir -p /var/lib/grafana
        echo "admin" > /var/lib/grafana/admin_password
        chmod 600 /var/lib/grafana/admin_password
        chown grafana:grafana /var/lib/grafana/admin_password
      fi
    '';
  };
}
