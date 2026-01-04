{ lib }:

{
  zone = "home.toorren.net";

  soa = {
    mname = "ns1.home.toorren.net.";
    rname = "hostmaster.toorren.net.";
    serial = 2026010401;
    refresh = 3600;
    retry = 600;
    expire = 1209600;
    minimum = 300;
  };

  ns = [
    "ns1.home.toorren.net."
    "ns2.home.toorren.net."
  ];

  records = [
    # Nameservers
    { name = "ns1"; type = "A"; value = "203.0.113.10"; }
    { name = "ns2"; type = "A"; value = "203.0.113.11"; }

    # Hosts
    { name = "@";   type = "A"; value = "203.0.113.20"; }
    { name = "gw";  type = "A"; value = "192.168.1.1"; } # split-horizon mogelijk
    { name = "nas"; type = "A"; value = "192.168.1.10"; }

    # Services
    { name = "ha"; type = "CNAME"; value = "nas.home.toorren.net."; }
  ];
}

}


