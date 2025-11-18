# Auto Focus Display

Automatically focus a macOS display when the cursor moves to it, using yabai window manager.

## What It Does

This tool monitors cursor movement and automatically focuses the display (and a window on that display) when your cursor crosses display boundaries. It's designed for multi-monitor setups where you want focus to follow your cursor seamlessly.

**Focus behavior:** Focus only changes when moving cursor between displays, NOT between windows on the same display.

## Table of Contents

- [Requirements](#requirements)
- [Fresh Mac Installation](#fresh-mac-installation)
- [Quick Install](#quick-install)
- [Usage Patterns](#usage-patterns)
- [Configuration](#configuration)
- [How It Works](#how-it-works)
- [Manual Setup](#manual-setup)
- [Troubleshooting](#troubleshooting)
- [Known Issues](#known-issues)
- [Uninstall](#uninstall)

## Requirements

- **macOS** (tested on macOS Sonoma and later)
- **yabai** window manager (v6.0.0+) - **Required and must be running**
- **Xcode Command Line Tools** (for compilation)
- **Accessibility Permissions** for the app
- **Input Monitoring Permissions** for the app

## Fresh Mac Installation

If you're setting this up on a fresh Mac, follow these steps:

### Step 1: Install Xcode Command Line Tools

```bash
xcode-select --install
```

Wait for installation to complete, then verify:

```bash
swiftc --version
```

### Step 2: Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/brew/HEAD/install.sh)"
```

Follow the post-installation instructions to add Homebrew to your PATH.

### Step 3: Install yabai

```bash
# Install yabai
brew install koekeishiya/formulae/yabai

# Verify installation
yabai --version
```

### Step 4: Configure yabai

Create a minimal yabai configuration. You can use a full tiling setup or a minimal config:

**Minimal configuration (float mode, only for display focusing):**

```bash
cat > ~/.yabairc <<'EOF'
#!/usr/bin/env sh

# Load scripting addition (enables space switching)
yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
sudo yabai --load-sa

# Disable window management - only used for display/space queries
yabai -m config layout                       float
yabai -m config mouse_follows_focus          off
yabai -m config focus_follows_mouse          off
yabai -m config window_placement             second_child

# Disable all window management for all apps
yabai -m rule --add app=".*" manage=off

echo "yabai configuration loaded - minimal setup for display focusing"
EOF

chmod +x ~/.yabairc
```

**Note:** The scripting addition (`sudo yabai --load-sa`) requires System Integrity Protection (SIP) to be partially disabled. If you don't want to disable SIP, you can skip this, but some features may be limited. See [yabai docs](https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection) for details.

### Step 5: Start yabai

```bash
# Start yabai as a service (will auto-start on login)
brew services start yabai

# OR start manually (won't auto-start on login)
yabai
```

Verify yabai is running:

```bash
yabai -m query --displays
```

### Step 6: Install focus-display tool

```bash
# Navigate to the auto-focus-display directory
cd /path/to/auto-focus-display

# Run installation script
./install.sh
```

The installer will:
1. Compile the Swift script
2. Install binary to `~/bin/focus-display-on-cursor`
3. Create wrapper script `~/bin/start-focus-display.sh`
4. Create Automator app at `/Applications/focus_display.app`
5. **Optionally** add to Login Items (not recommended due to CPU usage)

### Step 7: Grant Permissions

After running the app for the first time, you'll need to grant permissions:

1. **Run the app:**
   ```bash
   open /Applications/focus_display.app
   ```

2. **Grant Accessibility permission:**
   - macOS will prompt you, or go to:
   - System Settings → Privacy & Security → Accessibility
   - Find and enable `focus_display.app` (or `Automator Application Stub`)
   - You may need to click the lock icon to make changes

3. **Grant Input Monitoring permission:**
   - System Settings → Privacy & Security → Input Monitoring
   - Find and enable `focus_display.app`

4. **Verify it's running:**
   ```bash
   pgrep -fl focus-display
   ```

   You should see output like:
   ```
   2275 /Users/yourname/bin/focus-display-on-cursor
   ```

5. **Test the functionality:**
   - If you have multiple displays, move your cursor between them
   - Focus should automatically switch to the display under your cursor
   - Focus should NOT change when moving between windows on the same display

### Step 8: Verify Installation

```bash
# Check if binary exists and is executable
ls -lah ~/bin/focus-display-on-cursor

# Check if app exists
ls -d /Applications/focus_display.app

# View logs (should be empty if no errors)
tail ~/Library/Logs/focus-display-on-cursor-error.log
```

## Quick Install

**If you already have yabai installed and configured**, run:

```bash
./install.sh
```

This will:
1. Compile the Swift script
2. Install the binary to `~/bin/`
3. Create an Automator app at `/Applications/focus_display.app`
4. Optionally add it to Login Items
5. Start the service immediately

## Usage Patterns

Due to potential CPU usage (~30% on some systems), there are two recommended usage patterns:

### Pattern 1: On-Demand (Recommended)

**Best for:** Users who want the feature sometimes but don't want constant CPU usage.

**Setup:**
- Do NOT add to Login Items
- Launch manually when needed: `open /Applications/focus_display.app`
- Quit when not needed: `killall focus-display-on-cursor`

**Pros:**
- No CPU impact when not in use
- Full control over when feature is active

**Cons:**
- Must manually start/stop

### Pattern 2: Always-On Background Service

**Best for:** Users who always want the feature and don't mind CPU usage.

**Setup:**
1. Add to Login Items:
   - System Settings → General → Login Items
   - Click `+` and add `/Applications/focus_display.app`
2. The service will auto-start on login

**Pros:**
- Always available
- No manual intervention needed

**Cons:**
- Constant CPU usage (~30% during cursor movement)
- May impact battery life on laptops

### Quick Commands

```bash
# Start manually
open /Applications/focus_display.app

# Check if running
pgrep -fl focus-display

# Stop the service
killall focus-display-on-cursor

# View error logs
tail -f ~/Library/Logs/focus-display-on-cursor-error.log

# View output logs
tail -f ~/Library/Logs/focus-display-on-cursor.log
```

## Configuration

Edit the Swift script to customize behavior:

```swift
let DEBUG = false                          // Enable debug logging
let debounceSeconds: TimeInterval = 0.18   // Avoid double-switch on corners
let throttleMs: UInt64 = 12                // Handle at most every 12ms (~83Hz)
let YABAI = "/opt/homebrew/bin/yabai"      // Path to yabai binary
```

**Location:** `~/bin/focus-display-on-cursor.swift` (after installation) or `focus-display-on-cursor.swift` (source)

After editing, rebuild:

```bash
./build.sh

# Then reinstall the binary
cp focus-display-on-cursor ~/bin/

# Restart the service
killall focus-display-on-cursor
open /Applications/focus_display.app
```

### Reducing CPU Usage

If experiencing high CPU usage, try:

1. **Increase throttle interval:**
   ```swift
   let throttleMs: UInt64 = 50  // ~20Hz instead of ~83Hz
   ```

2. **Increase debounce time:**
   ```swift
   let debounceSeconds: TimeInterval = 0.3  // Slower response
   ```

3. **Use on-demand pattern** (see [Usage Patterns](#usage-patterns))

## How It Works

### Technical Overview

1. **Event Monitoring**: Creates a low-level CoreGraphics event tap to monitor `mouseMoved` events
2. **Throttling**: Processes events at most every 12ms (~83Hz) to reduce CPU load
3. **Display Detection**: Maintains cached display rectangles, detects when cursor crosses boundaries
4. **Debouncing**: 180ms debounce prevents double-switching at display corners
5. **Focus Strategy**:
   - Queries yabai to identify display under cursor
   - Attempts to focus window directly under cursor
   - Falls back to focusing first visible window on that display
6. **App Activation**: Uses `NSRunningApplication` to activate apps without warping cursor

### Architecture

```
Automator App (/Applications/focus_display.app)
    ↓ launches
Shell Script (~/bin/start-focus-display.sh)
    ↓ executes with logging
Swift Binary (~/bin/focus-display-on-cursor)
    ↓ queries
yabai (window manager)
    ↓ controls
macOS Window Focus
```

## Manual Setup

If you prefer manual installation over `./install.sh`:

### 1. Compile the Script

```bash
./build.sh
```

This creates `focus-display-on-cursor` binary.

### 2. Install Binary and Scripts

```bash
# Create bin directory if it doesn't exist
mkdir -p ~/bin

# Install binary
cp focus-display-on-cursor ~/bin/
chmod +x ~/bin/focus-display-on-cursor

# Install source (for reference)
cp focus-display-on-cursor.swift ~/bin/

# Create start script
cat > ~/bin/start-focus-display.sh <<'EOF'
#!/bin/bash
# Start focus-display-on-cursor in the background
$HOME/bin/focus-display-on-cursor > $HOME/Library/Logs/focus-display-on-cursor.log 2> $HOME/Library/Logs/focus-display-on-cursor-error.log &
EOF

chmod +x ~/bin/start-focus-display.sh
```

### 3. Create Automator App

1. Open **Automator** (`Cmd + Space`, type "Automator")
2. Create new **Application**
3. Search for and add action: **Run Shell Script**
4. Configure the action:
   - Shell: `/bin/zsh`
   - Pass input: `to stdin`
   - Script content: `~/bin/start-focus-display.sh`
5. File → Save
   - Name: `focus_display`
   - Location: `/Applications/` (NOT `~/Applications/`)
   - Format: Application

### 4. Grant Permissions

1. **Launch the app:**
   ```bash
   open /Applications/focus_display.app
   ```

2. **Grant Accessibility permission:**
   - System Settings → Privacy & Security → Accessibility
   - Enable `focus_display.app`

3. **Grant Input Monitoring permission:**
   - System Settings → Privacy & Security → Input Monitoring
   - Enable `focus_display.app`

### 5. (Optional) Add to Login Items

⚠️ Only do this if you want always-on behavior (see [Usage Patterns](#usage-patterns))

1. System Settings → General → Login Items
2. Click `+` and add `/Applications/focus_display.app`
3. Optionally check "Hide" to prevent it from showing in Dock

## Troubleshooting

### "Failed to create event tap"

**Cause:** Missing Accessibility or Input Monitoring permissions.

**Solution:**
1. System Settings → Privacy & Security → Accessibility
2. Find `focus_display.app` and enable it
3. System Settings → Privacy & Security → Input Monitoring
4. Find `focus_display.app` and enable it
5. Restart the app: `killall focus-display-on-cursor && open /Applications/focus_display.app`

### yabai not found / "No such file or directory"

**Cause:** yabai not installed or wrong path in configuration.

**Solution:**
1. Check if yabai is installed:
   ```bash
   which yabai
   ```

2. If not installed:
   ```bash
   brew install koekeishiya/formulae/yabai
   ```

3. If installed but different path, update the Swift script:
   ```bash
   # Edit the YABAI constant
   nano ~/bin/focus-display-on-cursor.swift

   # Change this line to match your path:
   let YABAI = "/your/path/to/yabai"

   # Rebuild
   cd /path/to/auto-focus-display
   ./build.sh
   cp focus-display-on-cursor ~/bin/

   # Restart
   killall focus-display-on-cursor
   open /Applications/focus_display.app
   ```

### Focus not switching

1. **Check yabai is running:**
   ```bash
   yabai -m query --displays
   ```
   If error, start yabai: `brew services start yabai`

2. **Check focus-display is running:**
   ```bash
   pgrep -fl focus-display
   ```
   If not running: `open /Applications/focus_display.app`

3. **Check error logs:**
   ```bash
   tail -50 ~/Library/Logs/focus-display-on-cursor-error.log
   ```

4. **Enable debug mode:**
   ```bash
   # Edit Swift script
   nano ~/bin/focus-display-on-cursor.swift

   # Change to:
   let DEBUG = true

   # Rebuild and restart
   cd /path/to/auto-focus-display
   ./build.sh
   cp focus-display-on-cursor ~/bin/
   killall focus-display-on-cursor
   open /Applications/focus_display.app

   # Watch debug output
   tail -f ~/Library/Logs/focus-display-on-cursor-error.log
   ```

### High CPU Usage

**Expected behavior:** ~30% CPU usage during active cursor movement between displays.

**Solutions:**

1. **Use on-demand pattern** (see [Usage Patterns](#usage-patterns))

2. **Reduce polling frequency:**
   ```swift
   let throttleMs: UInt64 = 50  // Slower but less CPU
   ```

3. **Increase debounce:**
   ```swift
   let debounceSeconds: TimeInterval = 0.5  // Less responsive but less CPU
   ```

4. **Check for runaway processes:**
   ```bash
   top -pid $(pgrep focus-display-on-cursor)
   ```

### Not starting on login

1. **Check Login Items:**
   ```bash
   osascript -e 'tell application "System Events" to get the name of every login item'
   ```

2. **Add manually:**
   - System Settings → General → Login Items
   - Click `+` → Navigate to `/Applications/focus_display.app`
   - Click "Add"

3. **Check app permissions** (see above)

### Permission dialogs not appearing

If macOS doesn't prompt for permissions:

1. **Manually reset permissions:**
   ```bash
   # Reset Accessibility database (requires password)
   tccutil reset Accessibility com.apple.automator.focus-display

   # Restart the app
   killall focus-display-on-cursor
   open /Applications/focus_display.app
   ```

2. **Manually add to Accessibility:**
   - System Settings → Privacy & Security → Accessibility
   - Click lock icon to unlock
   - Click `+` button
   - Navigate to `/Applications/focus_display.app`
   - Add and enable

## Known Issues

### CPU Usage

⚠️ **High CPU usage (~30%) during cursor movement between displays**

**Why:** High-frequency event monitoring (83Hz) + CoreGraphics queries + yabai process calls

**Workarounds:**
- Use on-demand pattern (recommended)
- Increase throttle/debounce values
- Only run when actively using multiple displays

**Status:** Investigating optimization strategies. Contributions welcome!

### SIP Partially Disabled Requirement (Optional)

yabai's scripting addition requires SIP to be partially disabled for full functionality. However, this tool works without scripting addition if you:
- Only use display focusing (no space management)
- Remove or comment out the `--load-sa` lines from `.yabairc`

See [yabai SIP docs](https://github.com/koekeishiya/yabai/wiki/Disabling-System-Integrity-Protection) for details.

## Uninstall

```bash
./uninstall.sh
```

This will safely remove all components:
- Stop running service
- Remove from Login Items
- Delete `/Applications/focus_display.app`
- Delete `~/bin/focus-display-on-cursor*`
- Optionally delete logs and backups

Manual uninstall:

```bash
# Stop service
killall focus-display-on-cursor

# Remove files
rm -rf /Applications/focus_display.app
rm ~/bin/focus-display-on-cursor*
rm ~/bin/start-focus-display.sh

# Remove from Login Items
# System Settings → General → Login Items → Remove focus_display

# Optional: Remove logs
rm ~/Library/Logs/focus-display-on-cursor*.log
```

## Files Created

After installation:

- `~/bin/focus-display-on-cursor` - Compiled binary (122 KB)
- `~/bin/focus-display-on-cursor.swift` - Source script (7.9 KB)
- `~/bin/start-focus-display.sh` - Wrapper script with logging
- `/Applications/focus_display.app` - Automator app (launches the service)
- `~/Library/Logs/focus-display-on-cursor.log` - Output log
- `~/Library/Logs/focus-display-on-cursor-error.log` - Error log

## Integration with yabai

This tool is designed to complement yabai configurations. Example `.yabairc` snippet:

```bash
#!/usr/bin/env sh

# Auto-focus display when mouse moves between displays
# Using Swift event tap (see ~/bin/focus-display-on-cursor)
# Launched via /Applications/focus_display.app

# ... rest of your yabai config ...
```

## Performance Characteristics

- **Binary size:** ~122 KB (optimized build)
- **Memory usage:** ~9 MB resident
- **CPU usage (idle):** <1%
- **CPU usage (active):** ~30% during cursor movement
- **Event frequency:** 83 Hz (~12ms intervals)
- **Response latency:** ~180-200ms (debounce + processing)

## License

MIT License - feel free to use, modify, and distribute.

## Contributing

Issues and pull requests welcome!

**Areas for improvement:**
- CPU usage optimization
- Alternative event monitoring approaches
- Better integration with yabai features
- Support for other window managers

## Credits

Created as a personal workflow enhancement for multi-monitor macOS setups with yabai.

**Author's setup:** macOS Sonoma, yabai (float mode), multiple external displays, on-demand usage pattern.
