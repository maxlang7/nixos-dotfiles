#!/bin/sh

# Define the path to your hypridle.conf file
#HYPRIDLE_CONFIG="$HOME/.config/hypr/hypridle.conf"

# Define a temporary file to store the status
STATUS_FILE="/tmp/hypridle_status"

# Function to check if hypridle is running
is_running() {
    pgrep hypridle > /dev/null
}

# Function to toggle hypridle
toggle_hypridle() {
    if is_running; then
        # hypridle is running, so we kill it
        pkill hypridle
        echo "disabled" > "$STATUS_FILE"
    else
        # hypridle is not running, so we start it
        nohup hypridle  &
        echo "enabled" > "$STATUS_FILE"
    fi
}

# Check for a command line argument
toggle_hypridle
# Output the current status for Waybar
if [ -f "$STATUS_FILE" ]; then
    status=$(cat "$STATUS_FILE")
else
    # If the status file doesn't exist, check the process and create it
    if is_running; then
        status="enabled"
    else
        status="disabled"
    fi
    echo "$status" > "$STATUS_FILE"
fi

# Output JSON for Waybar with Nerd Font icons and class
if [ "$status" == "enabled" ]; then
    echo '{"text": "󰾪", "tooltip": "hypridle is enabled", "class": "enabled"}'
else
    echo '{"text": "", "tooltip": "hypridle is disabled", "class": "disabled"}'
fi