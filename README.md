# Auto Focus Display

Automatically focus a macOS display when the cursor moves to it, using yabai window manager.

## What It Does

This tool monitors cursor movement and automatically focuses the display (and a window on that display) when your cursor crosses display boundaries. It's designed for multi-monitor setups where you want focus to follow your cursor seamlessly.

## Requirements

- **macOS** (tested on macOS Sonoma and later)
- **yabai** window manager ([Install Guide](https://github.com/koekeishiya/yabai/wiki/Installing-yabai))
- **Accessibility Permissions** for the compiled binary
- **Xcode Command Line Tools** (for compilation)

## Quick Install

```bash
./install.sh
```

This will:
1. Compile the Swift script
2. Install the binary to `~/bin/`
3. Create an Automator app
4. Add it to your Login Items for auto-start
5. Start the service immediately

## Uninstall

```bash
./uninstall.sh
```

This will safely remove all components and restore your system to its previous state.

## Known Issues

⚠️ **CPU Usage**: On some systems (including the author's), CPU usage can increase by approximately **30%** when frequently switching the cursor between displays. This is likely due to the high-frequency event monitoring and yabai queries. If you experience performance issues:

- Increase `debounceSeconds` (currently 0.18) in the Swift script
- Increase `throttleMs` (currently 12) in the Swift script
- Consider using only when needed, not as an always-on service

## Configuration

Edit the Swift script to customize behavior:

```swift
let DEBUG = false                          // Enable debug logging
let debounceSeconds: TimeInterval = 0.18   // Avoid double-switch on corners
let throttleMs: UInt64 = 12                // Handle at most every 12ms (~83Hz)
let YABAI = "/opt/homebrew/bin/yabai"      // Path to yabai binary
```

After editing, run `./build.sh` to recompile.

## How It Works

1. **Event Monitoring**: Creates a low-level event tap to monitor mouse movements
2. **Display Detection**: Detects when cursor crosses display boundaries
3. **Focus Window**: Attempts to focus the window under the cursor using yabai
4. **Fallback**: If no window is under cursor, focuses the first visible window on that display

## Manual Setup

If you prefer manual installation:

### 1. Compile the Script

```bash
./build.sh
```

### 2. Create Automator App

1. Open **Automator**
2. Create new **Application**
3. Add action: **Run Shell Script**
4. Set shell to: `/bin/zsh`
5. Paste: `~/bin/start-focus-display.sh`
6. Save as `focus_display.app` in `~/Applications/`

### 3. Grant Permissions

1. Run the app once
2. System Settings → Privacy & Security → Accessibility
3. Enable `focus_display.app`

### 4. Add to Login Items

1. System Settings → General → Login Items
2. Click `+` and add `focus_display.app`

## Troubleshooting

### "Failed to create event tap"

Grant Accessibility and Input Monitoring permissions:
- System Settings → Privacy & Security → Accessibility
- System Settings → Privacy & Security → Input Monitoring

### yabai not found

Update the `YABAI` path in `focus-display-on-cursor.swift` to match your installation:

```bash
which yabai  # Find your yabai path
```

### High CPU Usage

Increase throttling values in the Swift script (see Configuration above).

### Not starting on login

Check Login Items in System Settings and ensure the app is enabled.

## Files Created

- `~/bin/focus-display-on-cursor` - Compiled binary
- `~/bin/focus-display-on-cursor.swift` - Source script
- `~/bin/start-focus-display.sh` - Wrapper script with logging
- `~/Applications/focus_display.app` - Automator app
- `~/Library/Logs/focus-display-on-cursor.log` - Output log
- `~/Library/Logs/focus-display-on-cursor-error.log` - Error log

## License

MIT License - feel free to use, modify, and distribute.

## Contributing

Issues and pull requests welcome!

## Credits

Created as a personal workflow enhancement for multi-monitor macOS setups with yabai.
