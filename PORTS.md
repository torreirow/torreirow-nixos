# Port Mapping Overview

This document provides an overview of all ports in use on the Malandro server.

## Web Services (80xx range)

| Port | Service | Binding | Type | Description |
|------|---------|---------|------|-------------|
| 8080 | Vaultwarden | 127.0.0.1 | Native | Password manager (Bitwarden compatible) |
| 8081 | Baikal | 127.0.0.1 | Docker | CalDAV/CardDAV server |
| 8082 | Infcloud | 127.0.0.1 | Docker | Web calendar interface |
| 8083 | Erugo | 127.0.0.1 | Docker | Task management |
| 8084 | Pi-hole FTL | 0.0.0.0 | Native | DNS and ad-blocking web interface |
| 8085 | IT-Tools | 0.0.0.0 | Docker | Developer tools collection |
| 8086 | Zigbee2MQTT | 127.0.0.1 | Docker | Zigbee bridge web interface |
| 8123 | Home Assistant | 0.0.0.0 | Docker | Home automation platform |
| 8181 | Paperless | 0.0.0.0 | Docker | Document management system |

## Monitoring & Management (90xx range)

| Port | Service | Binding | Type | Description |
|------|---------|---------|------|-------------|
| 9001 | Mosquitto | 0.0.0.0 | Docker | MQTT WebSocket interface |
| 9090 | Prometheus | 0.0.0.0 | Native | Metrics collection and monitoring |
| 9091 | Authelia | 127.0.0.1 | Native | Single sign-on authentication |
| 9093 | Alertmanager | 0.0.0.0 | Native | Alert management (main) |
| 9094 | Alertmanager | 0.0.0.0 | Native | Alert management (cluster) |

## Network Services

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 1883 | Mosquitto | TCP | MQTT broker |
| 51820 | WireGuard | UDP | VPN service |
| 51821 | wg-easy | TCP | WireGuard management web interface |

## Standard Services

| Port | Service | Description |
|------|---------|-------------|
| 22 | SSH | Secure shell access |
| 80 | Nginx | HTTP (redirects to HTTPS) |
| 443 | Nginx | HTTPS reverse proxy |
| 111 | NFS/RPC | NFS port mapper |
| 2049 | NFS | Network File System |
| 5353 | mDNS/Avahi | Service discovery (Spotify Connect) |
| 57621 | Spotify | Local track sync |

## Reverse Proxy Domains (via Nginx on 443)

All these services are accessible via HTTPS through Nginx reverse proxy with Authelia authentication:

- `homeassistant.toorren.net` → Home Assistant (8123)
- `zigbee.toorren.net` → Zigbee2MQTT (8086)
- `wg.toorren.net` → wg-easy (51821)
- `auth.toorren.net` → Authelia (9091)
- `agenda.toorren.net` → Magister Sync
- *(Add other domains as configured in nginx modules)*

## Notes

- **127.0.0.1** binding means the service is only accessible locally (via reverse proxy)
- **0.0.0.0** binding means the service is accessible from the network
- All web services behind Nginx use HTTPS with Let's Encrypt certificates
- Most services require Authelia authentication when accessed via HTTPS

## Port Selection Strategy

When adding new services:
- Use **80xx** range for web interfaces
- Use **90xx** range for monitoring/management tools
- Check this document and update it when adding new services
- Prefer 127.0.0.1 binding with Nginx reverse proxy for security

## Quick Check Commands

Check which ports are in use:
```bash
sudo ss -tulpn | grep -E ":(80|90)[0-9]{2}" | sort -t: -k2 -n
```

List Docker containers with ports:
```bash
sudo docker ps --format "table {{.Names}}\t{{.Ports}}"
```
