#!/bin/bash

# Use 'wpctl status' to get the device node names mine look like this:
# ........
# ├─ Sinks:
# │      64. alsa_output.pci-0000_03_00.1.hdmi-stereo [vol: 0.49 MUTED]
# │      66. alsa_output.usb-FiiO_DigiHug_USB_Audio-01.analog-stereo [vol: 0.63]
# │  *   69. alsa_output.pci-0000_10_00.6.analog-stereo [vol: 0.82]
# ........

# Define device names
SPEAKER_NODE="alsa_output.pci-0000_10_00.6.analog-stereo"
HEADSET_NODE="alsa_output.usb-FiiO_DigiHug_USB_Audio-01.analog-stereo"

# Get current default sink
current_sink=$(wpctl status -n | tail -n 1 | awk '{print $3}')

# Resolve device IDs from node names
speaker_id=$(pw-cli info "$SPEAKER_NODE" | head -n 1 | awk '{print $2}')
headset_id=$(pw-cli info "$HEADSET_NODE" | head -n 1 | awk '{print $2}')

# Toggle default sink between speaker and headset
if [ "$current_sink" = "$SPEAKER_NODE" ]; then
    wpctl set-default "$headset_id"
else
    wpctl set-default "$speaker_id"
fi
