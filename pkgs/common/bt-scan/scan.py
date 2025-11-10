#!/usr/bin/env python3
"""Continuous BLE device scanner with live table"""
import asyncio
from datetime import datetime
from bleak import BleakScanner
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData
from rich.live import Live
from rich.table import Table
from rich.console import Console
import urllib.request
import json

console = Console()
devices_data = {}  # {mac: (name, rssi, last_seen, service_uuids)}
oui_cache = {}  # {oui: manufacturer}
device_colors = {}  # {mac: color}

# Color palette for devices (avoiding red/green which are used for signal strength)
COLORS = [
    "cyan", "magenta", "yellow", "blue",
    "bright_cyan", "bright_magenta", "bright_yellow", "bright_blue",
    "cyan1", "magenta1", "yellow1", "blue1",
    "cyan2", "magenta2", "yellow2", "blue2",
]
color_index = 0


def get_device_color(mac: str) -> str:
    """Get consistent color for a device"""
    global color_index
    if mac not in device_colors:
        device_colors[mac] = COLORS[color_index % len(COLORS)]
        color_index += 1
    return device_colors[mac]


def get_manufacturer(mac: str) -> str:
    """Get manufacturer from MAC address OUI lookup"""
    # Extract OUI (first 3 bytes)
    oui = mac[:8].replace(':', '').upper()

    if oui in oui_cache:
        return oui_cache[oui]

    try:
        # Query macaddress.io API (free tier allows lookups)
        url = f"https://api.macvendors.com/{mac}"
        with urllib.request.urlopen(url, timeout=2) as response:
            manufacturer = response.read().decode('utf-8').strip()
            oui_cache[oui] = manufacturer
            return manufacturer
    except:
        # Fallback: check if it's a random MAC (locally administered)
        first_byte = int(mac[:2], 16)
        if first_byte & 0x02:  # Bit 1 set = locally administered (random)
            oui_cache[oui] = "Random MAC"
            return "Random MAC"
        oui_cache[oui] = "Unknown"
        return "Unknown"


def create_table() -> Table:
    """Create a Rich table with current device data"""
    table = Table(title=f"🔵 BLE Devices (Live) - {datetime.now().strftime('%I:%M:%S %p')}")

    table.add_column("MAC Address", no_wrap=True)
    table.add_column("RSSI", justify="right", style="magenta")
    table.add_column("Signal", justify="center")
    table.add_column("Name")
    table.add_column("Service UUIDs", style="dim")
    table.add_column("Last Seen", justify="right", style="dim")

    # Sort by RSSI (strongest first)
    sorted_devices = sorted(
        devices_data.items(),
        key=lambda x: x[1][1] if x[1][1] is not None else -999,
        reverse=True
    )

    for mac, (name, rssi, last_seen, service_uuids) in sorted_devices:
        # Signal strength indicator
        if rssi is None:
            signal = "❓"
            rssi_str = "?"
        elif rssi >= -60:
            signal = "🟢"
            rssi_str = f"{rssi} dBm"
        elif rssi >= -75:
            signal = "🟡"
            rssi_str = f"{rssi} dBm"
        else:
            signal = "🔴"
            rssi_str = f"{rssi} dBm"

        # Time since last seen
        elapsed = (datetime.now() - last_seen).total_seconds()
        if elapsed < 1:
            last_seen_str = "now"
        elif elapsed < 60:
            last_seen_str = f"{int(elapsed)}s ago"
        else:
            last_seen_str = f"{int(elapsed/60)}m ago"

        # Get consistent color for this device
        color = get_device_color(mac)

        # Show manufacturer if no name
        if name:
            display_name = f"[{color}]{name}[/{color}]"
        else:
            manufacturer = get_manufacturer(mac)
            display_name = f"[{color} dim]{manufacturer}[/{color} dim]"

        # Format service UUIDs
        if service_uuids:
            # Show first UUID, or count if multiple
            if len(service_uuids) == 1:
                uuid_str = service_uuids[0]
            else:
                uuid_str = f"{service_uuids[0]} +{len(service_uuids)-1}"
        else:
            uuid_str = ""

        table.add_row(
            f"[{color}]{mac}[/{color}]",
            rssi_str,
            signal,
            display_name,
            uuid_str,
            last_seen_str
        )

    return table


def detection_callback(device: BLEDevice, advertisement: AdvertisementData):
    """Called whenever a device is detected"""
    devices_data[device.address] = (
        device.name,
        advertisement.rssi,
        datetime.now(),
        advertisement.service_uuids if advertisement.service_uuids else []
    )


async def main():
    """Main scanning loop"""
    console.print("[bold cyan]Starting continuous BLE scanner...[/bold cyan]")
    console.print("[dim]Press Ctrl+C to stop[/dim]\n")

    scanner = BleakScanner(detection_callback=detection_callback)
    await scanner.start()

    try:
        with Live(create_table(), refresh_per_second=2, console=console) as live:
            while True:
                await asyncio.sleep(0.5)
                live.update(create_table())
    except KeyboardInterrupt:
        console.print("\n[yellow]Stopping scanner...[/yellow]")
    finally:
        await scanner.stop()
        console.print(f"[green]Scanned {len(devices_data)} unique devices[/green]")


if __name__ == "__main__":
    asyncio.run(main())
