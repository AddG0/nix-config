# Appended to upstream's main.py at build time, so socket, decky and
# _get_lan_ip resolve against that module rather than this file.
# ruff: noqa: F821
#
# Replaces upstream's {hostname}.local, which needs an mDNS responder on the
# phone scanning the QR code.
import fcntl
import struct

_ADVERTISED_HOST = ""  # baked in by the package when advertisedHost is set

_SKIP_IFACE = ("tun", "tap", "tailscale", "docker", "br-", "veth", "virbr")
_SIOCGIFADDR = 0x8915


def _iface_address(iface: str) -> str | None:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        packed = fcntl.ioctl(
            sock.fileno(), _SIOCGIFADDR, struct.pack("256s", iface[:15].encode())
        )
        return socket.inet_ntoa(packed[20:24])
    except OSError:
        return None
    finally:
        sock.close()


# Tunnels and bridges are skipped so a VPN holding the default route cannot win
# the lookup and hand out an address the phone has no route to.
def _lan_address() -> str:
    try:
        with open("/proc/net/route") as routes:
            next(routes)
            for line in routes:
                iface, destination = line.split()[:2]
                if destination != "00000000" or iface.startswith(_SKIP_IFACE):
                    continue
                address = _iface_address(iface)
                if address:
                    return address
        decky.logger.warning("No non-tunnel default route carries an address")
    except Exception:
        decky.logger.exception("LAN address lookup failed")
    return _get_lan_ip()


def _advertised_host() -> str:
    return _ADVERTISED_HOST or _lan_address()


def _san_arg(host: str) -> str:
    try:
        socket.inet_aton(host)
    except OSError:
        return f"subjectAltName=DNS:{host}"
    return f"subjectAltName=IP:{host}"
