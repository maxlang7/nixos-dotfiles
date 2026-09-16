#!/usr/bin/env bash

set -u

found=0
failed=0

while IFS= read -r device; do
  [[ -n "$device" ]] || continue
  found=1

  if ! udisksctl mount --block-device "$device"; then
    failed=1
  fi
done < <(
  lsblk --raw --paths --noheadings --output PATH,TRAN,FSTYPE,MOUNTPOINT |
    awk '$2 == "usb" && $3 != "" && NF == 3 { print $1 }'
)

if (( found == 0 )); then
  echo "No unmounted USB filesystems found."
fi

exit "$failed"
