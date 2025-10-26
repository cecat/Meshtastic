# OTA (Over-The-Air) Configuration Guide

## Overview

Meshtastic devices can be configured remotely over WiFi for almost all settings. This guide explains what can and cannot be done via OTA configuration, and when to use each script. For complete setup instructions, see [README.md](README.md).

## What Works Over WiFi (OTA)

✅ **Almost everything!** The Meshtastic CLI supports network connections via `--host IP_ADDRESS`:

### Configuration Commands
- `--set` - All device settings
- `--setlat`, `--setlon`, `--setalt` - Position
- `--set-owner`, `--set-owner-short` - Node names
- `--ch-set` - Channel configuration
- All MQTT settings
- All position settings
- Display settings
- Power settings
- Network settings (including WiFi credentials)

### Control Commands
- `--reboot` - Restart the device
- `--info` - Get device information
- `--nodes` - List mesh nodes
- `--get` - Query specific settings
- `--shutdown` - Power down (ESP32 only)

### What This Means
Once your device is on WiFi, you can:
- Change any configuration remotely
- Update position data
- Modify MQTT settings
- Adjust all radio parameters
- Reboot the device
- Query status

## What Requires USB

❌ **Only ONE operation requires physical access:**

### Factory Reset
- `--factory-reset` - MUST be done via USB (security feature)
- `--factory-reset-device` - MUST be done via USB (security feature)

### Why This Limitation?
This is intentional security design:
- Prevents malicious remote wiping of devices
- Requires physical access to completely reset configuration
- Protects against unauthorized configuration erasure
- Ensures you can't accidentally brick a remote device

## Script Comparison

### radio-setup.sh (USB Only)
**Purpose**: Complete initial setup from factory reset

**Requirements**:
- USB connection required
- Device can be completely unconfigured
- Starts from scratch

**Process**:
1. Factory reset
2. Configure region and role
3. Set up WiFi
4. Configure position and identity
5. Set up MQTT
6. Verify all settings

**Use When**:
- Setting up a brand new device
- Starting completely from scratch
- Factory reset is needed
- USB access is available

### radio-tuneup.sh (USB or WiFi - Universal)
**Purpose**: Apply or update all configuration settings

**Requirements**:
- Works via USB OR WiFi (configurable)
- No factory reset
- Flexible connection method

**Features**:
- Universal configuration script
- Automatic verification
- Self-healing for broadcast interval bug
- Works identically via USB or network

**Process**:
1. Connect (USB or network - you choose)
2. Apply all settings
3. Triple-verify critical values
4. Reboot
5. Verify settings stuck

**Use When**:
- Remote configuration (set to network mode)
- After firmware update
- Settings have reverted
- Regular maintenance
- Quick configuration fix
- ANY configuration update (other than factory reset)

**This is your primary configuration tool** - use it for all configuration updates whether via USB or WiFi.

## Decision Tree

```
Need to configure device?
│
├─ Is device brand new/needs factory reset?
│  └─ YES → Use radio-setup.sh (USB required)
│
└─ Any other configuration needed?
   └─ Use radio-tuneup.sh
      ├─ Have USB access? → Set CONNECTION_TYPE="usb"
      └─ Remote/WiFi? → Set CONNECTION_TYPE="network"
```

## Network Configuration Details

### Finding Device IP Address

**Method 1: Router**
- Log into your router
- Check DHCP client list
- Look for device MAC address or hostname

**Method 2: Mobile App**
- Connect to device via app
- Device info shows IP when on WiFi
- Note the IP for later use

**Method 3: USB First**
```bash
meshtastic --port /dev/cu.SLAB_USBtoUART --info | grep -i ip
```

### Network Requirements

**Same Network**: Your computer and the Meshtastic device must be on the same network
- Both on same WiFi SSID, OR
- Both on same LAN

**Firewall**: Ensure firewall allows connections
- TCP port for configuration
- Check computer and router firewall rules

**WiFi Band**: Device must be on 2.4GHz WiFi
- 5GHz NOT supported
- Verify router is broadcasting 2.4GHz

## Common OTA Scenarios

### Scenario 1: Roof-Mounted Node
**Problem**: Node is mounted on roof, USB access is difficult

**Solution**: Use `radio-tuneup.sh` in network mode
```bash
# Edit script with node's IP
CONNECTION_TYPE="network"
NODE_IP="10.0.5.105"

# Run remotely
./radio-tuneup.sh
```

### Scenario 2: After Firmware Update
**Problem**: Settings reverted after OTA firmware update

**Solution**: Use `radio-tuneup.sh` over network
```bash
# Edit script - choose network mode
CONNECTION_TYPE="network"
NODE_IP="10.0.5.105"

# Re-apply all settings
./radio-tuneup.sh
```

### Scenario 3: Broadcast Interval Reset
**Problem**: position_broadcast_secs keeps reverting to 43200

**Solution**: Use `radio-tuneup.sh`
```bash
# The tuneup script automatically triple-verifies this setting
./radio-tuneup.sh
```

### Scenario 4: Deploy New Node to Attic
**Problem**: Setting up node that will be hard to access

**Solution**: Two-phase approach
1. **Phase 1** (USB at desk): Run `radio-setup.sh` to configure everything including WiFi
2. **Phase 2** (After installation): Use `radio-tuneup.sh` in network mode for any changes
   ```bash
   CONNECTION_TYPE="network"
   NODE_IP="10.0.5.110"
   ```

## Advantages of OTA Configuration

### For Fixed Installations
- No need to remove from mount
- No need for ladder/access
- Configure from comfort of desk
- Multiple nodes easily managed

### For Development
- Quick iteration on settings
- Test configurations rapidly
- No cable reconnections
- Script and automate changes

### For Maintenance
- Regular tune-ups without physical access
- Monitor and fix settings remotely
- Respond to issues quickly
- Coordinate with other admins remotely

## Limitations and Workarounds

### Cannot Factory Reset Remotely
**Workaround**: 
- Use tune-up script to re-apply settings
- If truly needed, physical access required
- Plan initial setup carefully

### Cannot Flash Firmware OTA (Standard)
**Note**: 
- Standard firmware doesn't support WiFi OTA flashing
- Special OTA firmware exists but requires compilation
- Bluetooth OTA works on nRF52 devices
- Plan physical access for major firmware updates

### Network Connectivity Required
**Workaround**:
- Ensure stable WiFi at installation site
- Test network connection before mounting
- Consider backup USB access method
- Document physical access procedure

## Best Practices

### Initial Setup
1. Configure everything via USB first (`radio-setup.sh`)
2. Test network connectivity
3. Document IP address
4. Test `radio-tuneup.sh` in network mode before mounting
5. Mount/deploy device
6. Use `radio-tuneup.sh` (network mode) for all future changes

### Regular Maintenance
1. Schedule monthly tune-ups
2. Use `radio-tuneup.sh` in network mode
3. Script automatically verifies critical settings
4. Check meshmap.net for proper reporting
5. Document any issues

### Remote Management
1. Keep IP addresses documented
2. Maintain current secrets.sh for each node
3. Use version control for configurations
4. Test changes on one node first
5. Always have `radio-tuneup.sh` configured for network mode ready to go

### Security Considerations
1. Secure WiFi network
2. Consider separate IoT network
3. Document admin access
4. Limit who has OTA access
5. Keep secrets.sh files secure

## Troubleshooting OTA

### Cannot Connect to Device
```bash
# Test connection
meshtastic --host 10.0.5.105 --info

# Check network
ping 10.0.5.105

# Verify IP address
# Check router DHCP list

# Try different IP if DHCP changed it
```

### Settings Don't Stick
```bash
# Use tuneup script (triple-verifies)
./radio-tuneup.sh

# Manual verification
meshtastic --host 10.0.5.105 --get position.position_broadcast_secs
```

### Device Reboots During Configuration
- Normal behavior - settings trigger reboots
- Wait for reboot to complete (20-30 seconds)
- Scripts include appropriate delays
- Don't interrupt the process

### Lost Network Connection After Changes
- WiFi credentials might have been changed
- Check secrets.sh matches device config
- May need USB access to restore WiFi
- Always test WiFi changes carefully

## Summary

**OTA Configuration is Powerful**:
- Almost all settings can be changed remotely
- Factory reset is the only USB-only operation
- Single universal script handles both USB and WiFi
- Enables true remote management

**Two Scripts, Simple Choice**:
- `radio-setup.sh` - Initial setup with factory reset (USB only)
- `radio-tuneup.sh` - Everything else (USB or WiFi - you choose)

**Plan Ahead**:
- Configure WiFi during initial setup
- Document IP addresses
- Test network mode before deployment
- Use `radio-tuneup.sh` for all ongoing configuration
