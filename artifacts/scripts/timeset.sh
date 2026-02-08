#!/bin/sh

# Define the target date and time
TARGET_DATE="2026-01-15 09:00:00"

# Convert the target date to a Unix timestamp
TARGET_TIMESTAMP=$(date -d "$TARGET_DATE" +%s)

# Get the current Unix timestamp
CURRENT_TIMESTAMP=$(date +%s)

# Check if the current date is before the target date
if (( CURRENT_TIMESTAMP < TARGET_TIMESTAMP )); then
    echo "Current date is before August 1, 2025. Setting system time..."

    # Set the system date and time
    # This command requires superuser privileges
    date -s "$TARGET_DATE"

    echo "Date and time have been set to 08/01/2025 09:00:00."
    echo "Restaring network manager"
    systemctl restart NetworkManager
else
    echo "Current date is already on or after August 1, 2025. No changes made."
fi
