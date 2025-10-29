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
            jsonData = {
              timeInterval = "5s";
              queryTimeout = "120s";
              httpMethod = "POST";
              manageAlerts = true;
            };
          }
        ];
        
        dashboards = {
          settings.providers = [
            {
              name = "default";
              options = {
                path = "/var/lib/grafana/dashboards";
                foldersFromFilesStructure = true;
              };
              allowUiUpdates = true;
            }
          ];
        };
      };
      
      # Additional Grafana settings
      settings = {
        security = {
          admin_user = "admin";
          admin_password = "$__file{/var/lib/grafana/admin_password}";
        };
        
        server = {
          root_url = "%(protocol)s://%(domain)s:%(http_port)s/";
          serve_from_sub_path = true;
        };
        
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
        };
        
        alerting = {
          enabled = true;
          execute_alerts = true;
          error_or_timeout = "alerting";
          nodata_or_nullvalues = "alerting";
          evaluation_timeout_seconds = 30;
          notification_timeout_seconds = 30;
          max_attempts = 3;
        };
        
        unified_alerting = {
          enabled = true;
        };
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
      9100  # Node exporter
      9115  # Blackbox exporter
    ];
    
    # Add SSL certificate monitoring dashboard
    services.grafana.provision.dashboards.settings.providers = [{
      name = "ssl-monitoring";
      options = {
        path = "/var/lib/grafana/dashboards";
      };
    }];
    
    # Create initial admin password file and dashboard directory
    system.activationScripts.grafana-init = ''
      if [ ! -f /var/lib/grafana/admin_password ]; then
        mkdir -p /var/lib/grafana
        echo "admin" > /var/lib/grafana/admin_password
        chmod 600 /var/lib/grafana/admin_password
        chown grafana:grafana /var/lib/grafana/admin_password
      fi
      
      # Create dashboards directory
      mkdir -p /var/lib/grafana/dashboards
      
      # Create a basic system monitoring dashboard
      cat > /var/lib/grafana/dashboards/system-monitoring.json << 'EOF'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.4.0",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "interval": "",
          "legendFormat": "CPU Usage",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "CPU Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "percent",
          "label": null,
          "logBase": 1,
          "max": "100",
          "min": "0",
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 4,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.4.0",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "node_memory_MemTotal_bytes - node_memory_MemFree_bytes - node_memory_Buffers_bytes - node_memory_Cached_bytes",
          "interval": "",
          "legendFormat": "Used Memory",
          "refId": "A"
        },
        {
          "expr": "node_memory_MemTotal_bytes",
          "interval": "",
          "legendFormat": "Total Memory",
          "refId": "B"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Memory Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "bytes",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": "0",
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 8
      },
      "hiddenSeries": false,
      "id": 6,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.4.0",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "node_filesystem_avail_bytes{mountpoint=\"/\"}",
          "interval": "",
          "legendFormat": "Available Disk Space",
          "refId": "A"
        },
        {
          "expr": "node_filesystem_size_bytes{mountpoint=\"/\"}",
          "interval": "",
          "legendFormat": "Total Disk Space",
          "refId": "B"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Disk Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "bytes",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": "0",
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "description": "",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 8
      },
      "hiddenSeries": false,
      "id": 8,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.4.0",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "probe_ssl_earliest_cert_expiry - time()",
          "interval": "",
          "legendFormat": "{{instance}} - Days until expiry",
          "refId": "A"
        }
      ],
      "thresholds": [
        {
          "colorMode": "critical",
          "fill": true,
          "line": true,
          "op": "lt",
          "value": 2592000,
          "visible": true
        }
      ],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "SSL Certificate Expiry",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "s",
          "label": "Time until expiry",
          "logBase": 1,
          "max": null,
          "min": "0",
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "refresh": "5s",
  "schemaVersion": 27,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "System Monitoring",
  "uid": "system-monitoring",
  "version": 1
}
EOF
      
      # Set proper permissions
      chown -R grafana:grafana /var/lib/grafana/dashboards
    '';
  };
}
