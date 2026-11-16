# webos-usb-dac-audio
# webos-usb-dac-audio

![Platform](https://img.shields.io/badge/platform-LG%20webOS%20(Rooted)-crimson)
![Tested](https://img.shields.io/badge/tested-webOS%2010%20(25)%20%7C%20k8lpn-blue)
![Audio](https://img.shields.io/badge/audio-ALSA%20USB%20DAC-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Enable direct, lossless **USB DAC audio output (USB-to-3.5mm AUX)** to external speakers on rooted LG webOS Smart TVs with automatic plug-and-play.

---

## Overview

Many modern LG Smart TVs removed the 3.5mm AUX/Headphone jack, and webOS ignores USB DACs in the TV Settings menu. However, on many LG TV models, LG left the **`snd-usb-audio`** driver compiled inside the Linux kernel.

By capturing the TV's internal ALSA audio loopback device (`arecord`) and piping it directly into the USB DAC (`aplay`), you get direct **48kHz / 16-bit Stereo PCM** audio out of the TV's USB port into any 3.5mm AUX speakers.

At a `2048` buffer size, the external speakers and the TV's built-in speakers play in sync right out of the box—no TV audio settings need to be changed, both speakers can play together simultaneously, and each keeps its own independent volume control.

```text
[ webOS Audio Bus (hw:0,13) ] ──(S16_LE 48kHz PCM)──> [ snd-usb-audio (USB DAC) ] ──> [ 3.5mm AUX Speakers ]
```

---

## Tested Setup

| Component | Details |
| :--- | :--- |
| **TV Model** | LG 43UR8050PSB (43" 4K UHD Smart TV) |
| **SoC / OS** | Realtek `k8lpn` — LG `webOS 25` (`webOS 10.x`, Rooted) |
| **USB DAC** | Audiocular Aura (CS43131 + SGM8262) via USB-A to USB-C OTG Adapter |
| **Speakers** | Mitashi TWR-8480 BT (2.0 Tower Speakers via 3.5mm-to-RCA AUX) |

*(Works on any rooted LG webOS TV whose kernel includes `snd-usb-audio` and exposes an internal ALSA capture loopback in `arecord -l`).*

---

## Prerequisites

1. **A Rooted LG webOS TV** with [webOS Homebrew Channel (`webosbrew`)](https://github.com/webosbrew/webos-homebrew-channel) and **Root SSH** enabled.
2. **[webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop)** or any SSH client (Termius, PuTTY, etc.).
3. **A USB DAC** (or USB-to-3.5mm adapter) + **3.5mm AUX Speakers/Headphones**.

---

## Step-by-Step Guide

### Step 1: Check if Your TV Kernel Detects Your USB DAC (30-Second Check)
Plug your USB DAC into the TV's USB port, connect your speakers, and run these three commands in your SSH terminal:

```bash
cat /proc/asound/cards
aplay -l
arecord -l
```

#### Check Your Result Before Going Further:
* ✅ **If your USB DAC shows up in `cat /proc/asound/cards` and `aplay -l`:**
  Your TV's kernel supports USB audio!
  1. Note your DAC's card number and the exact **Card ID** inside the `[ ]` brackets from `cat /proc/asound/cards`:
     ```text
     2 [AudiocularAura ]: USB-Audio - Audiocular-Aura
                          TTGK Technology Audiocular-Aura at usb-18050000.xhci_top-1, high speed
     ```
     *(Here, the card number is `2` and the Card ID is **`AudiocularAura`**).*
  2. Check `arecord -l` for your TV's internal audio capture device. On Realtek-based LG TVs, it is **`card 0, device 13`** (`MARS CAPTURE_TEST` → **`hw:0,13`**):
     ```text
     card 0: Mars [Mars], device 13: MARS CAPTURE_TEST [MARS CAPTURE_TEST]
     ```
     *(If your TV uses a different SoC and lists a different capture card/device number in `arecord -l`, use that `hw:X,Y` number instead).*

* ❌ **If your USB DAC does NOT show up at all in `cat /proc/asound/cards`:**
  **Stop here—do not waste your time.** Your specific TV model's kernel was compiled without `snd-usb-audio`. Instead, use **[nickvsnetworking/webos-audiostream-remote](https://github.com/nickvsnetworking/webos-audiostream-remote)** to stream `hw:0,13` over Wi-Fi to a phone/PC and plug your DAC into that device.

---

### Step 2: Test Live Audio & Buffer Sync
Play any video or music on the TV and test audio output to your DAC (replace `2,0` with your DAC's card number from Step 1):

```bash
arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 | aplay -D plughw:2,0
```

Once you hear sound from your speakers, lock in **`--buffer-size=2048`** and use your DAC's **Card ID** (`plughw:AudiocularAura,0`) instead of the card number so reboots never break it:

```bash
arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 --buffer-size=2048 | aplay -D plughw:AudiocularAura,0 --buffer-size=2048
```

* **Why `2048`?** Smaller buffers (`512` or `1024`) cause `underrun!!!` errors and audio pops. At `2048`, playback is rock-solid with zero pops, and the external speakers match the TV's internal speakers closely enough that both can play together at the same time without touching any TV audio settings.
* Press **`Ctrl+C`** to stop the manual test.

---

### Step 3: Install Automatic Plug-and-Play Startup Script
To make audio start automatically on TV boot and whenever you plug/unplug the USB DAC (with zero terminal commands needed again), run this block once:

> **Important:** Replace both instances of **`AudiocularAura`** below with your own DAC's Card ID from Step 1 (and update `hw:0,13` if your `arecord -l` capture device was different).

```bash
killall auto-dac.sh arecord aplay >/dev/null 2>&1
mkdir -p /var/lib/webosbrew/init.d

cat << 'EOF' > /home/root/auto-dac.sh
#!/bin/sh
while true; do
  if [ -e /proc/asound/AudiocularAura ]; then
    killall arecord aplay >/dev/null 2>&1
    arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 --buffer-size=2048 2>/dev/null | aplay -D plughw:AudiocularAura,0 --buffer-size=2048 >/dev/null 2>&1
    killall arecord aplay >/dev/null 2>&1
  fi
  sleep 3
done
EOF
chmod +x /home/root/auto-dac.sh

cat << 'EOF' > /var/lib/webosbrew/init.d/99-autodac
#!/bin/sh
killall auto-dac.sh arecord aplay >/dev/null 2>&1
/home/root/auto-dac.sh </dev/null >/dev/null 2>&1 &
exit 0
EOF
chmod +x /var/lib/webosbrew/init.d/99-autodac

/var/lib/webosbrew/init.d/99-autodac
```

Wait 3 seconds for your speakers to start playing, then close your terminal / Dev Manager app. You can now plug and unplug your DAC anytime.

---

## Safety, Storage & RAM Footprint

* **0 Bytes of Flash Storage Used:** The pipe (`|`) passes audio through a tiny **8 KB ring buffer in RAM**. Zero audio files or log files (`>/dev/null 2>&1`) are written to your TV's storage.
* **Negligible RAM Usage:** Uses **~1.8 MB of RAM** while the DAC is plugged in, and drops to **~0.12 MB (0.0% CPU)** when unplugged.
* **No Zombie Processes:** The loop blocks until playback exits and cleans up with `killall` on unplug, preventing duplicate processes.

---

## Uninstall

To stop playback and completely remove the automatic script:

```bash
rm -f /var/lib/webosbrew/init.d/99-autodac /home/root/auto-dac.sh && killall auto-dac.sh arecord aplay
```

---

## Credits

* **[nickvsnetworking/webos-audiostream-remote](https://github.com/nickvsnetworking/webos-audiostream-remote)** — For discovering and documenting the `hw:0,13` (`MARS CAPTURE_TEST`) internal ALSA capture tap on LG webOS TVs.
* **[webosbrew / OpenLGTV Community](https://github.com/webosbrew/webos-homebrew-channel)** — For Homebrew Channel, `init.d` startup hooks, and [Dev Manager](https://github.com/webosbrew/dev-manager-desktop).
* **[throwaway96/webos-kernel-drivers](https://github.com/throwaway96/webos-kernel-drivers)** — For LG webOS SoC and `init.d` documentation.
* **AI Assistance** — Buffer troubleshooting, hotplug loop structure, and documentation formatting assisted by AI (Argon 4 High / Gemini).