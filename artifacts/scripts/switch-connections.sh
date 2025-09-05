#!/bin/bash

# This script intelligently switches between two specified networks.
# It checks the current connection and switches to the other one.

# Define the names of your two networks here.
NETWORK1="CMellon"
NETWORK2="Max’s iPhone"

# Check if nmcli is installed
if ! command -v nmcli &> /dev/null
then
    echo "nmcli could not be found. Please install NetworkManager."
    exit 1
fi

echo "Attempting to switch networks..."

# Get the name of the currently active connection
ACTIVE_CONNECTION=$(nmcli -t -f NAME connection show --active | head -n 1)

if [ "$ACTIVE_CONNECTION" == "$NETWORK1" ]; then
    echo "Currently connected to '$NETWORK1'. Switching to '$NETWORK2'..."
    nmcli connection up "$NETWORK2"

elif [ "$ACTIVE_CONNECTION" == "$NETWORK2" ]; then
    echo "Currently connected to '$NETWORK2'. Switching to '$NETWORK1'..."
    nmcli connection up "$NETWORK1"

else
    echo "Not connected to either '$NETWORK1' or '$NETWORK2'. Attempting to connect to '$NETWORK1'..."
    nmcli connection up "$NETWORK1"
fi

# Check the exit status of the last nmcli command
if [ $? -eq 0 ]; then
    echo "Switch command sent successfully."
else
    echo "Failed to execute the switch command. Please check network availability and connection names."
    exit 1
fi