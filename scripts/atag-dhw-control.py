#!/usr/bin/env python3
"""
ATAG One DHW Temperature Control Script
Direct API access to read and set DHW (hot water) temperature

Usage:
    ./atag-dhw-control.py get              # Read current DHW temperature
    ./atag-dhw-control.py set 60           # Set DHW temperature to 60°C
    ./atag-dhw-control.py status           # Full status info
"""

import asyncio
import aiohttp
import json
import sys
from typing import Optional, Dict, Any

# Configuration
ATAG_HOST = "192.168.2.1"
ATAG_PORT = 10000
BASE_URL = f"http://{ATAG_HOST}:{ATAG_PORT}"
READ_PATH = "/retrieve"
UPDATE_PATH = "/update"

class AtagOneAPI:
    """Minimal ATAG One API client"""

    def __init__(self, host: str, port: int):
        self.base_url = f"http://{host}:{port}"
        self.session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=15))
        return self

    async def __aexit__(self, *args):
        if self.session:
            await self.session.close()

    async def retrieve_data(self) -> Optional[Dict[str, Any]]:
        """Retrieve all data from ATAG One"""
        payload = {
            "retrieve_message": {
                "seqnr": 0,
                "account_auth": {
                    "user_account": "",
                    "mac_address": "01:23:45:67:89:01"
                },
                "info": 127  # Request all data (1+2+4+8+16+32+64)
            }
        }

        try:
            async with self.session.post(
                f"{self.base_url}{READ_PATH}",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    return data.get("retrieve_reply", {})
                else:
                    print(f"Error: HTTP {resp.status}")
                    return None
        except Exception as e:
            print(f"Connection error: {e}")
            return None

    async def set_dhw_temperature(self, temperature: float) -> bool:
        """Set DHW temperature setpoint"""

        # First, retrieve current schedule data
        data = await self.retrieve_data()
        if not data:
            print("Failed to retrieve current data")
            return False

        # Extract current DHW schedule
        schedules = data.get("schedules", {})
        dhw_schedule = schedules.get("dhw_schedule")

        if not dhw_schedule:
            print("No DHW schedule data found")
            return False

        # Update base temperature
        dhw_schedule["base_temp"] = float(temperature)

        # Build update payload
        payload = {
            "update_message": {
                "seqnr": 0,
                "account_auth": {
                    "user_account": "",
                    "mac_address": "01:23:45:67:89:01"
                },
                "schedules": {
                    "dhw_schedule": dhw_schedule
                }
            }
        }

        try:
            async with self.session.post(
                f"{self.base_url}{UPDATE_PATH}",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as resp:
                if resp.status == 200:
                    result = await resp.json()
                    # Check if update was accepted (status should be 2)
                    if result.get("update_reply", {}).get("acc_status") == 2:
                        print(f"✓ DHW temperature set to {temperature}°C")
                        return True
                    else:
                        print(f"Update rejected: {result}")
                        return False
                else:
                    print(f"Error: HTTP {resp.status}")
                    return False
        except Exception as e:
            print(f"Connection error: {e}")
            return False

    async def get_dhw_info(self) -> Dict[str, Any]:
        """Get DHW-related information"""
        data = await self.retrieve_data()
        if not data:
            return {}

        # Extract relevant DHW info
        report = data.get("report", {})
        control = data.get("control", {})
        schedules = data.get("schedules", {})

        dhw_info = {
            "current_temp": report.get("dhw_water_temp"),
            "setpoint": schedules.get("dhw_schedule", {}).get("base_temp"),
            "water_pressure": report.get("dhw_water_pres"),
            "flow_rate": report.get("dhw_flow_rate"),
            "status": control.get("dhw_status"),
            "mode": control.get("dhw_mode"),
        }

        return dhw_info


async def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1].lower()

    async with AtagOneAPI(ATAG_HOST, ATAG_PORT) as api:
        if command == "get":
            info = await api.get_dhw_info()
            if info:
                print(f"\n📊 DHW Status:")
                print(f"  Current temp:    {info.get('current_temp', 'N/A')}°C")
                print(f"  Setpoint:        {info.get('setpoint', 'N/A')}°C")
                print(f"  Water pressure:  {info.get('water_pressure', 'N/A')} bar")
                print(f"  Flow rate:       {info.get('flow_rate', 'N/A')} l/min")
                print(f"  Status:          {info.get('status', 'N/A')}")
                print()
            else:
                print("❌ Failed to retrieve DHW info")
                sys.exit(1)

        elif command == "set":
            if len(sys.argv) < 3:
                print("Usage: atag-dhw-control.py set <temperature>")
                print("Example: atag-dhw-control.py set 60")
                sys.exit(1)

            try:
                temp = float(sys.argv[2])
                if temp < 40 or temp > 65:
                    print("⚠️  Temperature must be between 40-65°C")
                    print("   Recommended: 60°C (legionella prevention)")
                    sys.exit(1)

                print(f"Setting DHW temperature to {temp}°C...")
                success = await api.set_dhw_temperature(temp)

                if success:
                    # Verify the change
                    await asyncio.sleep(2)
                    info = await api.get_dhw_info()
                    print(f"\n✓ New setpoint: {info.get('setpoint', 'N/A')}°C")
                else:
                    print("❌ Failed to set temperature")
                    sys.exit(1)
            except ValueError:
                print("Error: Temperature must be a number")
                sys.exit(1)

        elif command == "status":
            data = await api.retrieve_data()
            if data:
                # Pretty print relevant sections
                print("\n📊 Full ATAG One Status:\n")

                report = data.get("report", {})
                control = data.get("control", {})

                print("🌡️  Temperatures:")
                print(f"  Room:            {report.get('room_temp', 'N/A')}°C")
                print(f"  Outside:         {report.get('outside_temp', 'N/A')}°C")
                print(f"  CH Water:        {report.get('ch_water_temp', 'N/A')}°C")
                print(f"  DHW Water:       {report.get('dhw_water_temp', 'N/A')}°C")

                print("\n💧 Pressure:")
                print(f"  CH:              {report.get('ch_water_pres', 'N/A')} bar")
                print(f"  DHW:             {report.get('dhw_water_pres', 'N/A')} bar")

                print("\n🔥 Heating:")
                print(f"  CH Setpoint:     {control.get('ch_mode_temp', 'N/A')}°C")
                print(f"  DHW Setpoint:    {data.get('schedules', {}).get('dhw_schedule', {}).get('base_temp', 'N/A')}°C")
                print(f"  Burner Status:   {report.get('boiler_status', 'N/A')}")

                print()
            else:
                print("❌ Failed to retrieve status")
                sys.exit(1)

        else:
            print(f"Unknown command: {command}")
            print(__doc__)
            sys.exit(1)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\nAborted by user")
        sys.exit(0)
