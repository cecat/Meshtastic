# Script Structure - Final Design

## Overview

The Meshtastic configuration scripts have been simplified to eliminate redundancy while maintaining full functionality for both USB and network (OTA) configuration.

## Final Script Set

### 1. radio-setup.sh (USB Only)
**Purpose**: Initial setup from factory reset

**When to use**:
- Brand new device
- Need factory reset
- Starting from scratch

**Unique feature**: Only script that does factory reset (requires USB)

### 2. radio-tuneup.sh (USB or Network - Universal)
**Purpose**: Apply/update configuration

**When to use**:
- ANY configuration update (except factory reset)
- Remote configuration via WiFi
- After firmware updates
- Fix settings that reverted (including broadcast interval)
- Regular maintenance

**Key feature**: Universal - same script works via USB or network, just change one variable

**Built-in protection**: Automatically triple-verifies critical settings to prevent firmware bugs

## Design Philosophy

### Eliminated Redundancy
**Before**: Had multiple scripts doing similar things
- `radio-setup.sh` - USB with factory reset
- `radio-ota-setup.sh` - Network without factory reset
- `radio-tuneup.sh` - USB or network without factory reset
- `fix-cec2-broadcast.sh` - Quick fix for one setting

**Problem**: Three scripts doing configuration, plus a fourth for a subset

**After**: Two scripts with clear purposes
- `radio-setup.sh` - USB with factory reset (unique capability)
- `radio-tuneup.sh` - Universal configuration (USB or network)

**Result**: Clean, simple, no overlap

### Universal Configuration Pattern

`radio-tuneup.sh` achieves universality through simple variable switching:

```bash
# For USB connection:
CONNECTION_TYPE="usb"
PORT="/dev/cu.SLAB_USBtoUART"

# For network connection:
CONNECTION_TYPE="network"
NODE_IP="10.0.5.105"
```

Same script, same configuration logic, different connection method.

## What Can Be Done OTA

### ✅ Everything Except Factory Reset
All of these work via `--host IP_ADDRESS`:
- Configuration settings (`--set`)
- Position updates (`--setlat`, `--setlon`, `--setalt`)
- Names (`--set-owner`)
- MQTT settings
- Channel configuration
- Reboots
- Status queries

### ❌ Only Factory Reset Requires USB
- `--factory-reset` - Intentional security feature
- Prevents remote wiping of devices
- Requires physical access

## Usage Examples

### Initial Setup (Brand New Device)
```bash
# Flash firmware at https://flasher.meshtastic.org
# Edit secrets.sh
# Edit radio-setup.sh (PORT, names)
./radio-setup.sh
```

### Remote Configuration (Device on Network)
```bash
# Edit secrets.sh
# Edit radio-tuneup.sh:
#   CONNECTION_TYPE="network"
#   NODE_IP="10.0.5.105"
./radio-tuneup.sh
```

### After Firmware Update (USB Available)
```bash
# Edit radio-tuneup.sh:
#   CONNECTION_TYPE="usb"
#   PORT="/dev/cu.SLAB_USBtoUART"
./radio-tuneup.sh
```

### Fix Broadcast Interval Issue (Network)
```bash
# Same script, automatically verifies all settings
# Edit radio-tuneup.sh:
#   CONNECTION_TYPE="network"
#   NODE_IP="10.0.5.105"
./radio-tuneup.sh
```

## Decision Tree

```
What do you need?
│
├─ Factory reset?
│  └─ YES → radio-setup.sh (USB required)
│
└─ Configure/update settings?
   └─ radio-tuneup.sh
      ├─ Have USB? → Set CONNECTION_TYPE="usb"
      └─ Remote?   → Set CONNECTION_TYPE="network"
```

## Benefits of This Design

### Simplicity
- Two main scripts instead of three
- Clear purpose for each
- Less confusion about which to use

### Flexibility
- `radio-tuneup.sh` works anywhere
- Same script for USB or network
- One script to learn and maintain

### Maintainability
- Single source of configuration logic
- Changes apply to both USB and network use
- Easier to update and improve

### User Experience
- "Use radio-tuneup.sh for everything except factory reset"
- Simple mental model
- Works how you'd expect

## File Structure

```
meshtastic-setup/
├── radio-setup.sh           # Initial setup (USB, with factory reset)
├── radio-tuneup.sh          # Universal configuration (USB or network)
├── secrets.sh.template      # Template for configuration
├── secrets.sh               # Your actual config (gitignored)
├── README.md                # Complete setup and usage guide
├── SETUP_NOTES.md           # Implementation notes
├── SCRIPT_STRUCTURE.md      # Design rationale
└── notes/                   # Additional technical documentation
    ├── OTA_GUIDE.md         # Remote configuration details
    ├── LESSONS_LEARNED.md   # Technical insights
    └── POSITION_BROADCAST_BUG.md # Bug documentation
```

## Key Takeaway

**Simplest possible structure**: 
- Need factory reset? → `radio-setup.sh`
- Everything else? → `radio-tuneup.sh`

That's it. Two scripts. One universal tool. Clear purpose. Zero redundancy.
