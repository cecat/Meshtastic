#!/bin/zsh

# Meshtastic Node Setup Script
# This script configures a Meshtastic device from factory reset to fully operational
# 
# PREREQUISITES:
# 1. Flash firmware FIRST using Web Flasher: https://flasher.meshtastic.org
# 2. Edit secrets.sh with your WiFi, location, and node name details
# 3. Connect device via USB and verify PORT setting below

# --- SYSTEM SETTINGS  ---
# Find your device port by:
#   macOS: ls /dev/cu.*
#   Linux: ls /dev/ttyUSB* or ls /dev/ttyACM*
#   Windows: Check Device Manager for COM port

PORT="/dev/cu.SLAB_USBtoUART"

# --- LOAD SECRETS (WiFi, MQTT credentials, location, node names...)---
source "$(dirname "$0")/secrets.sh"

# --- STEP 0: FACTORY RESET (REQUIRED TO CLEAN THE MEMORY) ---
# Factory reset ensures:
# - No stale configuration from previous setups
# - Clean slate prevents settings conflicts
# - Reduces risk of settings reverting to old values

echo "0. Performing Factory Reset..."
meshtastic --port "$PORT" --factory-reset

echo "Wait 45 seconds for the device to restart after the reset..."
sleep 45


# --- STEP 1: FORCE CORE RADIO AND ROLE (REQUIRES REBOOT) ---
# CRITICAL: These MUST be set first, together, before other settings
# Region: Required by law, affects frequency and duty cycle
# Role: ROUTER is for fixed infrastructure nodes that help extend the mesh
#       Use CLIENT for mobile/handheld devices instead

echo "1. Applying CRITICAL Radio Region and Device Role..."
# CRITICAL: LoRa Region and Role TOGETHER (MUST be set after reset)
meshtastic --port "$PORT" \
    --set lora.region US \
    --set device.role ROUTER

# FORCE REBOOT TO PERSIST CORE SETTINGS
echo "Forcing reboot to commit Region and Role. Wait 20 seconds..."
meshtastic --port "$PORT" --reboot
sleep 20


# --- STEP 2: APPLY WIFI (BEFORE OTHER SETTINGS) ---
# WiFi must be configured early because:
# - MQTT requires network connectivity
# - NTP server needs network for accurate time
# - Reboot ensures WiFi is connected before proceeding

echo "2. Configuring WiFi (must be done early)..."

# NETWORK CONFIG: Wi-Fi and NTP - ALL TOGETHER
meshtastic --port "$PORT" \
    --set network.wifi_enabled true \
    --set network.wifi_ssid "$WIFI_SSID" \
    --set network.wifi_psk "$WIFI_PSK" \
    --set network.ntp_server pool.ntp.org

# Reboot to establish WiFi connection
echo "Rebooting to connect to WiFi. Wait 25 seconds..."
meshtastic --port "$PORT" --reboot
sleep 25

# --- STEP 3: SET NAMES, POSITION, TIMEZONE, AND DISPLAY ---
# All position-related settings MUST be set together
# Firmware bug: Setting position values separately can cause
# position_broadcast_secs to revert to 43200 (12 hours) default
# 
# Position flags 813 = IS_ROUTER (1) + IS_STATION (812)
# This tells other nodes this is a fixed infrastructure node

echo "3. Applying Names, Position, Timezone, and Display Settings..."

# USER CONFIG: Names, position flags, and timezone - ALL TOGETHER
meshtastic --port "$PORT" \
    --set-owner "$LONG_NAME" \
    --set-owner-short "$SHORT_NAME" \
    --set position.position_flags 813 \
    --set device.tzdef "CST6CDT,M3.2.0/2:00:00,M11.1.0/2:00:00"

# POSITION CONFIG: CRITICAL - All position settings in ONE command
# This prevents the system from resetting position_broadcast_secs to 43200
# Including altitude here with other settings minimizes risk of reversion
meshtastic --port "$PORT" \
    --set position.gps_mode DISABLED \
    --set position.fixed_position true \
    --setlat "$LATITUDE" \
    --setlon "$LONGITUDE" \
    --setalt "$ALTITUDE" \
    --set position.position_broadcast_secs 120

# DISPLAY CONFIG: Screen always on (0 = never timeout)
# For battery-powered nodes, consider a timeout like 300 seconds
meshtastic --port "$PORT" --set display.screen_on_secs 0

# FORCE REBOOT TO PERSIST NAME/POSITION/DISPLAY/TIMEZONE
echo "Forcing reboot to commit Name/Position/Display/Timezone. Wait 20 seconds..."
meshtastic --port "$PORT" --reboot
sleep 20

# --- STEP 4: CONFIGURE MQTT WITH MAP REPORTING ---
# MQTT allows the node to:
# - Report to public map (meshmap.net)
# - Communicate with other nodes via internet
# - Bridge LoRa mesh to MQTT network
#
# Map reporting settings:
# - publish_interval_secs: How often to update the map (60 = every minute)
# - position_precision: Accuracy level for privacy (10 = ~10 meter precision)

echo "4. Applying MQTT Configuration with Map Reporting..."

# MQTT MODULE CONFIG: ALL MQTT settings TOGETHER
meshtastic --port "$PORT" \
    --set mqtt.enabled true \
    --set mqtt.address "$MQTT_ADDRESS" \
    --set mqtt.username "$MQTT_USERNAME" \
    --set mqtt.password "$MQTT_PASSWORD" \
    --set mqtt.tls_enabled false \
    --set mqtt.encryption_enabled false \
    --set mqtt.json_enabled false \
    --set mqtt.map_reporting_enabled true \
    --set mqtt.root msh/US/IL/Chi \
    --set mqtt.map_report_settings.position_precision "$POSITION_PRECISION" \
    --set mqtt.map_report_settings.publish_interval_secs 60

# CHANNEL CONFIG: Enable Uplink/Downlink - TOGETHER
# Uplink: Send to MQTT from LoRa mesh
# Downlink: Receive from MQTT to LoRa mesh
meshtastic --port "$PORT" \
    --ch-set uplink_enabled true --ch-index 0 \
    --ch-set downlink_enabled true --ch-index 0

# --- STEP 5: VERIFY CRITICAL SETTINGS ---

echo "5. Verifying critical settings (multiple passes for stubborn firmware)..."

# AGGRESSIVE FIX: Set position_broadcast_secs THREE TIMES
# The firmware is notorious for reverting this back to 43200
echo "  Setting position_broadcast_secs (attempt 1/3)..."
meshtastic --port "$PORT" --set position.position_broadcast_secs 120
sleep 2

echo "  Setting position_broadcast_secs (attempt 2/3)..."
meshtastic --port "$PORT" --set position.position_broadcast_secs 120
sleep 2

echo "  Setting position_broadcast_secs (attempt 3/3)..."
meshtastic --port "$PORT" --set position.position_broadcast_secs 120
sleep 2

# Also set MQTT publish interval separately to ensure it sticks
echo "  Setting MQTT map publish interval..."
meshtastic --port "$PORT" --set mqtt.map_report_settings.publish_interval_secs 60

echo "Verification complete. Final reboot..."

# --- STEP 6: FINAL REBOOT ---

meshtastic --port "$PORT" --reboot

echo ""
echo "IMPORTANT: After the device reboots, run this command to verify:"
echo "  meshtastic --port $PORT --get position.position_broadcast_secs"
echo ""
echo "If it shows 43200 instead of 120, run:"
echo "  meshtastic --port $PORT --set position.position_broadcast_secs 120"

echo ""
echo "============================================"
echo "Script finished!"
echo "============================================"
echo "The device should now:"
echo "  - Display info on the LCD screen (always on)"
echo "  - Connect to WiFi: $WIFI_SSID"
echo "  - Connect to MQTT: $MQTT_ADDRESS"
echo "  - Report position to mesh every 120 seconds"
echo "  - Report to MQTT map every 60 seconds"
echo "  - Role: ROUTER"
echo "  - Timezone: US Central (CST/CDT)"
echo ""
echo "Check the map at https://meshmap.net in 5-10 minutes."
echo "Look for node: $LONG_NAME ($SHORT_NAME)"
echo ""
echo "To verify settings after boot:"
echo "  meshtastic --port $PORT --info"
echo "  meshtastic --port $PORT --get position"
echo "  meshtastic --port $PORT --get mqtt"
echo ""
echo "CRITICAL: If position_broadcast_secs reverts to 43200,"
echo "run this command:"
echo "  meshtastic --port $PORT --set position.position_broadcast_secs 120"
echo "============================================"
