# Meshtastic Configuration - Lessons Learned

This document summarizes key findings from real-world testing with Meshtastic firmware 2.6.11 on Heltec V3 hardware.

## Critical Firmware Quirks

### 1. Position Broadcast Interval Resets
**The Bug**: `position.position_broadcast_secs` frequently reverts from 120 to 43200 (12 hours)

**When It Happens**:
- After setting altitude
- After MQTT configuration changes
- After certain reboots
- Sometimes randomly

**Impact**: Node stops appearing on meshmap.net because it only broadcasts every 12 hours

**Solutions**:
- Set all position-related settings in a single command
- Never set altitude separately (or accept you'll need to fix broadcast interval)
- Triple-check the value after configuration
- Re-apply after any config changes
- Keep a fix script handy

**Code Pattern That Works**:
```bash
# Set ALL position settings together
meshtastic --port $PORT \
    --set position.gps_mode DISABLED \
    --set position.fixed_position true \
    --setlat "$LATITUDE" \
    --setlon "$LONGITUDE" \
    --set position.position_broadcast_secs 120

# Verify after every reboot
sleep 20
meshtastic --port $PORT --set position.position_broadcast_secs 120
sleep 2
meshtastic --port $PORT --set position.position_broadcast_secs 120
sleep 2
meshtastic --port $PORT --set position.position_broadcast_secs 120
```

### 2. Configuration Order Matters
**Finding**: Settings must be applied in a specific order with strategic reboots

**Best Practice Order**:
1. Factory reset
2. Region + Role (together, then reboot)
3. WiFi (then reboot to establish connection)
4. Position + Names + Timezone (all together, then reboot)
5. MQTT + Channels (together)
6. Verify critical settings (especially broadcast interval)
7. Final reboot

**Why**: Some settings override others if applied in wrong order

### 3. Timezone Gets Forgotten
**The Bug**: Timezone (`device.tzdef`) defaults to empty string

**Impact**: 
- Incorrect timestamps
- Confusing logs
- Time-based features may not work correctly

**Solution**: Always explicitly set timezone:
```bash
--set device.tzdef "CST6CDT,M3.2.0/2:00:00,M11.1.0/2:00:00"
```

### 4. Altitude Setting Best Practice
**Finding**: Setting `--setalt` separately can cause position_broadcast_secs to reset

**Best Practice**: Include altitude with other position settings in a single command:

```bash
# Good - altitude with all other position settings
meshtastic --port $PORT \
    --set position.gps_mode DISABLED \
    --set position.fixed_position true \
    --setlat "$LAT" \
    --setlon "$LON" \
    --setalt "$ALT" \
    --set position.position_broadcast_secs 120

# Bad - altitude set separately
meshtastic --port $PORT --setlat "$LAT" --setlon "$LON"
sleep 5
meshtastic --port $PORT --setalt "$ALT"  # <- May reset broadcast_secs
```

**After Setting**: Always verify position_broadcast_secs didn't revert:
```bash
meshtastic --port $PORT --get position.position_broadcast_secs
```

## Best Practices from Testing

### Grouping Related Settings
Always group related settings in a single command:

```bash
# Good - all position settings together
meshtastic --port $PORT \
    --set position.gps_mode DISABLED \
    --set position.fixed_position true \
    --setlat "$LAT" \
    --setlon "$LON" \
    --setalt "$ALT" \
    --set position.position_broadcast_secs 120

# Bad - separate commands
meshtastic --port $PORT --set position.gps_mode DISABLED
meshtastic --port $PORT --setlat "$LAT"  # <- May reset broadcast_secs
meshtastic --port $PORT --setalt "$ALT"  # <- Definitely may reset broadcast_secs
meshtastic --port $PORT --set position.position_broadcast_secs 120
```

### Strategic Reboots
Reboot after major configuration groups:
- After region/role changes
- After WiFi configuration
- After position configuration
- After all MQTT settings

Don't reboot in the middle of a configuration group.

### Verification is Essential
Always verify critical settings:
```bash
# Check the three settings that commonly reset
meshtastic --port $PORT --get position.position_broadcast_secs
meshtastic --port $PORT --get device.tzdef
meshtastic --port $PORT --get mqtt.map_report_settings.publish_interval_secs
```

### Network Connection Timing
Configure WiFi early and reboot before MQTT settings:
- MQTT needs network connectivity
- NTP needs network for time
- Map reporting needs both

## Community Best Practices (from Research)

### Device Roles
**From Official Docs**: "It is strongly recommended to keep your ROLE set to CLIENT, CLIENT_MUTE, or CLIENT_BASE. Only use other roles if you have a specific, well-understood reason to do so."

**When to Use ROUTER**:
- Fixed installations (rooftop, attic)
- Reliable power source
- Specifically intending to extend mesh coverage
- Understanding the power consumption trade-off

**When to Use CLIENT**:
- Mobile/handheld devices
- Battery-powered nodes
- Personal devices
- Default choice for most users

### Hop Limit
**From Official Docs**: "It is strongly recommended to leave your MAX HOPS set to 3 unless you're sure you need more"

**Default**: 3 hops
**Reasoning**: Higher hop counts can cause network congestion and packet collisions

### Position Broadcast Intervals
**From Testing**: 
- 120 seconds (2 min) works well for fixed nodes
- Enables frequent map updates
- Provides timely position data to mesh

**From Official Docs**: Smart broadcast feature helps by:
- Increasing frequency when moving
- Reducing frequency when stationary
- Automatically adjusting based on channel data rate

### MQTT Map Reporting
**From Testing**:
- `publish_interval_secs: 60` provides good map update frequency
- `position_precision: 10` balances accuracy with privacy (≈10m precision)
- Map updates take 5-10 minutes to appear initially

## Firmware Version Notes

**Tested With**: 2.6.11.60ec05e

**Known Issues in This Version**:
- position_broadcast_secs reversion bug
- Altitude setting causing broadcast interval reset
- Timezone defaulting to empty

**Recommendations**:
- Stay on stable release branch (2.6.x currently)
- Check release notes before updating
- Always re-run full setup after firmware updates
- Don't rely on config preservation across major versions

## Testing Methodology

These findings come from:
1. Multiple Heltec V3 devices
2. Real-world deployment over several days
3. Monitoring via meshmap.net
4. CLI configuration and verification
5. Analysis of `--info` output comparing working vs. broken states
6. Review of official documentation
7. Community forum/Discord discussions

## Configuration File Management

### secrets.sh Best Practices
```bash
# Keep sensitive data separate
# Version control-friendly (can .gitignore secrets.sh)
# Reusable across multiple nodes
# Easy to audit and update

# Security
chmod 600 secrets.sh  # Readable only by owner
```

### Script Design Principles
1. **Idempotent**: Can be run multiple times safely (factory reset ensures clean state)
2. **Documented**: Comments explain WHY, not just WHAT
3. **Defensive**: Triple-checks critical settings that are known to revert
4. **Transparent**: Shows what it's doing with echo statements
5. **Recoverable**: Provides verification commands in output

## What Actually Works

### Reliable Configuration Pattern
```bash
# 1. Factory reset
meshtastic --port $PORT --factory-reset
sleep 45

# 2. Core settings with reboot
meshtastic --port $PORT --set lora.region US --set device.role ROUTER
meshtastic --port $PORT --reboot
sleep 20

# 3. WiFi with reboot
meshtastic --port $PORT \
    --set network.wifi_enabled true \
    --set network.wifi_ssid "$SSID" \
    --set network.wifi_psk "$PSK" \
    --set network.ntp_server pool.ntp.org
meshtastic --port $PORT --reboot
sleep 25

# 4. Position and identity with reboot
meshtastic --port $PORT \
    --set-owner "$NAME" \
    --set-owner-short "$SHORT" \
    --set position.position_flags 813 \
    --set device.tzdef "$TZ"

meshtastic --port $PORT \
    --set position.gps_mode DISABLED \
    --set position.fixed_position true \
    --setlat "$LAT" \
    --setlon "$LON" \
    --setalt "$ALT" \
    --set position.position_broadcast_secs 120

meshtastic --port $PORT --reboot
sleep 20

# 5. MQTT configuration
meshtastic --port $PORT \
    --set mqtt.enabled true \
    --set mqtt.address "$MQTT_ADDR" \
    --set mqtt.username "$MQTT_USER" \
    --set mqtt.password "$MQTT_PASS" \
    --set mqtt.map_reporting_enabled true \
    --set mqtt.map_report_settings.publish_interval_secs 60

# 6. Triple-verify critical setting
meshtastic --port $PORT --set position.position_broadcast_secs 120
sleep 2
meshtastic --port $PORT --set position.position_broadcast_secs 120
sleep 2
meshtastic --port $PORT --set position.position_broadcast_secs 120

# 7. Final reboot
meshtastic --port $PORT --reboot
```

This pattern has proven reliable across multiple devices and configurations.

## Future Improvements

### For Script
- [ ] Add automatic verification of broadcast interval after final reboot
- [ ] Add option to set CLIENT vs ROUTER role via command line
- [ ] Add support for different time zones via parameter
- [ ] Create verification-only script (no changes)
- [ ] Add rollback/restore config option

### For Documentation
- [ ] Video walkthrough
- [ ] Troubleshooting flowchart
- [ ] Common error messages and solutions
- [ ] Hardware-specific notes (different boards)

### For Meshtastic Firmware
Issues to report/track:
- position_broadcast_secs reversion bug
- Altitude setting causing config resets
- Timezone default to empty string
- Need for triple-setting workaround

## Conclusion

Meshtastic is powerful but has configuration quirks. The key to success:
1. Understand the quirks
2. Work around them systematically
3. Verify everything
4. Keep fix scripts handy
5. Document what works

This script and documentation represent hard-won knowledge from real-world testing. The configuration pattern it implements is proven to work reliably despite firmware bugs.
