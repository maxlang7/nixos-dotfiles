#!/usr/bin/env bash

# --- Configuration ---
CONFIG_DIR="$HOME/.config/uair"
# The active configuration file that uair reads
ACTIVE_CONFIG="$CONFIG_DIR/uair.toml"
# Custom config filenames
POMODORO_CONFIG_NAME="uair_pomodoro.toml"
LAUNDRY_CONFIG_NAME="uair_laundry.toml"

POMODORO_CONFIG="$CONFIG_DIR/$POMODORO_CONFIG_NAME"
LAUNDRY_CONFIG="$CONFIG_DIR/$LAUNDRY_CONFIG_NAME"

# --- Helper Functions ---

# Function to find and kill the running uair process
kill_uair() {
    # Find the PID of the running uair process (excluding grep itself)
    # Using 'pgrep -f' to match the full command line, which should be robust.
    UAIR_PID=$(pgrep -f "^uair")
    
    if [[ -n "$UAIR_PID" ]]; then
        echo "Killing existing uair process (PID: $UAIR_PID)..."
        kill "$UAIR_PID"
        # Wait briefly for the process to terminate
        sleep 0.5
    else
        echo "No running uair process found."
    fi
}

# Function to start uair
start_uair() {
    if [[ ! -e "$ACTIVE_CONFIG" ]]; then
        echo "Error: Active config symlink ($ACTIVE_CONFIG) does not exist. Cannot start uair."
        return 1
    fi
    
    # Start uair in the background. It will automatically read uair.toml as the default config.
    uair &
    echo "uair restarted in background, reading from $(readlink -f "$ACTIVE_CONFIG")."
}

# --- Main Logic ---

# Check which config is currently linked (if any)
CURRENT_TARGET=$(readlink -f "$ACTIVE_CONFIG")

if [[ "$CURRENT_TARGET" == "$POMODORO_CONFIG" ]]; then
    # Currently pomodoro, switch to laundry
    NEW_SOURCE="$LAUNDRY_CONFIG"
    NEW_TARGET_NAME="$LAUNDRY_CONFIG_NAME"
elif [[ "$CURRENT_TARGET" == "$LAUNDRY_CONFIG" ]]; then
    # Currently laundry, switch to pomodoro
    NEW_SOURCE="$POMODORO_CONFIG"
    NEW_TARGET_NAME="$POMODORO_CONFIG_NAME"
else
    # Default case or first run: switch to laundry as the common "special" case to start with
    echo "Current config link is ambiguous or missing. Defaulting to $LAUNDRY_CONFIG_NAME."
    NEW_SOURCE="$LAUNDRY_CONFIG"
    NEW_TARGET_NAME="$LAUNDRY_CONFIG_NAME"
fi

# 1. Check if the new source file exists
if [[ ! -f "$NEW_SOURCE" ]]; then
    echo "Error: Target configuration file '$NEW_SOURCE' not found."
    exit 1
fi

# 2. Kill the currently running uair daemon
kill_uair

# 3. Update the symbolic link for uair.toml
# Remove existing active config link/file
if [[ -e "$ACTIVE_CONFIG" ]]; then
    rm "$ACTIVE_CONFIG"
fi

# Create a symbolic link to the new configuration
ln -s "$NEW_SOURCE" "$ACTIVE_CONFIG"
echo "Active config toggled to $NEW_TARGET_NAME."

# 4. Restart uair (uair starts paused, waiting for a uairctl command)
start_uair