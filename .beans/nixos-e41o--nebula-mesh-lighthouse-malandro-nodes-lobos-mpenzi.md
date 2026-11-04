---
# nixos-e41o
title: 'Nebula-mesh: lighthouse malandro, nodes lobos + mpenzi'
status: completed
type: task
priority: normal
created_at: 2026-11-04T16:26:56Z
updated_at: 2026-11-04T18:03:39Z
parent: nixos-54um
blocked_by:
    - nixos-nkux
---

Nebula-mesh, altijd aan, alleen eigen overlay-verkeer (raakt het gewone internet van Maaike niet).

- Subnet `10.77.0.0/24` (eerst controleren dat het niet botst met wg-easy/docker/paperless-netwerken):
  malandro `.1` (lighthouse), lobos `.2`, mpenzi `.3`.
- Gedeelde module `modules/nebula.nix` met `services.nebula.networks.<naam>`; per host isLighthouse/
  lighthouses/staticHostMap (publieke naam van malandro, poort UDP 4242).
- malandro: firewall UDP 4242 open.
- Certs/keys via agenix (`secrets/nebula-<host>.{crt,key}.age` + `ca.crt`), entries in `secrets/secrets.nix`.
  De .age-bestanden zelf maakt de gebruiker (handmatige bean); de config moet zonder evalueren/bouwen.
- Nebula-firewall: inbound ICMP overal; op mpenzi tcp 22 en 21118 alleen van host `lobos` (of group `admin`).


## Resultaat

modules/nebula.nix (10.77.0.0/24, lighthouse malandro), geïmporteerd op malandro/lobos/mpenzi; staat uit tot de .age-certs bestaan. VM-test checks.x86_64-linux.nebula geslaagd; malandro dry-build en lobos-eval geslaagd. OpenSpec: mpenzi-laptop.
