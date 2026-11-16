#!/bin/sh
# webos-usb-dac-audio: Automatic USB DAC Hotplug Script for Rooted LG webOS TVs

DAC_ID="AudiocularAura"   # Replace with your DAC's Card ID from: cat /proc/asound/cards
CAPTURE_DEV="hw:0,13"     # Replace if your TV's capture device in 'arecord -l' differs
BUFFER_SIZE="2048"

while true; do
  if [ -e "/proc/asound/${DAC_ID}" ]; then
    killall arecord aplay >/dev/null 2>&1
    arecord -D "${CAPTURE_DEV}" -f S16_LE -r 48000 -c 2 --buffer-size="${BUFFER_SIZE}" 2>/dev/null | \
      aplay -D "plughw:${DAC_ID},0" --buffer-size="${BUFFER_SIZE}" >/dev/null 2>&1
    killall arecord aplay >/dev/null 2>&1
  fi
  sleep 3
done
