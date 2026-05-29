{ ... }:

{
  # Lokale Docker pull-through registry mirror
  # Cached Docker Hub images lokaal zodat:
  # 1. Images beschikbaar blijven na stroomstoring (geen re-download nodig)
  # 2. Docker Hub rate limits niet meer van toepassing zijn
  virtualisation.oci-containers.containers.registry-mirror = {
    image = "registry:2";
    ports = [ "127.0.0.1:5000:5000" ];
    volumes = [ "/data/external/registry-mirror:/var/lib/registry" ];
    environment = {
      REGISTRY_PROXY_REMOTEURL = "https://registry-1.docker.io";
    };
  };

  # Configureer Docker om de lokale mirror te gebruiken
  virtualisation.docker.daemon.settings = {
    "registry-mirrors" = [ "http://localhost:5000" ];
  };
}
