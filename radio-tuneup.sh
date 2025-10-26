#!/bin/zsh

# Meshtastic Node Tune-Up Script
# Re-applies all configuration settings without factory reset
# Works over USB (--port) or WiFi (--host)
#
# USE CASES:
# - After firmware update (settings may revert)
# - When position_broadcast_secs resets to 43200
# - After configuration changes cause settings to revert
# - Quick fix for mis-configured nodes
# - Regular maintenance to ensure settings are correct
#
# DOES NOT:
# - Factory reset (preserves all existing config)
# - Change WiFi credentials (unless you edit secrets.sh)
# - Disrupt operation (just updates settings)

# --- CONNECTION SETTINGS ---
# Uncomment ONE of these connection methods:

# Method 1: USB Connection
CONNECTION_TYPE="usb"
PORT="/dev/cu.SLAB_USBtoUART"

# Method 2: Network Connection (comment out above, uncomment below)
# CONNECTION_TYPE="network"
# NODE_IP="10.0.5.105"

# --- LOAD SECRETS ---
source "$(dirname "$0")/secrets.sh"

# --- BUILD CONNECTION STRING ---
if [ "$CONNECTION_TYPE" = "usb" ]; then
    CONNECT="--port $PORT"
    CONN_DESC="USB port $PORT"
elif [ "$CONNECTION_TYPE" = "network" ]; then
    CONNECT="--host $NODE_IP"
    CONN_DESC="network at $NODE_IP"
else
    echo "ERROR: Invalid CONNECTION_TYPE. Must be 'usb' or 'network'"
    exit 1
fi

# --- VERIFY CONNECTION ---
echo "Testing connection via $CONN_DESC..."
if ! meshtastic $CONNECT --info > /dev/null 2>&1; then
    echo "ERROR: Cannot connect via $CONN_DESC"
    echo ""
    if [ "$CONNECTION_TYPE" = "usb" ]; then
        echo "USB Troubleshooting:"
        echo "  1. Check device is connected via USB"
        echo "  2. Verify PORT setting is correct"
        echo "  3. Try: ls /dev/cu.* (macOS) or ls /dev/tty* (Linux)"
    else
        echo "Network Troubleshooting:"
        echo "  1. Verify IP address is correct"
        echo "  2. Check device is powered on and connected to WiFi"
        echo "  3. Confirm you're on the same network"
    fi
    exit 1
fi

echo "✓ Connected successfully via $CONN_DESC"
echo ""
echo "============================================"
echo "Meshtastic Node Tune-Up"
echo "This will re-apply all settings without factory reset"
echo "============================================"
echo ""

# --- APPLY ALL SETTINGS ---

echo "Step 1: Core Radio Settings..."
meshtastic $CONNECT \
    --set lora.region US \
    --set device.role ROUTER \
    --set device.tzdef "CST6CDT,M3.2.0/2:00:00,M11.1.0/2:00:00"

echo "Step 2: Names and Position Flags..."
meshtastic $CONNECT \
    --set-owner "$LONG_NAME" \
    --set-owner-short "$SHORT_NAME" \
    --set position.position_flags 813

echo "Step 3: Position Settings (ALL TOGETHER)..."
meshtastic $CONNECT \
    --set position.gps_mode DISABLED \
    --set position.fixed_position true \
    --setlat "$LATITUDE" \
    --setlon "$LONGITUDE" \
    --setalt "$ALTITUDE" \
    --set position.position_broadcast_secs 120

echo "Step 4: Display Settings..."
meshtastic $CONNECT --set display.screen_on_secs 0

echo "Step 5: MQTT Configuration..."
meshtastic $CONNECT \
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

echo "Step 6: Channel Settings..."
meshtastic $CONNECT \
    --ch-set uplink_enabled true --ch-index 0 \
    --ch-set downlink_enabled true --ch-index 0

echo ""
echo "Step 7: Triple-Verify Critical Settings..."
echo "  (This works around firmware bug that resets position_broadcast_secs)"

meshtastic $CONNECT --set position.position_broadcast_secs 120
sleep 2
meshtastic $CONNECT --set position.position_broadcast_secs 120
sleep 2
meshtastic $CONNECT --set position.position_broadcast_secs 120
sleep 2

meshtastic $CONNECT --set mqtt.map_report_settings.publish_interval_secs 60

echo ""
echo "Step 8: Final Reboot..."
meshtastic $CONNECT --reboot

echo ""
echo "============================================"
echo "Tune-Up Complete!"
echo "============================================"
echo ""
echo "Waiting 20 seconds for reboot..."
sleep 20

echo ""
echo "Verifying critical setting after reboot..."
BROADCAST_SECS=$(meshtastic $CONNECT --get position.position_broadcast_secs 2>&1 | grep -o '[0-9]\+' | tail -1)

if [ "$BROADCAST_SECS" = "120" ]; then
    echo "✓ SUCCESS: position_broadcast_secs is correctly set to 120"
else
    echo "⚠ WARNING: position_broadcast_secs is $BROADCAST_SECS (should be 120)"
    echo "  Re-applying fix..."
    meshtastic $CONNECT --set position.position_broadcast_secs 120
    echo "  Fixed. Verify with: meshtastic $CONNECT --get position.position_broadcast_secs"
fi

echo ""
echo "Node: $LONG_NAME ($SHORT_NAME)"
echo "Check meshmap.net in 5-10 minutes for updates"
echo ""
echo "Quick verification commands:"
echo "  meshtastic $CONNECT --info"
echo "  meshtastic $CONNECT --get position"
echo "  meshtastic $CONNECT --get mqtt"
echo "============================================"
