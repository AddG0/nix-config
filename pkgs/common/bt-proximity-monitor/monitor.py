#!/usr/bin/env python3
"""
Bluetooth Proximity Monitor with Continuous Scanning
Uses always-on passive scanning with callbacks - never misses advertisements!
"""

import asyncio
import logging
import subprocess
import sys
from collections import deque
from enum import Enum, auto
from pathlib import Path
from statistics import mean
from typing import Optional, List

from bleak import BleakScanner
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData
from bleak.backends.bluezdbus.manager import get_global_bluez_manager
from bleak.exc import BleakError
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class LockState(Enum):
    """Session lock states"""
    UNLOCKED = auto()
    LOCKED = auto()


class Settings(BaseSettings):
    """Configuration from environment variables"""
    model_config = SettingsConfigDict(env_prefix='BT_')

    device_mac_address: Optional[str] = None
    device_mac_address_file: Optional[Path] = None
    device_name: Optional[str] = None
    device_name_file: Optional[Path] = None
    device_service_uuid: Optional[str] = None
    device_service_uuid_file: Optional[Path] = None

    lock_cmd: str = "loginctl lock-session"
    unlock_cmd: str = "loginctl unlock-session"

    # Timing
    proximity_timeout: float = 20.0   # Grace period before lock

    # RSSI thresholds
    lock_threshold: int = -75
    unlock_threshold: int = -68

    # RSSI averaging
    rssi_samples: int = 2  # Small buffer for slow advertisers (2 × 10s = 20s max)

    @model_validator(mode='after')
    def load_from_files_and_validate(self) -> 'Settings':
        """Load device identification from files if file paths are set"""
        # Load MAC address from file
        if self.device_mac_address is None and self.device_mac_address_file is not None:
            if not self.device_mac_address_file.exists():
                logger.error(f"Device MAC address file not found: {self.device_mac_address_file}")
                sys.exit(1)
            self.device_mac_address = self.device_mac_address_file.read_text().strip()

        # Load device name from file
        if self.device_name is None and self.device_name_file is not None:
            if not self.device_name_file.exists():
                logger.error(f"Device name file not found: {self.device_name_file}")
                sys.exit(1)
            self.device_name = self.device_name_file.read_text().strip()

        # Load service UUID from file
        if self.device_service_uuid is None and self.device_service_uuid_file is not None:
            if not self.device_service_uuid_file.exists():
                logger.error(f"Device service UUID file not found: {self.device_service_uuid_file}")
                sys.exit(1)
            self.device_service_uuid = self.device_service_uuid_file.read_text().strip()

        # Require at least one identification method
        if not any([self.device_mac_address, self.device_name, self.device_service_uuid]):
            logger.error("No device identification specified. Set at least one of:")
            logger.error("  BT_DEVICE_MAC_ADDRESS (MAC address)")
            logger.error("  BT_DEVICE_MAC_ADDRESS_FILE (path to file with MAC address)")
            logger.error("  BT_DEVICE_NAME (device name)")
            logger.error("  BT_DEVICE_NAME_FILE (path to file with device name)")
            logger.error("  BT_DEVICE_SERVICE_UUID (service UUID - most reliable)")
            logger.error("  BT_DEVICE_SERVICE_UUID_FILE (path to file with service UUID)")
            sys.exit(1)

        return self


class RSSITracker:
    """Tracks RSSI values and provides averaging"""

    def __init__(self, max_samples: int):
        self.samples: deque[int] = deque(maxlen=max_samples)

    def add_sample(self, rssi: int) -> None:
        """Add new RSSI sample - immediate on stronger signal, averaged on weaker signal"""
        # If signal is stronger (more positive/less negative), use immediately for faster unlocking
        if self.samples:
            current_avg = self.get_averaged_rssi()
            if current_avg is not None and rssi > current_avg:
                logger.info(f"Stronger signal detected ({current_avg} → {rssi} dBm), using immediately")
                self.samples.clear()

        self.samples.append(rssi)

    def get_averaged_rssi(self) -> Optional[int]:
        """Get averaged RSSI from recent samples"""
        if not self.samples:
            return None
        return int(mean(self.samples))

    def clear(self) -> None:
        """Clear all samples"""
        self.samples.clear()


class ContinuousScanner:
    """Runs BLE scanner continuously with callback"""

    def __init__(
        self,
        rssi_tracker: RSSITracker,
        state_machine: 'ProximityStateMachine',
        timers: 'TimerManager',
        settings: 'Settings'
    ):
        self.rssi_tracker = rssi_tracker
        self.state_machine = state_machine
        self.timers = timers
        self.settings = settings
        self.scanner: Optional[BleakScanner] = None
        self._running = False
        self._watchdog_task: Optional[asyncio.Task] = None
        self._detected_device_address: Optional[str] = None  # Store matched device address

    async def _check_adapter_available(self) -> bool:
        """Check if a powered Bluetooth adapter is available"""
        try:
            manager = await get_global_bluez_manager()
            manager.get_default_adapter()
            return True
        except BleakError:
            return False

    async def _adapter_watchdog(self) -> None:
        """Monitor adapter availability and signal if adapter disappears"""
        while self._running:
            await asyncio.sleep(5)  # Check every 5 seconds
            if not await self._check_adapter_available():
                logger.warning("⚠️  Bluetooth adapter became unavailable")
                self._running = False
                break

    async def start(self) -> bool:
        """Start continuous scanning. Returns True on success, False if BT unavailable"""
        if self._running:
            return True

        # Log startup configuration (only on first attempt)
        if not hasattr(self, '_config_logged'):
            logger.info("=== Bluetooth Proximity Monitor ===")

            # Show all configured identification methods
            if self.settings.device_mac_address:
                logger.info(f"Device MAC: {self.settings.device_mac_address}")
            if self.settings.device_name:
                logger.info(f"Device Name: {self.settings.device_name}")
            if self.settings.device_service_uuid:
                logger.info(f"Service UUID: {self.settings.device_service_uuid}")

            logger.info(f"Lock threshold: {self.settings.lock_threshold} dBm")
            logger.info(f"Unlock threshold: {self.settings.unlock_threshold} dBm")
            logger.info(f"RSSI averaging: {self.settings.rssi_samples} samples")
            logger.info(f"Proximity timeout: {self.settings.proximity_timeout}s")
            logger.info("=" * 36)
            self._config_logged = True

        # Check if adapter is available before attempting to start
        if not await self._check_adapter_available():
            logger.warning("⚠️  Bluetooth adapter is disabled or not available")
            logger.warning("Waiting for Bluetooth to become available...")
            return False

        logger.info(f"Starting continuous BLE scanner...")

        try:
            self.scanner = BleakScanner(detection_callback=self._detection_callback)
            await self.scanner.start()
            self._running = True

            # Give scanner time to initialize
            await asyncio.sleep(0.5)
            logger.info("Scanner started successfully")

            # Start initial lock timer (will lock if device never detected)
            self._start_lock_timer()

            # Start watchdog to monitor adapter availability
            self._watchdog_task = asyncio.create_task(self._adapter_watchdog())

            return True
        except BleakError as e:
            logger.warning(f"⚠️  Failed to start scanner: {e}")
            self.scanner = None  # Clean up on failure
            return False

    async def stop(self) -> None:
        """Stop scanning"""
        if not self._running and not self.scanner:
            return

        logger.info("Stopping scanner...")
        self._running = False

        # Cancel watchdog
        if self._watchdog_task and not self._watchdog_task.done():
            self._watchdog_task.cancel()
            try:
                await self._watchdog_task
            except asyncio.CancelledError:
                pass

        # Stop scanner
        if self.scanner:
            try:
                await self.scanner.stop()
            except Exception as e:
                logger.debug(f"Error stopping scanner: {e}")
            finally:
                self.scanner = None

        logger.info("Scanner stopped")

    async def run(self) -> None:
        """Run the monitor (event-driven with auto-restart on BT disconnect)"""
        try:
            while True:
                # Try to start scanner (with retry if BT unavailable)
                while True:
                    success = await self.start()
                    if success:
                        break
                    # Wait 10 seconds before retrying if BT is unavailable
                    await asyncio.sleep(10)

                # Scanner running - wait for it to stop (either gracefully or from watchdog)
                while self._running:
                    await asyncio.sleep(1)

                # Scanner stopped (BT went down) - clean up and retry
                logger.info("Scanner stopped, will retry in 10 seconds...")
                await self.stop()
                await asyncio.sleep(10)

        except Exception as e:
            logger.error(f"Monitor error: {e}", exc_info=True)
        finally:
            await self.stop()

    def _matches_device(self, device: BLEDevice, advertisement: AdvertisementData) -> bool:
        """Check if device matches ALL configured identification criteria (AND logic)"""
        # Method 1: Match by MAC address (if configured, must match)
        if self.settings.device_mac_address:
            if device.address.upper() != self.settings.device_mac_address.upper():
                return False

        # Method 2: Match by device name (if configured, must match)
        if self.settings.device_name:
            if not device.name or device.name != self.settings.device_name:
                return False

        # Method 3: Match by service UUID (if configured, must match)
        if self.settings.device_service_uuid:
            service_uuid = self.settings.device_service_uuid.lower()
            if not advertisement.service_uuids:
                return False
            # Check if any advertised service UUID matches
            if service_uuid not in [uuid.lower() for uuid in advertisement.service_uuids]:
                return False

        # All configured criteria matched
        return True

    def _detection_callback(self, device: BLEDevice, advertisement: AdvertisementData) -> None:
        """Called whenever a BLE advertisement is detected"""
        if not self._matches_device(device, advertisement):
            return

        # Store detected device address for logging
        if not self._detected_device_address:
            self._detected_device_address = device.address
            match_method = []
            if self.settings.device_mac_address and device.address.upper() == self.settings.device_mac_address.upper():
                match_method.append("MAC")
            if self.settings.device_name and device.name:
                match_method.append("Name")
            if self.settings.device_service_uuid:
                match_method.append("Service UUID")
            logger.info(f"✓ Device matched via: {', '.join(match_method)}")
            logger.info(f"  Address: {device.address}")
            if device.name:
                logger.info(f"  Name: {device.name}")

        rssi = advertisement.rssi

        # Filter out invalid RSSI sentinel values
        # -127 is commonly sent when Bluetooth is disconnecting/disabled
        if rssi <= -127:
            logger.debug(f"Ignoring invalid RSSI value: {rssi} dBm (likely BT disconnect)")
            return

        self.rssi_tracker.add_sample(rssi)
        avg_rssi = self.rssi_tracker.get_averaged_rssi()
        logger.info(f"Device detected: RSSI {rssi} dBm (avg: {avg_rssi} dBm)")
        self._handle_detection(rssi)

    def _handle_detection(self, rssi: int) -> None:
        """Handle device detection - purely event-driven"""
        # Get averaged RSSI
        avg_rssi = self.rssi_tracker.get_averaged_rssi()
        if avg_rssi is None:
            return

        # Check if we should unlock (locked + strong signal)
        if self.state_machine.state != LockState.UNLOCKED and avg_rssi >= self.settings.unlock_threshold:
            # Good signal - cancel lock timer and unlock
            self.timers.cancel("lock")
            self.state_machine.unlock(f"Device nearby (RSSI: {avg_rssi} dBm)")

        # Check if we should start lock timer (unlocked + weak signal)
        elif self.state_machine.state == LockState.UNLOCKED and avg_rssi <= self.settings.lock_threshold:
            # Weak signal - start timer only if not already running
            if not self.timers.is_running("lock"):
                self._start_lock_timer()
                logger.info(f"Weak signal (avg: {avg_rssi} dBm ≤ {self.settings.lock_threshold} dBm), starting {self.settings.proximity_timeout:.0f}s lock timer")
            else:
                # Weak signal persists - lock immediately (no reason to wait)
                logger.info(f"Weak signal persists (avg: {avg_rssi} dBm), locking immediately")
                self.timers.cancel("lock")
                self.state_machine.lock(f"Weak signal confirmed (avg: {avg_rssi} dBm)")
        else:
            # Signal improved (in hysteresis zone) - restart timer
            logger.info(f"Hysteresis zone (avg: {avg_rssi} dBm between {self.settings.lock_threshold} and {self.settings.unlock_threshold} dBm), restarting timer")
            self._start_lock_timer()

    def _start_lock_timer(self) -> None:
        """Start/restart 15s timer that locks the session"""
        self.timers.cancel("lock")
        self.timers.start_if_not_running("lock", self._lock_timeout())

    async def _lock_timeout(self) -> None:
        """Called after 15s of absence or weak signal"""
        await asyncio.sleep(self.settings.proximity_timeout)
        logger.info(f"Lock timeout ({self.settings.proximity_timeout:.0f}s)")
        self.state_machine.lock("Device absent or weak signal")


class TimerManager:
    """Manages cancellable async timers"""

    def __init__(self):
        self._tasks: dict[str, asyncio.Task] = {}

    def start_if_not_running(self, name: str, coro) -> None:
        """Start timer only if not already running"""
        if not self.is_running(name):
            self._tasks[name] = asyncio.create_task(coro)

    def is_running(self, name: str) -> bool:
        """Check if timer is running"""
        return name in self._tasks and not self._tasks[name].done()

    def cancel(self, name: str) -> None:
        """Cancel a timer"""
        if name in self._tasks:
            self._tasks[name].cancel()
            del self._tasks[name]

    def cancel_all(self) -> None:
        """Cancel all timers"""
        for task in self._tasks.values():
            task.cancel()
        self._tasks.clear()


class ProximityStateMachine:
    """Manages lock/unlock state transitions"""

    def __init__(self, lock_cmd: List[str], unlock_cmd: List[str]):
        self.lock_cmd = lock_cmd
        self.unlock_cmd = unlock_cmd
        self.state = LockState.UNLOCKED

    def lock(self, reason: str) -> None:
        """Execute lock command"""
        if self.state == LockState.UNLOCKED:
            logger.info(f"{reason}, locking...")
            self._execute(self.lock_cmd)
            self.state = LockState.LOCKED
            logger.info(f"State: {self.state}")

    def unlock(self, reason: str) -> None:
        """Execute unlock command"""
        if self.state != LockState.UNLOCKED:
            logger.info(f"{reason}, unlocking...")
            self._execute(self.unlock_cmd)
            self.state = LockState.UNLOCKED
            logger.info(f"State: {self.state}")

    def _execute(self, cmd: List[str]) -> None:
        """Execute command with timeout"""
        try:
            subprocess.run(cmd, check=False, timeout=5.0)
        except Exception as e:
            logger.error(f"Command failed: {e}")


def main() -> None:
    """Application entry point"""
    # Load settings
    settings = Settings()

    # Create components
    rssi_tracker = RSSITracker(max_samples=settings.rssi_samples)
    state_machine = ProximityStateMachine(
        lock_cmd=settings.lock_cmd.split(),
        unlock_cmd=settings.unlock_cmd.split()
    )
    timers = TimerManager()

    # Create scanner (all logic is event-driven via callbacks and timers)
    scanner = ContinuousScanner(
        rssi_tracker=rssi_tracker,
        state_machine=state_machine,
        timers=timers,
        settings=settings
    )

    # Run
    try:
        asyncio.run(scanner.run())
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        timers.cancel_all()
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
