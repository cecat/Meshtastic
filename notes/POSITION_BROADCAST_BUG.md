# The position_broadcast_secs Reversion Bug

## The Problem

Meshtastic firmware has a persistent bug where `position.position_broadcast_secs` keeps reverting from the desired value (120 seconds) back to the default (43200 seconds / 12 hours). This causes nodes to stop updating on meshmap.net.

## Why It Happens

The firmware appears to reset this value when:
1. ANY position-related setting is changed (altitude, coordinates, etc.)
2. MQTT settings are modified
3. The device reboots after certain configuration changes
4. Seemingly random other configuration changes

## The Evidence

From your CEC2 outputs:
- **First check**: `positionBroadcastSecs: 43200` (12 hours) ❌
- **After manual fix**: Node reported once, then stopped
- **Current check**: `positionBroadcastSecs: 43200` again ❌

Meanwhile CEC1 has been stable at 120 seconds and reports consistently.

## Solutions

### Immediate Fix (Use Every Time It Breaks)

```bash
# For USB connection:
meshtastic --port /dev/cu.SLAB_USBtoUART --set position.position_broadcast_secs 120

# For network connection:
meshtastic --host 10.0.5.105 --set position.position_broadcast_secs 120
```

### Quick Check Script

Use `fix-cec2-broadcast.sh` to quickly verify and fix:
```bash
./fix-cec2-broadcast.sh
```

### Prevention Strategy

1. **Set it multiple times** - The updated setup script now sets it 3 times with delays
2. **Set it LAST** - Always set position_broadcast_secs after all other config changes
3. **Verify after reboot** - Always check this value after the device restarts
4. **Keep a copy of the fix command** - You'll need it frequently

### Verification Commands

Check current value:
```bash
meshtastic --host 10.0.5.105 --get position.position_broadcast_secs
```

Check full position config:
```bash
meshtastic --host 10.0.5.105 --get position
```

Get complete node info:
```bash
meshtastic --host 10.0.5.105 --info | grep -A 20 "position"
```

## Why 43200 Is Wrong

- **43200 seconds = 12 hours** between broadcasts
- This means the node only updates the mesh network twice per day
- meshmap.net won't show updates for 12+ hours
- CEC1 broadcasts every **120 seconds = 2 minutes** and updates reliably

## Best Practice Workflow

When making ANY configuration change to CEC2:

1. Make your config change
2. Immediately re-run: `meshtastic --host 10.0.5.105 --set position.position_broadcast_secs 120`
3. Verify: `meshtastic --host 10.0.5.105 --get position.position_broadcast_secs`
4. If it shows 43200, run the set command again
5. After reboot, verify again

## Alternative: Lock Down CEC2 Configuration

Consider setting CEC2 to `device.is_managed true` after configuration is complete. This makes the device read-only via API, preventing accidental changes. However, you'd need to unlock it to make future changes.

## The Real Solution

This needs to be fixed in Meshtastic firmware. Consider:
1. Reporting this as a bug on the Meshtastic GitHub
2. Checking if a newer firmware version has fixed this
3. Documenting this behavior in your node management procedures

## Summary

This is not your fault - it's a firmware quirk. The value WILL revert periodically. Keep the fix command handy and run it whenever CEC2 stops reporting to the map.
