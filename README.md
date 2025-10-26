# Meshtastic Node Setup Guide

This repository contains scripts and documentation for setting up Meshtastic ROUTER nodes with MQTT connectivity and map reporting. The scripts are designed to work around known firmware quirks and provide a reliable, repeatable setup process.

## 📋 Prerequisites

### Hardware Required
- **Supported Meshtastic device** (e.g., Heltec V3, RAK4631, T-Beam, etc.)
- **USB cable** (data-capable, not just charging)
- **Computer** running macOS, Linux, or Windows
- **Power source** (battery or wall adapter for permanent installation)

### Software Required
1. **Meshtastic CLI** - Install via pip:
   ```bash
   pip install --upgrade meshtastic
   ```

2. **Web Browser** - For flashing firmware

### Network Required
- **WiFi network** with internet access
- **WiFi credentials** (SSID and password)

## 🚀 Quick Start

### Step 1: Flash the Firmware

**CRITICAL: Flash firmware BEFORE running the setup script!**

1. Visit the **[Meshtastic Web Flasher](https://flasher.meshtastic.org)**
2. Connect your device via USB
3. Select your device type from the dropdown
4. Choose the **latest stable firmware** (currently 2.6.x series)
5. Click **Flash** and wait for completion
6. **Do not configure anything yet** - just flash and disconnect

### Step 2: Edit the Secrets File

1. Open `secrets.sh` in a text editor
2. Update these values for YOUR setup:

```bash
# --- NETWORK CREDENTIALS ---
WIFI_SSID="YourWiFiName"          # Your WiFi network name
WIFI_PSK="YourWiFiPassword"       # Your WiFi password
MQTT_ADDRESS="mqtt.meshtastic.org" # Public MQTT broker (or use your own)
MQTT_USERNAME="meshdev"            # Default public MQTT username
MQTT_PASSWORD="large4cats"         # Default public MQTT password

# --- LOCATION (Set to your node's location) ---
LATITUDE="40.7128"                 # Your latitude (decimal degrees)
LONGITUDE="-74.0060"               # Your longitude (decimal degrees)
ALTITUDE="10"                      # Your altitude in meters
POSITION_PRECISION="15"            # Privacy: 10=~10m, 13=~100m, 14=~200m, 15=~400m, 16=~1km
```

**How to get your coordinates:**
- Use Google Maps: Right-click location → Copy coordinates
- Use your phone's GPS app
- Use a GPS device
- **DO NOT guess** - accuracy matters for mesh routing

**Position Precision (Privacy Setting):**
- Controls how precisely your location appears on meshmap.net
- **10** = ~10 meters (shows specific building) - good for public infrastructure
- **13** = ~100 meters (shows property area)
- **14** = ~200 meters (shows neighborhood block)
- **15** = ~400 meters (shows general neighborhood) - **recommended for home nodes**
- **16** = ~1 kilometer (shows part of town) - maximum privacy

### Step 3: Edit the Setup Script

1. Open `radio-setup.sh`
2. Find the port setting at the top:
   ```bash
   PORT="/dev/cu.SLAB_USBtoUART"
   ```
   
3. Update if needed for your system:
   - **macOS**: Usually `/dev/cu.SLAB_USBtoUART` or `/dev/cu.usbserial-*`
     - Check with: `ls /dev/cu.*`
   - **Linux**: Usually `/dev/ttyUSB0` or `/dev/ttyACM0`
     - Check with: `ls /dev/ttyUSB* /dev/ttyACM*`
   - **Windows**: Usually `COM3`, `COM4`, etc.
     - Check in Device Manager

4. Set your node name:
   ```bash
   LONG_NAME="Charlie's node n"    # Up to 40 characters
   SHORT_NAME="CECn"                # 4 characters recommended
   ```

### Step 4: Run the Setup Script

1. Connect your device via USB
2. Make the script executable:
   ```bash
   chmod +x radio-setup.sh
   ```

3. Run the script:
   ```bash
   ./radio-setup.sh
   ```

4. Wait 5-7 minutes for completion
5. The script will output status and instructions

### Step 5: Verify Configuration

After the script completes, verify your settings:

```bash
# Check position broadcast interval (should be 120)
meshtastic --port /dev/cu.SLAB_USBtoUART --get position.position_broadcast_secs

# Check full configuration
meshtastic --port /dev/cu.SLAB_USBtoUART --info

# Check MQTT settings
meshtastic --port /dev/cu.SLAB_USBtoUART --get mqtt
```

### Step 6: Check the Map

1. Wait 5-10 minutes after setup completes
2. Visit **[meshmap.net](https://meshmap.net)**
3. Search for your node name
4. Your node should appear with regular updates

## 📁 Files in This Repository

### Core Scripts
| File | Purpose |
|------|---------|
| `radio-setup.sh` | Initial setup with factory reset (USB only) |
| `radio-tuneup.sh` | All other configuration (USB or WiFi) |

### Configuration
| File | Purpose |
|------|---------|
| `secrets.sh.template` | Template for creating your configuration |
| `secrets.sh` | Your actual configuration (create from template) |

### Documentation
| File | Purpose |
|------|---------|
| `README.md` | This file - complete setup and usage guide |
| `SETUP_NOTES.md` | Detailed implementation notes |
| `notes/` | Additional technical documentation and insights |

### Which Script Should I Use?

**For brand new/factory reset setup** → Use `radio-setup.sh` (requires USB)
- Flashing new device
- Complete reconfiguration
- Starting from scratch
- Need to factory reset

**For everything else** → Use `radio-tuneup.sh` (works via USB or WiFi)
- Remote configuration changes
- After firmware updates
- When settings revert
- Regular maintenance
- Updating deployed nodes
- Quick fixes

## 📡 Over-The-Air (OTA) Configuration

### What Can Be Done Over WiFi

Almost ALL configuration can be done remotely over WiFi once the device is on your network:
- ✅ All `--set` commands (region, role, position, etc.)
- ✅ Position updates (lat/lon/alt)
- ✅ Names and identifiers
- ✅ MQTT settings
- ✅ Channel configuration
- ✅ Reboot commands
- ✅ Query device status

### What Requires USB

Only ONE operation requires physical USB access:
- ❌ **Factory Reset** - Must be done via USB for security

This is intentional - prevents malicious remote wiping of devices.

### Configuring Over WiFi

**Use `radio-tuneup.sh` in network mode:**

1. Find the node's IP address (check router or mobile app)
2. Edit `radio-tuneup.sh`:
   ```bash
   # Change from USB to network mode
   CONNECTION_TYPE="network"
   NODE_IP="10.0.5.105"  # Your node's IP
   ```
3. Run the script:
   ```bash
   ./radio-tuneup.sh
   ```
4. All settings applied remotely!

The script works identically whether using USB or WiFi - just change the connection type.

**For more details on OTA configuration**, see [notes/OTA_GUIDE.md](notes/OTA_GUIDE.md).

## 🔧 What the Script Does

The setup script performs these steps in a specific order:

1. **Factory Reset** - Clean slate, removes old configuration
2. **Set Region & Role** - Required by law (US) and defines node behavior (ROUTER)
3. **Configure WiFi** - Connects to your network for MQTT
4. **Set Position & Names** - Configures location and identifiers
5. **Configure MQTT** - Enables map reporting and mesh bridging
6. **Verify Settings** - Triple-checks critical values (they can revert!)
7. **Final Reboot** - Commits all changes

### Why This Order Matters

Meshtastic firmware has quirks that require settings to be applied in a specific order with strategic reboots. The script is designed to work around these issues:

- **Region + Role together**: Prevents role from being overridden
- **WiFi early**: MQTT needs network connectivity
- **All position settings together**: Prevents position_broadcast_secs from reverting
- **Triple verification**: Works around firmware bug that reverts critical settings

## ⚙️ Configuration Options Explained

### Device Role: ROUTER

The script sets the device role to **ROUTER**, which means:
- ✅ Fixed position (doesn't move)
- ✅ Always listening for messages
- ✅ Rebroadcasts messages to extend mesh
- ✅ Helps other nodes communicate
- ⚠️ Power consumption is higher (needs reliable power)

**When to use ROUTER:**
- Fixed installations (rooftop, attic, etc.)
- Powered by wall adapter or solar
- Acts as infrastructure for the mesh

**When to use CLIENT instead:**
- Mobile/portable devices
- Battery-powered handhelds
- Personal devices you carry

To change to CLIENT role, edit line 32 in `radio-setup.sh`:
```bash
--set device.role CLIENT
```

### Position Broadcast Interval: 120 seconds

This is how often your node tells the mesh where it is:
- **120 seconds (2 minutes)** = Frequent updates, mesh knows your position
- Script sets this to 120 for reliable operation
- ⚠️ **Known bug**: Firmware may reset this to 43200 (12 hours)!
- The script triple-checks this value to prevent reversion

### MQTT Settings

- **Map Reporting**: Enabled - shows up on meshmap.net
- **Publish Interval**: 60 seconds - updates map every minute
- **Position Precision**: 10 - approximately 10 meter accuracy
- **Uplink/Downlink**: Enabled - bridges LoRa ↔ MQTT

### Display Settings

- **Screen Timeout**: 0 (never turns off)
- For battery-powered nodes, set to 300 (5 minutes) to save power

## 🐛 Known Issues & Troubleshooting

### Issue: Node Stops Appearing on Map

**Symptom**: Node appeared once, then stopped updating for hours

**Cause**: The `position_broadcast_secs` setting has reverted from 120 to 43200

**Solution**: Run the tuneup script:
```bash
# Configure for your connection method
./radio-tuneup.sh
```

The script automatically triple-checks and fixes this setting.

**Prevention**: After ANY configuration change, run `radio-tuneup.sh` to verify settings.

**For detailed documentation on this bug**, see [notes/POSITION_BROADCAST_BUG.md](notes/POSITION_BROADCAST_BUG.md).

### Issue: Wrong Coordinates

**Symptom**: Node shows up in wrong location on map

**Cause**: Coordinates in `secrets.sh` are incorrect or in wrong format

**Solution**:
1. Get correct coordinates from Google Maps
2. Update `secrets.sh`
3. Apply manually:
   ```bash
   meshtastic --host YOUR_NODE_IP --setlat YOUR_LAT --setlon YOUR_LON
   ```

### Issue: Not Connecting to WiFi

**Symptom**: Node doesn't show up in network, can't connect via IP

**Diagnosis**:
```bash
meshtastic --port YOUR_PORT --info | grep -A 10 network
```

**Solutions**:
1. Verify SSID/password in `secrets.sh` are correct
2. Check if WiFi is 2.4GHz (5GHz not supported)
3. Verify WiFi security is WPA2 (WEP not supported)
4. Check if MAC address is blocked on router

### Issue: Can't Flash Firmware

**Symptom**: Web flasher can't detect device

**Solutions**:
1. Try a different USB cable (must be data cable, not just power)
2. Try a different USB port
3. Install drivers:
   - **CP210x**: For most ESP32 devices
   - **CH340**: For some ESP32 clones
4. Put device in bootloader mode (consult device manual)

### Issue: Altitude Not Setting

**Current Approach**: Script sets altitude with other position settings to minimize firmware bugs

**If Still Having Issues**:
1. Verify altitude is in meters (not feet)
2. Check that position_broadcast_secs didn't revert to 43200:
   ```bash
   meshtastic --host YOUR_NODE_IP --get position.position_broadcast_secs
   ```
3. If reverted, fix it:
   ```bash
   meshtastic --host YOUR_NODE_IP --set position.position_broadcast_secs 120
   ```

**Known Limitation**: Setting altitude can sometimes trigger position_broadcast_secs to reset. The script triple-verifies this value, but monitor it after setup.

## 📊 Verifying Your Setup

### Check Position Broadcasting

```bash
# Should show 120
meshtastic --port YOUR_PORT --get position.position_broadcast_secs
```

### Check MQTT Connection

```bash
# Should show enabled: true
meshtastic --port YOUR_PORT --get mqtt
```

### Check WiFi Connection

```bash
# Should show wifiEnabled: true and your SSID
meshtastic --port YOUR_PORT --get network
```

### Check Node on Map

1. Visit https://meshmap.net
2. Use search to find your node name
3. Should update every 1-2 minutes
4. If not updating:
   - Check position_broadcast_secs
   - Check MQTT connection
   - Wait 5-10 minutes and refresh

## 🔄 Updating Firmware

When new firmware is released:

1. **Backup current config** (optional but recommended):
   ```bash
   meshtastic --port YOUR_PORT --info > backup_config.txt
   ```

2. **Flash new firmware** using Web Flasher

3. **Re-run setup script**:
   ```bash
   ./radio-setup.sh
   ```

**DO NOT** try to preserve config across major firmware updates - always re-run setup.

## 🆘 Getting Help

### Check Your Setup

Before asking for help, gather this info:
```bash
# Get full device info
meshtastic --port YOUR_PORT --info > my_device_info.txt

# Get firmware version
meshtastic --port YOUR_PORT --info | grep firmware

# Check logs
meshtastic --port YOUR_PORT --debug
```

### Support Resources

- **Official Docs**: https://meshtastic.org/docs
- **Discord**: https://discord.gg/meshtastic
- **Forum**: https://meshtastic.discourse.group
- **GitHub Issues**: https://github.com/meshtastic/firmware/issues

### Common Questions

**Q: Can I use 5GHz WiFi?**
A: No, only 2.4GHz is supported

**Q: Can I use multiple nodes on same WiFi?**
A: Yes, each gets its own IP via DHCP

**Q: How do I change node name later?**
A: 
```bash
meshtastic --host YOUR_IP --set-owner "New Name" --set-owner-short "NEWN"
```

**Q: Why is my battery draining fast?**
A: ROUTER role + always-on screen + frequent broadcasts = high power use
   - Consider CLIENT role for battery devices
   - Set screen timeout (display.screen_on_secs 300)

**Q: Can I disable MQTT but keep LoRa mesh?**
A: Yes:
```bash
meshtastic --host YOUR_IP --set mqtt.enabled false
```

## 📝 Notes

- **Region Setting**: US region is set in the script. For other regions, change line 31:
  ```bash
  --set lora.region US    # Change to EU_868, ANZ, etc.
  ```

- **Time Zones**: Script uses US Central time. For other zones, change line 66:
  ```bash
  --set device.tzdef "CST6CDT,M3.2.0/2:00:00,M11.1.0/2:00:00"
  ```

- **Security**: secrets.sh contains WiFi password - keep it secure!

- **Altitude**: The script includes altitude with position settings to minimize firmware bugs. 
  After setup, verify position_broadcast_secs is still 120 (not 43200).

## 🔐 Security Considerations

1. **secrets.sh contains sensitive data**:
   - Add to .gitignore if using git
   - Don't share or commit to public repositories
   - Secure file permissions: `chmod 600 secrets.sh`

2. **Default MQTT credentials**:
   - Public broker with shared credentials
   - Anyone can see your node's position
   - Messages on default channel are visible to all
   - For privacy, set up your own MQTT broker

3. **WiFi security**:
   - Use WPA2 or WPA3
   - Don't use WEP (not supported)
   - Consider separate IoT network

## 📚 Additional Documentation

For more details, see:
- `SETUP_NOTES.md` - Technical implementation details
- `POSITION_BROADCAST_BUG.md` - In-depth bug documentation
- [Official Meshtastic Docs](https://meshtastic.org/docs)

## 📄 License

These scripts are provided as-is for use with Meshtastic devices. Meshtastic firmware is GPL-licensed. Consult official documentation for licensing details.

## 🙏 Credits

- Meshtastic project and community
- Configuration tips from the Meshtastic Discord and forums
- Trial-and-error testing with real hardware

---

**Last Updated**: October 2025  
**Tested With**: Meshtastic firmware 2.6.11, Heltec V3 hardware  
**Python CLI Version**: 2.4+
