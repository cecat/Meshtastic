# Meshtastic Node Setup Script - Improvements

## Problems Fixed

### 1. **Missing Timezone Configuration**
- **Issue**: CEC2 had an empty timezone setting (`tzdef: ""`)
- **Solution**: Added `device.tzdef` set to `"CST6CDT,M3.2.0/2:00:00,M11.1.0/2:00:00"` (US Central Time)
- **Location**: Step 3, combined with other user config settings

### 2. **Position Broadcast Interval Resetting to 43200 seconds**
- **Issue**: After configuration changes, `position_broadcast_secs` would reset from 120 (2 min) to 43200 (12 hours)
- **Solution**: 
  - Set all position settings together in a single command
  - Added verification step (Step 5) that re-applies the 120-second setting before final reboot
  - This ensures the value persists even if other config changes try to reset it

### 3. **MQTT Map Reporting Interval Not Specified**
- **Issue**: The original script didn't set `mqtt.map_report_settings.publish_interval_secs`
- **Solution**: Added explicit setting for 60-second MQTT map reports
- **Location**: Step 4, in the MQTT configuration block

### 4. **LCD Screen Always On**
- **Confirmed**: `display.screen_on_secs 0` keeps the screen on permanently
- This was already in your script but is now documented clearly

## Key Improvements

### Strategic Setting Order
The script applies settings in a specific order to prevent conflicts:
1. **Core radio settings** (region, role) - requires reboot
2. **Network** (WiFi) - requires reboot to connect
3. **Position, names, timezone, display** - all together, then reboot
4. **MQTT and channels** - applied after network is stable
5. **Verification** - double-check critical settings
6. **Final reboot** - commit everything

### Grouping Related Settings
Settings that affect each other are applied in single commands:
- Position settings all together (GPS mode, fixed position, coordinates, broadcast interval)
- MQTT settings all together (connection info, map reporting, intervals)
- This prevents the system from applying defaults when settings are changed individually

### Safety Verification
Added Step 5 to re-verify `position_broadcast_secs` before the final reboot, as a safety net against the system resetting it.

## Configuration Variables Set

| Setting | Value | Purpose |
|---------|-------|---------|
| `lora.region` | US | Radio frequency region |
| `device.role` | ROUTER | Node operates as router |
| `device.tzdef` | CST6CDT... | US Central timezone |
| `network.wifi_enabled` | true | Enable WiFi |
| `network.wifi_ssid` | (from secrets) | WiFi network name |
| `network.wifi_psk` | (from secrets) | WiFi password |
| `network.ntp_server` | pool.ntp.org | Time sync server |
| `position.gps_mode` | DISABLED | No GPS hardware needed |
| `position.fixed_position` | true | Station doesn't move |
| `position.position_flags` | 813 | IS_ROUTER + IS_STATION flags |
| `position.position_broadcast_secs` | 120 | Broadcast every 2 minutes |
| `display.screen_on_secs` | 0 | Screen always on |
| `mqtt.enabled` | true | Enable MQTT |
| `mqtt.address` | mqtt.meshtastic.org | Public MQTT broker |
| `mqtt.map_reporting_enabled` | true | Report to map |
| `mqtt.map_report_settings.publish_interval_secs` | 60 | Update map every minute |
| `mqtt.map_report_settings.position_precision` | 10 | Position precision level |

## Usage

1. Edit `secrets.sh` with your WiFi credentials and node location
2. Edit the script to set `LONG_NAME` and `SHORT_NAME` for your node
3. Connect the radio via USB
4. Run: `./radio-setup.sh`
5. Wait for completion (~3-5 minutes)
6. Verify on https://meshmap.net after 5-10 minutes

## Troubleshooting

If position still doesn't update on the map:
```bash
# Check if position_broadcast_secs got reset again
meshtastic --port /dev/cu.SLAB_USBtoUART --get position

# If it's 43200, fix it:
meshtastic --port /dev/cu.SLAB_USBtoUART --set position.position_broadcast_secs 120
```

If coordinates are wrong:
```bash
meshtastic --port /dev/cu.SLAB_USBtoUART --setlat YOUR_LAT --setlon YOUR_LON --setalt YOUR_ALT
```

## Why These Settings Work Together

The Meshtastic firmware has some quirks where changing certain settings can cause others to revert to defaults:

1. **Changing altitude alone** can reset `position_broadcast_secs` to 43200
2. **MQTT configuration** can sometimes affect position settings
3. **Rebooting** at the right times ensures changes persist

By grouping related settings and applying them in a specific order with strategic reboots, this script minimizes these issues.
