{config, lib, pkgs,  agenix, ... }:
{

age = {
  identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  secrets = {
#      loboskey = {
#        file = ../../secrets/loboskey.age;
#        path = "/tmp/loboskey";
#        owner = "wtoorren";
#        group = "wtoorren";
#        mode = "600";
#      };
ssh-hosts-customer-prod = {
  file = ../../secrets/ssh-hosts-customer-prod.json.age;
  path = "/run/secrets/ssh-hosts-customer-prod";
  owner = "wtoorren";
  mode = "0400";
};
spotifywto = {
  file = ../../secrets/spotifywto.age;
  path = "/home/wtoorren/.config/spotify/prefs";
  owner = "wtoorren";
  group = "nogroup";
  mode = "0400";
};
atticwto = {
  file = ../../secrets/atticwto.age;
  path = "/tmp/atticwto";
  owner = "wtoorren";
  group = "nogroup";
  mode = "0400";
};
aider = {
  file = ../../secrets/aider.age;
  owner = "wtoorren";
  group = "nogroup";
  mode = "0500";
};
update_latop = {
  file = ../../secrets/update_laptop.age;
  path = "/data/scripts/update_laptop.sh";
  owner = "wtoorren";
  group = "root";
  mode = "0550";
};
# Long-lived access token voor Home Assistant (malandro). Gebruikt door de
# home-manager-module notify-signal om faalmeldingen via notify.signal_maria te
# versturen. Expliciet `path` opgeven is vereist: zonder dat legt agenix de
# secret alleen in /run/keys/<owner>/ neer en ontstaat er geen symlink.
ha-token = {
  file = ../../secrets/ha-token.age;
  path = "/run/secrets/ha-token";
  owner = "wtoorren";
  mode = "0400";
};
kar01_vpn_lobos = {
  file = ../../secrets/kar01-lobos-ovpn.age;
  path = "/data/agenix/kar01-lobos.ovpn";
  owner = "wtoorren";
  group = "nogroup";
  mode = "0400";
};

# WireGuard secrets
wg-toorren-private-key = {
  file = ../../secrets/wg-toorren-private-key.age;
  mode = "0400";
  owner = "root";
};
wg-toorren-preshared-key = {
  file = ../../secrets/wg-toorren-preshared-key.age;
  mode = "0400";
  owner = "root";
};
wg-tn_arkana-private-key = {
  file = ../../secrets/wg-tn_arkana-private-key.age;
  mode = "0400";
  owner = "root";
};
};
  };


}
