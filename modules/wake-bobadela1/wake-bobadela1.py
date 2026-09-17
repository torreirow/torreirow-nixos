#!/usr/bin/env python3
"""Wek bobadela1 (Nextcloud AIO) via Wake-on-LAN en wacht tot Nextcloud gezond is.

bobadela1 gaat elke avond 23:00 uit (een koude start werkt betrouwbaarder dan een
warme reboot). Deze wekker draait op de altijd-aan host malandro.

Gebruik:
  wake-bobadela1                                    # één burst, direct terug (handmatig)
  wake-bobadela1 --wait 1800 --burst 300 \\
                 --check-nextcloud --notify         # service-modus (30 min, burst/5 min)

Exitcodes: 0 = gezond, 1 = host kwam niet op, 2 = host op maar Nextcloud niet gezond.
"""
import argparse
import json
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

MAC = "b8:ac:6f:c7:20:c6"
BROADCAST = "192.168.2.255"
HOST = "192.168.2.67"
PORTS = (7, 9)
NEXTCLOUD_PORT = 11000  # AIO apache; status.php volgt het --host-adres

# Zelfde afzender/ontvanger als rustic-notify@ en HA signal_maria.
SIGNAL_API = "http://127.0.0.1:8088/v2/send"
SIGNAL_SENDER = "+31612652352"
SIGNAL_RECIPIENT = "+31636201589"

POLL_INTERVAL = 5  # seconden tussen ping/health-checks


def send_wol(mac, broadcast, repeat=3):
    """Verstuur magic packets op alle WoL-poorten; geeft het aantal terug."""
    payload = b"\xff" * 6 + bytes.fromhex(mac.replace(":", "").replace("-", "")) * 16
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sent = 0
    for port in PORTS:
        for _ in range(repeat):
            sock.sendto(payload, (broadcast, port))
            sent += 1
    sock.close()
    return sent


def is_up(host):
    """True als de host op ICMP-ping reageert (vereist ping op PATH)."""
    return subprocess.run(
        ["ping", "-c1", "-W2", host],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0


def nextcloud_healthy(url):
    """True als status.php HTTP 200 geeft met installed=true en maintenance=false."""
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            if resp.status != 200:
                return False
            data = json.load(resp)
    except (urllib.error.URLError, OSError, ValueError):
        return False
    return data.get("installed") is True and data.get("maintenance") is False


def signal_send(message):
    """Best-effort Signal-melding; faalt stil zodat de exitcode ongewijzigd blijft."""
    payload = json.dumps(
        {"message": message, "number": SIGNAL_SENDER, "recipients": [SIGNAL_RECIPIENT]}
    ).encode()
    req = urllib.request.Request(
        SIGNAL_API, data=payload,
        headers={"Content-Type": "application/json"}, method="POST",
    )
    try:
        urllib.request.urlopen(req, timeout=30).close()
    except (urllib.error.URLError, OSError):
        pass


def main():
    p = argparse.ArgumentParser(description="Wek bobadela1 via Wake-on-LAN.")
    p.add_argument("--mac", default=MAC, help=f"MAC-adres (standaard {MAC})")
    p.add_argument("--broadcast", default=BROADCAST,
                   help=f"broadcastadres (standaard {BROADCAST})")
    p.add_argument("--host", default=HOST, help=f"IP om op te pollen (standaard {HOST})")
    p.add_argument("--wait", type=int, metavar="SEC", default=0,
                   help="blijf maximaal SEC seconden proberen (0 = één burst en terug)")
    p.add_argument("--burst", type=int, metavar="SEC", default=300,
                   help="stuur elke SEC seconden een nieuwe WoL-burst zolang de host "
                        "niet reageert (standaard 300)")
    p.add_argument("--check-nextcloud", action="store_true",
                   help="pas tevreden als Nextcloud status.php gezond antwoordt")
    p.add_argument("--notify", action="store_true",
                   help="stuur een Signal-melding bij mislukking")
    args = p.parse_args()

    nc_url = f"http://{args.host}:{NEXTCLOUD_PORT}/status.php"

    def healthy():
        if not is_up(args.host):
            return False
        return nextcloud_healthy(nc_url) if args.check_nextcloud else True

    # Al gezond? Dan is er niets te doen (idempotent).
    if healthy():
        print(f"{args.host} is al gezond; geen wake nodig.")
        return 0

    # Alleen wekken als de host echt uit is.
    if not is_up(args.host):
        n = send_wol(args.mac, args.broadcast)
        print(f"{n} magic packets naar {args.mac} via {args.broadcast} "
              f"(poort {', '.join(map(str, PORTS))})")

    if args.wait <= 0:
        return 0

    start = time.time()
    deadline = start + args.wait
    next_burst = start + args.burst
    host_seen = is_up(args.host)

    while time.time() < deadline:
        if is_up(args.host):
            host_seen = True
            if not args.check_nextcloud or nextcloud_healthy(nc_url):
                print(f"{args.host} gezond na {int(time.time() - start)}s")
                return 0
        elif time.time() >= next_burst:
            # Eén burst kan door de NIC gemist worden vlak na S5; blijf herhalen.
            send_wol(args.mac, args.broadcast)
            print(f"herhaal-burst naar {args.mac} na {int(time.time() - start)}s")
            next_burst += args.burst
        time.sleep(POLL_INTERVAL)

    dur = f"{args.wait // 60} min" if args.wait >= 60 else f"{args.wait}s"
    if not host_seen:
        msg = (f"⚠️ bobadela1 kwam niet op na {dur} Wake-on-LAN-pogingen "
               f"(geen ping op {args.host}). Handmatig checken.")
        code = 1
    else:
        msg = (f"⚠️ bobadela1 is op ({args.host} pingt) maar Nextcloud werd niet "
               f"gezond binnen {dur} (status.php). Handmatig checken.")
        code = 2

    print(msg, file=sys.stderr)
    if args.notify:
        signal_send(msg)
    return code


if __name__ == "__main__":
    sys.exit(main())
