#!/bin/bash
# Uninstall script for auto-focus-display
# Safely removes all components with proper error handling

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
INSTALL_DIR="$HOME/bin"
APP_DIR="/Applications"  # System-wide Applications folder
LOG_DIR="$HOME/Library/Logs"

BINARY_NAME="focus-display-on-cursor"
SWIFT_NAME="$BINARY_NAME.swift"
START_SCRIPT="start-focus-display.sh"
APP_NAME="focus_display.app"

# Summary tracking
SUMMARY_ACTIONS=()
ERRORS=()

# Function to safely remove a file
safe_remove_file() {
    local file="$1"
    local description="$2"

    if [ -e "$file" ]; then
        if rm -rf "$file" 2>/dev/null; then
            echo -e "${GREEN}✓ Removed: $description${NC}"
            SUMMARY_ACTIONS+=("Removed: $description")
            return 0
        else
            echo -e "${RED}✗ Failed to remove: $description${NC}"
            ERRORS+=("Failed to remove: $description")
            return 1
        fi
    else
        echo -e "${BLUE}  Not found: $description${NC}"
        return 0
    fi
}

# Function to safely remove from login items
safe_remove_login_item() {
    if osascript -e "tell application \"System Events\" to get the name of every login item" 2>/dev/null | grep -q "$APP_NAME"; then
        if osascript -e "tell application \"System Events\" to delete login item \"$APP_NAME\"" 2>/dev/null; then
            echo -e "${GREEN}✓ Removed from login items${NC}"
            SUMMARY_ACTIONS+=("Removed from login items")
            return 0
        else
            echo -e "${RED}✗ Failed to remove from login items${NC}"
            ERRORS+=("Failed to remove from login items (remove manually)")
            return 1
        fi
    else
        echo -e "${BLUE}  Not in login items${NC}"
        return 0
    fi
}

# Print header
echo
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Auto Focus Display - Uninstallation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo

# Confirm uninstallation
echo -e "${YELLOW}This will remove all components of auto-focus-display.${NC}"
echo
read -p "Continue with uninstallation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi
echo

# Step 1: Stop running instances
echo -e "${YELLOW}[1/5] Stopping running instances...${NC}"
if pgrep -x "$BINARY_NAME" > /dev/null; then
    if killall "$BINARY_NAME" 2>/dev/null; then
        echo -e "${GREEN}✓ Stopped $BINARY_NAME${NC}"
        SUMMARY_ACTIONS+=("Stopped running service")
        sleep 1
    else
        echo -e "${YELLOW}⚠ Could not stop $BINARY_NAME (may require manual termination)${NC}"
        ERRORS+=("Could not stop service (may require manual termination)")
    fi
else
    echo -e "${BLUE}  No running instances found${NC}"
fi
echo

# Step 2: Remove from login items
echo -e "${YELLOW}[2/5] Removing from login items...${NC}"
safe_remove_login_item
echo

# Step 3: Remove application
echo -e "${YELLOW}[3/5] Removing application...${NC}"
safe_remove_file "$APP_DIR/$APP_NAME" "Automator app"
echo

# Step 4: Remove installed files
echo -e "${YELLOW}[4/5] Removing installed files...${NC}"
safe_remove_file "$INSTALL_DIR/$BINARY_NAME" "Binary"
safe_remove_file "$INSTALL_DIR/$SWIFT_NAME" "Swift source"
safe_remove_file "$INSTALL_DIR/$START_SCRIPT" "Start script"

# Check for backup files
BACKUP_COUNT=$(find "$INSTALL_DIR" -name "$BINARY_NAME.backup.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$BACKUP_COUNT" -gt 0 ]; then
    echo
    echo -e "${YELLOW}Found $BACKUP_COUNT backup file(s)${NC}"
    read -p "Remove backup files? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find "$INSTALL_DIR" -name "$BINARY_NAME.backup.*" -exec rm {} \; 2>/dev/null
        echo -e "${GREEN}✓ Removed backup files${NC}"
        SUMMARY_ACTIONS+=("Removed backup files")
    else
        echo -e "${BLUE}  Kept backup files${NC}"
    fi
fi

APP_BACKUP_COUNT=$(find "$APP_DIR" -name "focus_display.backup.*.app" 2>/dev/null | wc -l | tr -d ' ')
if [ "$APP_BACKUP_COUNT" -gt 0 ]; then
    echo
    echo -e "${YELLOW}Found $APP_BACKUP_COUNT app backup(s)${NC}"
    read -p "Remove app backups? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        find "$APP_DIR" -name "focus_display.backup.*.app" -exec rm -rf {} \; 2>/dev/null
        echo -e "${GREEN}✓ Removed app backups${NC}"
        SUMMARY_ACTIONS+=("Removed app backups")
    else
        echo -e "${BLUE}  Kept app backups${NC}"
    fi
fi
echo

# Step 5: Handle log files
echo -e "${YELLOW}[5/5] Handling log files...${NC}"
LOG_FILES_EXIST=false
if [ -f "$LOG_DIR/$BINARY_NAME.log" ] || [ -f "$LOG_DIR/$BINARY_NAME-error.log" ]; then
    LOG_FILES_EXIST=true
fi

if [ "$LOG_FILES_EXIST" = true ]; then
    echo -e "${YELLOW}Log files found${NC}"
    read -p "Remove log files? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        safe_remove_file "$LOG_DIR/$BINARY_NAME.log" "Output log"
        safe_remove_file "$LOG_DIR/$BINARY_NAME-error.log" "Error log"
    else
        echo -e "${BLUE}  Kept log files:${NC}"
        [ -f "$LOG_DIR/$BINARY_NAME.log" ] && echo "    $LOG_DIR/$BINARY_NAME.log"
        [ -f "$LOG_DIR/$BINARY_NAME-error.log" ] && echo "    $LOG_DIR/$BINARY_NAME-error.log"
        SUMMARY_ACTIONS+=("Kept log files for review")
    fi
else
    echo -e "${BLUE}  No log files found${NC}"
fi

# Print uninstallation summary
echo
if [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Uninstallation Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
else
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Uninstallation Completed with Warnings${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
fi

echo
echo -e "${BLUE}Summary of changes:${NC}"
if [ ${#SUMMARY_ACTIONS[@]} -eq 0 ]; then
    echo -e "  ${BLUE}No components were found to remove${NC}"
else
    for action in "${SUMMARY_ACTIONS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $action"
    done
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo
    echo -e "${YELLOW}Warnings/Errors:${NC}"
    for error in "${ERRORS[@]}"; do
        echo -e "  ${YELLOW}⚠${NC} $error"
    done
fi

echo
echo -e "${BLUE}Manual cleanup (if needed):${NC}"
echo "  • Check System Settings → Privacy & Security → Accessibility"
echo "    Remove '$APP_NAME' if still listed"
echo "  • Check System Settings → General → Login Items"
echo "    Remove '$APP_NAME' if still listed"

# Check if process is still running
if pgrep -x "$BINARY_NAME" > /dev/null; then
    echo
    echo -e "${YELLOW}⚠ Warning: $BINARY_NAME is still running${NC}"
    echo "  Kill manually with: killall $BINARY_NAME"
fi

echo
if [ ${#ERRORS[@]} -eq 0 ]; then
    echo -e "${GREEN}All components successfully removed!${NC}"
    echo -e "${GREEN}Thank you for using auto-focus-display.${NC}"
else
    echo -e "${YELLOW}Uninstallation completed with some warnings (see above).${NC}"
fi
echo
