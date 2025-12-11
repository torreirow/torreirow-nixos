{ ... }:
{
  imports = [
    ./prometheus
    ./grafana
  ];
    services.vulnix-exporter.enable = true;
    services.vulnix-exporter.port = 9109;
    services.vulnix-exporter.interval = "monthly";  # of "1M"
}
