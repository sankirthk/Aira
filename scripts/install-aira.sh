#!/bin/bash
#
# Aira Installer — for testers and early feedback
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOURUSERNAME/Aira/Dev/install-aira.sh | bash
#
# Or if you already have the zip/app:
#   bash install-aira.sh /path/to/Aira.app
#

set -euo pipefail

APP_NAME="Aira"
INSTALL_DIR="/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME.app"

# --- Color output ---
bold() { printf "\033[1m%s\033[0m" "$1"; }
green() { printf "\033[32m%s\033[0m" "$1"; }
red() { printf "\033[31m%s\033[0m" "$1"; }
dim() { printf "\033[2m%s\033[0m" "$1"; }

echo ""
echo "  $(bold 'Aira Installer')"
echo "  $(dim 'Stealth teleprompter for presenters')"
echo ""

# --- Locate the app ---
APP_SOURCE=""

if [[ $# -ge 1 ]]; then
    # User passed a path to the .app or a .zip/.dmg
    INPUT="$1"

    if [[ -d "$INPUT" && "$INPUT" == *.app ]]; then
        APP_SOURCE="$INPUT"
    elif [[ -f "$INPUT" && "$INPUT" == *.zip ]]; then
        echo "  Extracting $(basename "$INPUT")..."
        TEMP_DIR=$(mktemp -d)
        unzip -q "$INPUT" -d "$TEMP_DIR"
        APP_SOURCE=$(find "$TEMP_DIR" -name "*.app" -maxdepth 2 -type d | head -1)
        if [[ -z "$APP_SOURCE" ]]; then
            echo "  $(red 'Error'): No .app found inside the zip."
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        echo "  $(red 'Error'): Pass a path to Aira.app or a .zip containing it."
        exit 1
    fi
else
    # No argument — check if Aira.app is in common locations
    for candidate in \
        "$HOME/Downloads/$APP_NAME.app" \
        "$HOME/Desktop/$APP_NAME.app" \
        "./$APP_NAME.app"; do
        if [[ -d "$candidate" ]]; then
            APP_SOURCE="$candidate"
            break
        fi
    done

    if [[ -z "$APP_SOURCE" ]]; then
        # Check for zip in Downloads
        for candidate in "$HOME/Downloads/$APP_NAME"*.zip; do
            if [[ -f "$candidate" ]]; then
                echo "  Extracting $(basename "$candidate")..."
                TEMP_DIR=$(mktemp -d)
                unzip -q "$candidate" -d "$TEMP_DIR"
                APP_SOURCE=$(find "$TEMP_DIR" -name "*.app" -maxdepth 2 -type d | head -1)
                if [[ -n "$APP_SOURCE" ]]; then
                    break
                fi
                rm -rf "$TEMP_DIR"
            fi
        done
    fi

    if [[ -z "$APP_SOURCE" ]]; then
        echo "  $(red 'Error'): Could not find Aira.app."
        echo ""
        echo "  Either:"
        echo "    1. Download Aira.app or Aira.zip to your Downloads folder and rerun this script"
        echo "    2. Run: bash install-aira.sh /path/to/Aira.app"
        echo ""
        exit 1
    fi
fi

echo "  Found: $(basename "$APP_SOURCE")"

# --- Quit Aira if running ---
if pgrep -xq "$APP_NAME"; then
    echo "  Quitting running instance..."
    osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
    sleep 1
fi

# --- Copy to Applications ---
echo "  Installing to $INSTALL_DIR..."
if [[ -d "$INSTALLED_APP" ]]; then
    rm -rf "$INSTALLED_APP"
fi
cp -R "$APP_SOURCE" "$INSTALLED_APP"

# --- Remove quarantine (the key fix for unsigned apps) ---
echo "  Removing quarantine flag..."
xattr -rd com.apple.quarantine "$INSTALLED_APP" 2>/dev/null || true
xattr -cr "$INSTALLED_APP" 2>/dev/null || true

# --- Clean up temp files ---
if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
    rm -rf "$TEMP_DIR"
fi

# --- Launch ---
echo ""
echo "  $(green '✓') Aira installed to $INSTALLED_APP"
echo ""

read -p "  Launch Aira now? [Y/n] " -n 1 -r REPLY
echo ""
if [[ -z "$REPLY" || "$REPLY" =~ ^[Yy]$ ]]; then
    open "$INSTALLED_APP"
    echo "  $(green '✓') Aira is running."
fi

echo ""
