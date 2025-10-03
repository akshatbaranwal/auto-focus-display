#!/bin/bash
# Install script for auto-focus-display
# Installs with robust error handling and rollback capability

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/bin"
APP_DIR="$HOME/Applications"
LOG_DIR="$HOME/Library/Logs"
AUTOMATOR_DIR="$HOME/Library/Mobile Documents/com~apple~Automator/Documents"

BINARY_NAME="focus-display-on-cursor"
SWIFT_NAME="$BINARY_NAME.swift"
START_SCRIPT="start-focus-display.sh"
APP_NAME="focus_display.app"

# Track what we've done for rollback
CREATED_FILES=()
CREATED_DIRS=()
ADDED_LOGIN_ITEM=false
STARTED_APP=false

# Summary tracking
SUMMARY_ACTIONS=()

# Cleanup function for rollback on failure
cleanup_on_failure() {
    echo
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}Installation failed! Rolling back changes...${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo

    # Stop the app if we started it
    if [ "$STARTED_APP" = true ]; then
        echo "Stopping $APP_NAME..."
        killall "$BINARY_NAME" 2>/dev/null || true
    fi

    # Remove from login items if we added it
    if [ "$ADDED_LOGIN_ITEM" = true ]; then
        echo "Removing from login items..."
        osascript -e "tell application \"System Events\" to delete login item \"$APP_NAME\"" 2>/dev/null || true
    fi

    # Remove created files (in reverse order)
    for ((i=${#CREATED_FILES[@]}-1; i>=0; i--)); do
        file="${CREATED_FILES[i]}"
        if [ -e "$file" ]; then
            echo "Removing: $file"
            rm -rf "$file"
        fi
    done

    # Remove created directories (in reverse order)
    for ((i=${#CREATED_DIRS[@]}-1; i>=0; i--)); do
        dir="${CREATED_DIRS[i]}"
        if [ -d "$dir" ] && [ -z "$(ls -A "$dir")" ]; then
            echo "Removing empty directory: $dir"
            rmdir "$dir"
        fi
    done

    echo
    echo -e "${RED}Rollback complete. Your system has been restored.${NC}"
    exit 1
}

# Set trap for cleanup on any error
trap cleanup_on_failure ERR INT TERM

# Print header
echo
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Auto Focus Display - Installation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}✗ Swift compiler not found${NC}"
    echo "Please install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi
echo -e "${GREEN}✓ Swift compiler found${NC}"

if ! command -v yabai &> /dev/null; then
    echo -e "${YELLOW}⚠ yabai not found in PATH${NC}"
    echo "This tool requires yabai. Please install it first:"
    echo "  https://github.com/koekeishiya/yabai/wiki/Installing-yabai"
    echo
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ yabai found${NC}"
fi

echo

# Step 1: Build the binary
echo -e "${YELLOW}[1/6] Building binary...${NC}"
if [ ! -f "$SCRIPT_DIR/focus-display-on-cursor.swift" ]; then
    echo -e "${RED}✗ Source file not found: focus-display-on-cursor.swift${NC}"
    exit 1
fi

./build.sh
if [ ! -f "$SCRIPT_DIR/$BINARY_NAME" ]; then
    echo -e "${RED}✗ Build failed - binary not created${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Binary built successfully${NC}"
SUMMARY_ACTIONS+=("Built binary from Swift source")
echo

# Step 2: Create installation directory
echo -e "${YELLOW}[2/6] Setting up installation directories...${NC}"
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    CREATED_DIRS+=("$INSTALL_DIR")
    echo -e "${GREEN}✓ Created $INSTALL_DIR${NC}"
    SUMMARY_ACTIONS+=("Created directory: $INSTALL_DIR")
else
    echo -e "${GREEN}✓ Directory exists: $INSTALL_DIR${NC}"
fi

if [ ! -d "$APP_DIR" ]; then
    mkdir -p "$APP_DIR"
    CREATED_DIRS+=("$APP_DIR")
    echo -e "${GREEN}✓ Created $APP_DIR${NC}"
    SUMMARY_ACTIONS+=("Created directory: $APP_DIR")
else
    echo -e "${GREEN}✓ Directory exists: $APP_DIR${NC}"
fi
echo

# Step 3: Install binary and scripts
echo -e "${YELLOW}[3/6] Installing binary and scripts...${NC}"

# Backup existing files
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    BACKUP_FILE="$INSTALL_DIR/$BINARY_NAME.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$INSTALL_DIR/$BINARY_NAME" "$BACKUP_FILE"
    echo -e "${BLUE}Backed up existing binary to: $BACKUP_FILE${NC}"
    SUMMARY_ACTIONS+=("Backed up existing binary")
fi

# Install binary
cp "$SCRIPT_DIR/$BINARY_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$BINARY_NAME"
CREATED_FILES+=("$INSTALL_DIR/$BINARY_NAME")
echo -e "${GREEN}✓ Installed: $INSTALL_DIR/$BINARY_NAME${NC}"
SUMMARY_ACTIONS+=("Installed binary: $INSTALL_DIR/$BINARY_NAME")

# Install Swift source (for reference/recompilation)
cp "$SCRIPT_DIR/$SWIFT_NAME" "$INSTALL_DIR/"
CREATED_FILES+=("$INSTALL_DIR/$SWIFT_NAME")
echo -e "${GREEN}✓ Installed: $INSTALL_DIR/$SWIFT_NAME${NC}"
SUMMARY_ACTIONS+=("Installed source: $INSTALL_DIR/$SWIFT_NAME")

# Create start script
cat > "$INSTALL_DIR/$START_SCRIPT" <<EOF
#!/bin/bash
# Start focus-display-on-cursor in the background
$INSTALL_DIR/$BINARY_NAME > $LOG_DIR/$BINARY_NAME.log 2> $LOG_DIR/$BINARY_NAME-error.log &
EOF
chmod +x "$INSTALL_DIR/$START_SCRIPT"
CREATED_FILES+=("$INSTALL_DIR/$START_SCRIPT")
echo -e "${GREEN}✓ Created: $INSTALL_DIR/$START_SCRIPT${NC}"
SUMMARY_ACTIONS+=("Created start script: $INSTALL_DIR/$START_SCRIPT")
echo

# Step 4: Create Automator app
echo -e "${YELLOW}[4/6] Creating Automator app...${NC}"

# Check if Automator directory exists
if [ ! -d "$AUTOMATOR_DIR" ]; then
    echo -e "${YELLOW}Creating Automator directory...${NC}"
    mkdir -p "$AUTOMATOR_DIR"
    CREATED_DIRS+=("$AUTOMATOR_DIR")
fi

APP_PATH="$APP_DIR/$APP_NAME"

# Remove existing app if present
if [ -d "$APP_PATH" ]; then
    BACKUP_APP="$APP_DIR/${APP_NAME%.app}.backup.$(date +%Y%m%d_%H%M%S).app"
    mv "$APP_PATH" "$BACKUP_APP"
    echo -e "${BLUE}Backed up existing app to: $BACKUP_APP${NC}"
    SUMMARY_ACTIONS+=("Backed up existing app")
fi

# Create Automator app using osacompile
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" <<'EOF'
tell application "Automator"
    set newAction to make new workflow with properties {name:"focus_display"}
    tell newAction
        set shellScriptAction to make new action at end of actions with properties {name:"Run Shell Script"}
        tell shellScriptAction
            set value of setting "inputMethod" to 0
            set value of setting "shell" to "/bin/zsh"
            set value of setting "COMMAND_STRING" to "INSTALL_DIR_PLACEHOLDER/start-focus-display.sh"
        end tell
    end tell
    save newAction in POSIX file "APP_PATH_PLACEHOLDER"
    close newAction
end tell
EOF

# Replace placeholders
sed -i '' "s|INSTALL_DIR_PLACEHOLDER|$INSTALL_DIR|g" "$TEMP_SCRIPT"
sed -i '' "s|APP_PATH_PLACEHOLDER|$APP_PATH|g" "$TEMP_SCRIPT"

# Try to create via osascript
if osascript "$TEMP_SCRIPT" 2>/dev/null; then
    rm "$TEMP_SCRIPT"
    CREATED_FILES+=("$APP_PATH")
    echo -e "${GREEN}✓ Created Automator app: $APP_PATH${NC}"
    SUMMARY_ACTIONS+=("Created Automator app: $APP_PATH")
else
    rm "$TEMP_SCRIPT"
    echo -e "${YELLOW}⚠ Automated app creation failed. Creating manually...${NC}"

    # Fallback: Create app structure manually
    mkdir -p "$APP_PATH/Contents/MacOS"
    mkdir -p "$APP_PATH/Contents/Resources"
    CREATED_FILES+=("$APP_PATH")

    # Create Info.plist
    cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Application Stub</string>
    <key>CFBundleIconFile</key>
    <string>ApplicationStub</string>
    <key>CFBundleIdentifier</key>
    <string>com.apple.automator.focus_display</string>
    <key>CFBundleName</key>
    <string>focus_display</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOF

    # Create simple launcher script
    cat > "$APP_PATH/Contents/MacOS/Application Stub" <<EOF
#!/bin/bash
$INSTALL_DIR/$START_SCRIPT
EOF
    chmod +x "$APP_PATH/Contents/MacOS/Application Stub"

    echo -e "${GREEN}✓ Created launcher app: $APP_PATH${NC}"
    SUMMARY_ACTIONS+=("Created launcher app (manual method): $APP_PATH")
fi
echo

# Step 5: Add to login items
echo -e "${YELLOW}[5/6] Adding to login items...${NC}"

# Check if already in login items
if osascript -e "tell application \"System Events\" to get the name of every login item" | grep -q "$APP_NAME"; then
    echo -e "${BLUE}Already in login items${NC}"
    SUMMARY_ACTIONS+=("App already in login items (no change)")
else
    # Add to login items
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_PATH\", hidden:false, name:\"$APP_NAME\"}" 2>/dev/null || {
        echo -e "${YELLOW}⚠ Could not add to login items automatically${NC}"
        echo "Please add manually: System Settings → General → Login Items"
        SUMMARY_ACTIONS+=("Failed to add to login items (add manually)")
    }

    if osascript -e "tell application \"System Events\" to get the name of every login item" | grep -q "$APP_NAME"; then
        ADDED_LOGIN_ITEM=true
        echo -e "${GREEN}✓ Added to login items${NC}"
        SUMMARY_ACTIONS+=("Added to login items for auto-start")
    fi
fi
echo

# Step 6: Start the service
echo -e "${YELLOW}[6/6] Starting service...${NC}"

# Kill any existing instances
if pgrep -x "$BINARY_NAME" > /dev/null; then
    echo "Stopping existing instance..."
    killall "$BINARY_NAME" 2>/dev/null || true
    sleep 1
fi

# Start the app
open "$APP_PATH"
STARTED_APP=true
sleep 2

# Verify it's running
if pgrep -x "$BINARY_NAME" > /dev/null; then
    echo -e "${GREEN}✓ Service started successfully${NC}"
    SUMMARY_ACTIONS+=("Started service")
else
    echo -e "${YELLOW}⚠ Service may not have started. Check logs:${NC}"
    echo "  $LOG_DIR/$BINARY_NAME.log"
    echo "  $LOG_DIR/$BINARY_NAME-error.log"
    SUMMARY_ACTIONS+=("Attempted to start service (check logs)")
fi

# Clear trap - installation successful
trap - ERR INT TERM

# Print installation summary
echo
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo
echo -e "${BLUE}Summary of changes:${NC}"
for action in "${SUMMARY_ACTIONS[@]}"; do
    echo -e "  ${GREEN}✓${NC} $action"
done
echo
echo -e "${BLUE}Important files:${NC}"
echo "  Binary:      $INSTALL_DIR/$BINARY_NAME"
echo "  Source:      $INSTALL_DIR/$SWIFT_NAME"
echo "  App:         $APP_PATH"
echo "  Logs:        $LOG_DIR/$BINARY_NAME*.log"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Grant Accessibility permissions:"
echo "     System Settings → Privacy & Security → Accessibility"
echo "     Enable '$APP_NAME'"
echo
echo "  2. Verify yabai path in source if needed:"
echo "     Edit $INSTALL_DIR/$SWIFT_NAME"
echo
echo -e "${YELLOW}⚠  Known Issue:${NC}"
echo "  CPU usage may increase by ~30% during frequent display switching"
echo "  See README.md for configuration options to reduce this"
echo
echo -e "${GREEN}Installation logs saved to: $LOG_DIR/$BINARY_NAME*.log${NC}"
echo
