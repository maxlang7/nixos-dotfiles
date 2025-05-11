#!/bin/sh

notification() {
  notify-send "Timer operating now for: " "$@" --icon=clock
}

get_time() {
  rofi -dmenu -i -p "Enter time (minutes) or choose an option:" <<<"
5
10
30
Custom"
}

get_custom_time() {
  rofi -dmenu -i -p "Enter custom time in minutes:"
}

update_waybar() {
  jq -n \
    --arg text "$1" \
    '{ "text": $text }'
}

run_countdown() {
  local total_seconds="$1"
  local start_time="$2" # Pass start time as an argument
  local remaining_seconds

  while true; do
    remaining_seconds=$((total_seconds - ($(date +%s) - start_time)))
    if [[ "$remaining_seconds" -le 0 ]]; then
      echo "$(update_waybar '')" # Back to blank
      notification "Timer Finished!"
      # Clear environment variables
      unset WAYBAR_TIMER_SECONDS
      unset WAYBAR_TIMER_START
      exit 0
    fi
    local remaining_minutes=$((remaining_seconds / 60))
    local remaining_secs=$((remaining_seconds % 60))
    echo "$(
      update_waybar \
        "Timer: ${remaining_minutes}m ${remaining_secs}s"
    )"
    sleep 1
  done
}

main() {
  # Check if timer is already running
  if [ -n "$WAYBAR_TIMER_SECONDS" ] && [ -n "$WAYBAR_TIMER_START" ]; then
    run_countdown "$WAYBAR_TIMER_SECONDS" "$WAYBAR_TIMER_START"
    exit 0
  fi

  # Prompt for time in minutes with common options.
  # Do not run the timer selection process unless it's first run.
  start_time=$(date +%s)
  time_str=$(get_time)

  # Handle the time input and convert to seconds
  case "$time_str" in
  "5")
    minutes="5"
    seconds=$((minutes * 60))
    ;;
  "10")
    minutes="10"
    seconds=$((minutes * 60))
    ;;
  "30")
    minutes="30"
    seconds=$((minutes * 60))
    ;;
  "Custom")
    # Launch a new rofi prompt for custom time
    custom_time=$(get_custom_time)

    if ! [[ "$custom_time" =~ ^[0-9]+$ ]]; then
      echo "Invalid time. Please enter a number."
      exit 1
    fi
    minutes="$custom_time"
    seconds=$((minutes * 60))
    ;;
  "")
    echo "$(update_waybar '')" # Back to blank
    exit 0 # Exit if no time is given
    ;;
  *)
    exit 1 # Exit on an unexpected error.
    ;;
  esac

  # Set environment variables
  export WAYBAR_TIMER_SECONDS="$seconds"
  export WAYBAR_TIMER_START="$start_time"

  notification "$minutes minutes"
  echo "$(update_waybar "Timer: ${minutes} minutes")"
  run_countdown "$seconds" "$start_time"
  exit 0
}

main
