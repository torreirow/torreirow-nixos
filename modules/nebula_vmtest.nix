# VM-test voor modules/nebula.nix: drie VM's (malandro, lobos, mpenzi) met de echte module.
#
#   nix build .#checks.x86_64-linux.nebula -L
#
# Controleert het toegangsbeleid uit de hosts-tabel: ssh (22) en ICMP mogen tussen alle hosts;
# lobos komt bij RustDesk (21118) op mpenzi, malandro niet; malandro komt bij Immich-ML (3003) op
# lobos, mpenzi niet; en 21118/3003 staan op het gewone netwerk (de underlay) dicht. De
# certificaten zijn wegwerp, alleen voor deze test gemaakt.
{ pkgs, ... }:

let
  # Alleen testwaarden; nooit echte Nebula-sleutels in de store.
  pki = pkgs.runCommand "nebula-test-pki" { nativeBuildInputs = [ pkgs.nebula ]; } ''
    mkdir -p $out
    cd $out
    nebula-cert ca -name test-toorren
    nebula-cert sign -name malandro -ip 10.77.0.1/24
    nebula-cert sign -name lobos -ip 10.77.0.2/24
    nebula-cert sign -name mpenzi -ip 10.77.0.3/24
  '';

  node = name: { nodes, ... }: {
    imports = [ ./nebula.nix ];
    toorren.nebula = {
      enable = true;
      lighthouseEndpoints = [ "${nodes.malandro.networking.primaryIPAddress}:4242" ];
      pki = { ca = "${pki}/ca.crt"; cert = "${pki}/${name}.crt"; key = "${pki}/${name}.key"; };
    };
    environment.systemPackages = [ pkgs.netcat ];
  };
in
{
  name = "nebula";

  nodes = {
    malandro = {
      imports = [ (node "malandro") ];
      services.openssh.enable = true;
    };
    lobos = { pkgs, ... }: {
      imports = [ (node "lobos") ];
      # Staat in voor immich-machine-learning (modules/immich-ml.nix), luistert ook op 0.0.0.0.
      systemd.services.fake-immich-ml = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${pkgs.netcat}/bin/nc -lk 3003";
      };
      services.openssh.enable = true;
    };
    mpenzi = { pkgs, ... }: {
      imports = [ (node "mpenzi") ];
      services.openssh.enable = true;
      # Staat in voor de RustDesk-service: alleen een luisterende poort is nodig.
      systemd.services.fake-rustdesk = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = "${pkgs.netcat}/bin/nc -lk 21118";
      };
    };
  };

  testScript = { nodes, ... }: ''
    start_all()
    for m in (malandro, lobos, mpenzi):
        m.wait_for_unit("nebula@toorren.service")
    mpenzi.wait_for_unit("sshd.service")
    mpenzi.wait_for_open_port(21118)
    lobos.wait_for_open_port(3003)
    lobos.wait_for_unit("sshd.service")
    malandro.wait_for_unit("sshd.service")

    with subtest("mesh is opgebouwd: ICMP mag overal"):
        lobos.wait_until_succeeds("ping -c1 -W2 10.77.0.1", timeout=60)
        lobos.wait_until_succeeds("ping -c1 -W2 10.77.0.3", timeout=60)
        malandro.wait_until_succeeds("ping -c1 -W2 10.77.0.3", timeout=60)

    with subtest("ssh mag tussen alle mesh-hosts"):
        for src in (malandro, lobos, mpenzi):
            for ip in ("10.77.0.1", "10.77.0.2", "10.77.0.3"):
                src.succeed(f"nc -z -w5 {ip} 22")

    with subtest("lobos mag RustDesk op mpenzi, malandro niet"):
        lobos.succeed("nc -z -w5 10.77.0.3 21118")
        malandro.fail("nc -z -w5 10.77.0.3 21118")

    with subtest("malandro mag bij Immich-ML op lobos, mpenzi niet"):
        malandro.succeed("nc -z -w5 10.77.0.2 3003")
        mpenzi.fail("nc -z -w5 10.77.0.2 3003")

    with subtest("RustDesk en Immich-ML staan op de underlay dicht"):
        lobos.fail("nc -z -w5 ${nodes.mpenzi.networking.primaryIPAddress} 21118")
        malandro.fail("nc -z -w5 ${nodes.lobos.networking.primaryIPAddress} 3003")

    with subtest("lighthouse luistert op UDP 4242"):
        malandro.succeed("ss -uln | grep -q ':4242 '")
  '';
}
