#!/usr/bin/env bash
#              __ _       _     _            _              _   _
#  _ __ ___   / _(_)     | |__ | |_   _  ___| |_ ___   ___ | |_| |__
# | '__/ _ \ | |_| |_____| '_ \| | | | |/ _ \ __/ _ \ / _ \| __| '_ \
# | | | (_) |  _| |_____| |_) | | |_| |  __/ || (_) | (_) | |_| | | |
# |_|  \___/|_| |_|     |_.__/|_|\__,_|\___|\__\___/ \___/ \__|_| |_|
#
# Author: Nick Clyde (clydedroid)
# Modified: Sorted by Status (Connected/Paired) and Alphabetized

# Constants
divider="---------"
goback="Back"

# Checks if bluetooth controller is powered on
power_on() {
    if bluetoothctl show | grep -q "Powered: yes"; then
        return 0
    else
        return 1
    fi
}

# Toggles power state
toggle_power() {
    if power_on; then
        bluetoothctl power off
        show_menu
    else
        if rfkill list bluetooth | grep -q 'blocked: yes'; then
            rfkill unblock bluetooth && sleep 3
        fi
        bluetoothctl power on
        show_menu
    fi
}

# Checks if controller is scanning for new devices
scan_on() {
    if bluetoothctl show | grep -q "Discovering: yes"; then
        echo "Scan: on"
        return 0
    else
        echo "Scan: off"
        return 1
    fi
}

# Toggles scanning state
toggle_scan() {
    if scan_on; then
        kill $(pgrep -f "bluetoothctl --timeout 5 scan on")
        bluetoothctl scan off
        show_menu
    else
        bluetoothctl --timeout 5 scan on
        echo "Scanning..."
        show_menu
    fi
}

# Checks if controller is able to pair to devices
pairable_on() {
    if bluetoothctl show | grep -q "Pairable: yes"; then
        echo "Pairable: on"
        return 0
    else
        echo "Pairable: off"
        return 1
    fi
}

# Toggles pairable state
toggle_pairable() {
    if pairable_on; then
        bluetoothctl pairable off
        show_menu
    else
        bluetoothctl pairable on
        show_menu
    fi
}

# Checks if controller is discoverable by other devices
discoverable_on() {
    if bluetoothctl show | grep -q "Discoverable: yes"; then
        echo "Discoverable: on"
        return 0
    else
        echo "Discoverable: off"
        return 1
    fi
}

# Toggles discoverable state
toggle_discoverable() {
    if discoverable_on; then
        bluetoothctl discoverable off
        show_menu
    else
        bluetoothctl discoverable on
        show_menu
    fi
}

# Checks if a device is connected
device_connected() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Connected: yes"; then
        return 0
    else
        return 1
    fi
}

# Toggles device connection
toggle_connection() {
    if device_connected "$1"; then
        bluetoothctl disconnect "$1"
        device_menu "$device"
    else
        bluetoothctl connect "$1"
        device_menu "$device"
    fi
}

# Checks if a device is paired
device_paired() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Paired: yes"; then
        echo "Paired: yes"
        return 0
    else
        echo "Paired: no"
        return 1
    fi
}

# Toggles device paired state
toggle_paired() {
    if device_paired "$1"; then
        bluetoothctl remove "$1"
        device_menu "$device"
    else
        bluetoothctl pair "$1"
        device_menu "$device"
    fi
}

# Checks if a device is trusted
device_trusted() {
    device_info=$(bluetoothctl info "$1")
    if echo "$device_info" | grep -q "Trusted: yes"; then
        echo "Trusted: yes"
        return 0
    else
        echo "Trusted: no"
        return 1
    fi
}

# Toggles device connection
toggle_trust() {
    if device_trusted "$1"; then
        bluetoothctl untrust "$1"
        device_menu "$device"
    else
        bluetoothctl trust "$1"
        device_menu "$device"
    fi
}

# Prints status bar info
print_status() {
    if power_on; then
        printf ''
        paired_devices_cmd="devices Paired"
        if (( $(echo "$(bluetoothctl version | cut -d ' ' -f 2) < 5.65" | bc -l) )); then
            paired_devices_cmd="paired-devices"
        fi
        mapfile -t paired_devices < <(bluetoothctl $paired_devices_cmd | grep Device | cut -d ' ' -f 2)
        counter=0
        for device in "${paired_devices[@]}"; do
            if device_connected "$device"; then
                device_alias=$(bluetoothctl info "$device" | grep "Alias" | cut -d ' ' -f 2-)
                if [ $counter -gt 0 ]; then
                    printf ", %s" "$device_alias"
                else
                    printf " %s" "$device_alias"
                fi
                ((counter++))
            fi
        done
        printf "\n"
    else
        echo ""
    fi
}

# Device-specific submenu
device_menu() {
    device=$1
    device_name=$(echo "$device" | cut -d ' ' -f 3-)
    mac=$(echo "$device" | cut -d ' ' -f 2)

    if device_connected "$mac"; then
        connected="Connected: yes"
    else
        connected="Connected: no"
    fi
    paired=$(device_paired "$mac")
    trusted=$(device_trusted "$mac")
    options="$connected\n$paired\n$trusted\n$divider\n$goback\nExit"

    chosen="$(echo -e "$options" | $rofi_command "$device_name")"

    case "$chosen" in
        "" | "$divider")
            echo "No option chosen."
            ;;
        "$connected")
            toggle_connection "$mac"
            ;;
        "$paired")
            toggle_paired "$mac"
            ;;
        "$trusted")
            toggle_trust "$mac"
            ;;
        "$goback")
            show_menu
            ;;
    esac
}

# Main menu with status-based and alphabetical sorting
show_menu() {
    if power_on; then
        power="Power: on"

        # Get all devices
        all_devices=$(bluetoothctl devices | grep Device)

        connected_list=""
        paired_list=""
        other_list=""

        # Categorize devices
        while read -r line; do
            [ -z "$line" ] && continue
            mac=$(echo "$line" | cut -d ' ' -f 2)
            name=$(echo "$line" | cut -d ' ' -f 3-)

            if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
                connected_list+="$name\n"
            elif bluetoothctl info "$mac" | grep -q "Paired: yes"; then
                paired_list+="$name\n"
            else
                other_list+="$name\n"
            fi
        done <<< "$all_devices"

        # Alphabetize each group
        sorted_connected=$(echo -e "$connected_list" | sed '/^$/d' | sort -f)
        sorted_paired=$(echo -e "$paired_list" | sed '/^$/d' | sort -f)
        sorted_other=$(echo -e "$other_list" | sed '/^$/d' | sort -f)

        # Merge them back together
        devices=$(printf "%s\n%s\n%s" "$sorted_connected" "$sorted_paired" "$sorted_other" | sed '/^$/d')

        scan=$(scan_on)
        pairable=$(pairable_on)
        discoverable=$(discoverable_on)

        options="$devices\n$divider\n$power\n$scan\n$pairable\n$discoverable\nExit"
    else
        power="Power: off"
        options="$power\nExit"
    fi

    chosen="$(echo -e "$options" | $rofi_command "Bluetooth")"

    case "$chosen" in
        "" | "$divider")
            echo "No option chosen."
            ;;
        "$power")
            toggle_power
            ;;
        "$scan")
            toggle_scan
            ;;
        "$discoverable")
            toggle_discoverable
            ;;
        "$pairable")
            toggle_pairable
            ;;
        "Exit")
            exit 0
            ;;
        *)
            device=$(bluetoothctl devices | grep "$chosen" | head -n 1)
            if [[ $device ]]; then device_menu "$device"; fi
            ;;
    esac
}

# Rofi command configuration
rofi_command="rofi -dmenu $* -p"

case "$1" in
    --status)
        print_status
        ;;
    *)
        show_menu
        ;;
esac
