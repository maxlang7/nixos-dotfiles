#!/bin/bash
# --- Function to set up Presentation Mode ---
setup_presentation_mode() {
    echo "🎬 Entering Presentation Mode..."

    # 1. Kill hypridle
    pkill -STOP hypridle
    echo "    - hypridle stopped."

    # 2. Set volume to 0 (mute)
    # Using 'pactl' for PulseAudio/PipeWire; 'amixer' is an alternative for ALSA
    pactl set-sink-mute @DEFAULT_SINK@ 1
    echo "    - Volume muted."

    # 3. Disable dunst notifications (pause)
    dunstctl set-paused true
    echo "    - Notifications paused (dunst)."

    echo ""
    echo "Presentation Mode is active. Press Ctrl+C to exit."
}

# --- Function to restore normal settings ---
restore_settings() {
    echo ""
    echo "✨ Restoring normal settings..."

    # 1. Restore hypridle
    pkill -CONT hypridle
    echo "    - hypridle resumed."

    # 2. Restore volume (unmute, doesn't restore previous level)
    # This will UNMUTE but keep volume at 0. You'll need to turn it up manually.
    pactl set-sink-mute @DEFAULT_SINK@ 0
    echo "    - Volume unmuted (still at 0, adjust manually)."

    # 3. Restore dunst notifications (unpause)
    dunstctl set-paused false
    echo "    - Notifications unpaused."

    echo "✅ Done. Exiting script."
}

# --- Main script execution ---

# Set a trap to run 'restore_settings' when the script is interrupted (Ctrl+C)
trap restore_settings INT

# Start presentation mode
setup_presentation_mode

# Keep the script running until Ctrl+C is pressed
# A simple infinite loop with a short sleep
while true; do
    sleep 1
done