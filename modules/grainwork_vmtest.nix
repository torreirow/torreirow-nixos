# VM-test voor modules/grainwork.nix: nginx + Pocket ID + oauth2-proxy echt opgestart.
#
#   nix build .#checks.x86_64-linux.grainwork -L
#
# Controleert dat de site zonder login nergens bereikbaar is behalve /welkom/ en de statische
# assets, dat oauth2-proxy via OIDC-discovery naar Pocket ID doorverwijst, en dat het
# setup-slot Pocket ID afschermt voor andere netwerken. Een echte passkey-login kan een VM-test
# niet doen; die staat als handmatige stap in de go-live.
{ pkgs, ... }:

let
  # Alleen testwaarden; nooit echte secrets in de store.
  encryptionKey = pkgs.writeText "pocket-id-encryption-key" "SUeAyRRFZ1uf03ClOE+o++BVENSE/Ptb9YFRF2Sk+zM=";
  clientEnv = pkgs.writeText "oauth2-proxy-client" ''
    OAUTH2_PROXY_CLIENT_ID=grainwork-test
    OAUTH2_PROXY_CLIENT_SECRET=test-secret
  '';
  # oauth2-proxy leest een cookie secret uit een bestand als ruwe bytes: precies 16, 24 of 32.
  cookieSecret = pkgs.writeText "oauth2-proxy-cookie" "0123456789abcdef0123456789abcdef";

  site = pkgs.runCommand "grainwork-site" { } ''
    mkdir -p $out/welkom $out/css $out/studies/nehemia
    echo "GEHEIME-STUDIE-INHOUD" > $out/index.html
    echo "WELKOM-UITLEG" > $out/welkom/index.html
    echo "body{}" > $out/css/custom.css
    echo "body{}" > $out/style.main.min.abc123.css
    echo "SESSIE-INHOUD" > $out/studies/nehemia/index.html
  '';

  hosts = ip: {
    "${ip}" = [ "grainwork.dutchyland.net" "id.dutchyland.net" ];
  };
in
{
  name = "grainwork";

  nodes = {
    server = { nodes, ... }: {
      imports = [ ./grainwork.nix ];

      services.grainwork = {
        enable = true;
        acmeHost = null;
        agenix = false;
        pocketId = {
          enable = true;
          encryptionKeyFile = encryptionKey;
          # Alleen de server zelf; de client hoort geweigerd te worden.
          allowedNetworks = [ "127.0.0.1" ];
        };
        site = {
          enable = true;
          root = "${site}";
          clientEnvFile = clientEnv;
          cookieSecretFile = cookieSecret;
        };
      };

      services.nginx.enable = true;
      networking.firewall.allowedTCPPorts = [ 80 ];
      networking.hosts = hosts "127.0.0.1";
      environment.systemPackages = [ pkgs.curl ];
    };

    client = { nodes, ... }: {
      networking.hosts = hosts nodes.server.networking.primaryIPAddress;
      environment.systemPackages = [ pkgs.curl ];
    };
  };

  testScript = ''
    def status(machine, url):
        return machine.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' {url}").strip()

    def location(machine, url):
        return machine.succeed(f"curl -s -o /dev/null -w '%{{redirect_url}}' {url}").strip()

    start_all()
    server.wait_for_unit("pocket-id.service")
    server.wait_for_open_port(8098)
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(80)

    with subtest("Pocket ID luistert alleen op loopback"):
        listeners = server.succeed("ss -ltnH 'sport = :8098'")
        assert "127.0.0.1:8098" in listeners, listeners
        assert "*:8098" not in listeners and "0.0.0.0:8098" not in listeners, listeners

    with subtest("herstelcommando bereikt de database"):
        out = server.fail("grainwork-login-link bestaat-niet@example.invalid 2>&1")
        assert "user not found" in out, out
        server.fail("grainwork-login-link")  # zonder argument: gebruiksmelding

    with subtest("Pocket ID werkt via nginx vanaf de server zelf"):
        assert status(server, "http://id.dutchyland.net/") == "200"
        server.succeed("curl -sf http://id.dutchyland.net/.well-known/openid-configuration | grep -q '\"issuer\":\"http://id.dutchyland.net\"'")

    # oauth2-proxy doet bij het starten OIDC-discovery; dat kan pas als Pocket ID antwoordt.
    try:
        server.wait_until_succeeds("systemctl is-active oauth2-proxy.service", timeout=120)
    except Exception:
        print(server.execute("journalctl -u oauth2-proxy.service --no-pager | tail -n 30")[1])
        raise
    server.wait_for_open_port(8099)

    client.wait_for_unit("multi-user.target")

    with subtest("setup-slot: Pocket ID geweigerd vanaf een ander netwerk"):
        assert status(client, "http://id.dutchyland.net/") == "403"
        assert status(client, "http://id.dutchyland.net/setup") == "403"

    with subtest("site zonder login: doorverwijzing naar de login"):
        for path in ["/", "/studies/nehemia/", "/index.html"]:
            code = status(client, f"http://grainwork.dutchyland.net{path}")
            assert code == "307", f"{path}: {code}"
            assert location(client, f"http://grainwork.dutchyland.net{path}").startswith(
                "https://grainwork.dutchyland.net/oauth2/start?rd="), path
        body = client.succeed("curl -s http://grainwork.dutchyland.net/ http://grainwork.dutchyland.net/studies/nehemia/")
        assert "GEHEIME-STUDIE-INHOUD" not in body and "SESSIE-INHOUD" not in body

    with subtest("welkomstpagina en assets zonder login"):
        assert "WELKOM-UITLEG" in client.succeed("curl -sf http://grainwork.dutchyland.net/welkom/")
        assert status(client, "http://grainwork.dutchyland.net/css/custom.css") == "200"
        assert status(client, "http://grainwork.dutchyland.net/style.main.min.abc123.css") == "200"

    with subtest("oauth2-proxy stuurt door naar Pocket ID (OIDC-discovery gelukt)"):
        target = location(client, "http://grainwork.dutchyland.net/oauth2/start?rd=/")
        assert target.startswith("http://id.dutchyland.net/authorize?"), target
        assert "client_id=grainwork-test" in target, target
        assert "groups" in target, target
        assert "code_challenge_method=S256" in target, target
        assert "offline_access" in target, target
        assert "approval_prompt=auto" in target, target

    with subtest("uitloggen: cookie gewist en door naar Pocket ID"):
        headers = client.succeed(
            "curl -s -D - -o /dev/null --cookie '_grainwork=oud' "
            "'http://grainwork.dutchyland.net/oauth2/sign_out?rd=http%3A%2F%2Fid.dutchyland.net%2Fapi%2Foidc%2Fend-session'")
        assert "location: http://id.dutchyland.net/api/oidc/end-session" in headers.lower(), headers
        assert "set-cookie: _grainwork=;" in headers.lower(), headers
        # Een ander domein blijft geweigerd (geen open redirect).
        other = location(client, "'http://grainwork.dutchyland.net/oauth2/sign_out?rd=https%3A%2F%2Fevil.example%2F'")
        assert "evil.example" not in other, other
  '';
}
