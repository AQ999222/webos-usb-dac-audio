#!/bin/sh
DAC_ID="AudiocularAura"
CAPTURE_DEV="hw:0,13"
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
