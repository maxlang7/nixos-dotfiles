#!/bin/sh

notification() {
  notify-send "Monitor operating now at: " "$@" --icon=video-display
}

menu() {
  printf "Battery Saver\n"
  printf "Normal\n"
  printf "Gaming\n"
}

main() {
  choice=$(menu | rofi -dmenu -i -p "Resolution:")

  case "$choice" in
    "Battery Saver")
      notification "Battery Saver"
      resolution="1440x960@60"
      scale="1.0"
      ;;
    "Normal")
      notification "Normal"
      resolution="2880x1920@60"
      scale="2.0"
      ;;
    "Gaming")
      notification "Gaming"
      resolution="2880x1920@120"
      scale="2.0"
      ;;
    *)
      exit 0 # Exit if no choice is made or an invalid option is chosen
      ;;
  esac

  #Get the monitor name of eDP-1. Adjust if incorrect
  MONITOR_NAME="eDP-1"

  echo "Monitor Name: $MONITOR_NAME"
  echo "Resolution: $resolution"
  echo "Scale: $scale"

  final="hyprctl keyword monitor $MONITOR_NAME,$resolution,0x0,$scale"
  $final
}
main