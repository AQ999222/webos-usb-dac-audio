
# webos-usb-dac-audio

![Platform](https://img.shields.io/badge/platform-LG%20webOS%20(Rooted)-crimson)
![Tested](https://img.shields.io/badge/tested-webOS%2010%20(25)%20%7C%20k8lpn-blue)
![Audio](https://img.shields.io/badge/audio-ALSA%20USB%20DAC-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Get direct, lossless **USB DAC audio output (USB-to-3.5mm AUX)** to your external speakers on a rooted LG webOS TV—with automatic plug-and-play.

---

## Why I Made This

A lot of modern LG TVs dropped the 3.5mm AUX headphone jack completely, leaving only Optical, HDMI ARC, and Bluetooth. If you have great wired AUX speakers without an Optical port (or with an older Bluetooth receiver that sounds compressed), you can't plug them straight into the TV. And if you plug a USB DAC into the TV's USB port, webOS ignores it in the Sound Settings menu.

As it turns out, **LG left the `snd-usb-audio` driver built right into the TV's Linux kernel**.

By grabbing the TV's internal ALSA audio stream (`arecord`) and piping it directly to the USB DAC (`aplay`), you can get crisp, uncompressed **48kHz / 16-bit Stereo PCM** sound straight out of the TV's USB port into any 3.5mm AUX speakers.

Even better: at a `2048` buffer size, the external speakers and the TV's built-in speakers stay in sync right out of the box. You don't need to touch any TV sound settings or mute the TV—both speakers play together cleanly with their own independent volume control.

```text
[ TV Internal Audio (hw:0,13) ] ──(48kHz Stereo PCM)──> [ USB DAC (snd-usb-audio) ] ──> [ 3.5mm AUX Speakers ]
```

---

## What I Tested This On

| Part | My Setup |
| :--- | :--- |
| **TV Model** | LG 43UR8050PSB (43" 4K UHD Smart TV) |
| **SoC / OS** | Realtek `k8lpn` — LG `webOS 25` (`webOS 10.x`, Rooted) |
| **USB DAC** | Audiocular Aura (CS43131 + SGM8262) with a USB-A to USB-C OTG Adapter |
| **Speakers** | Mitashi TWR-8480 BT (2.0 Tower Speakers connected via 3.5mm-to-RCA AUX) |

*This method should work on most rooted LG webOS TVs whose kernel has `snd-usb-audio` enabled and exposes an internal capture device in `arecord -l`.*

---

## What You Need

1. **A Rooted LG webOS TV** with [webOS Homebrew Channel (`webosbrew`)](https://github.com/webosbrew/webos-homebrew-channel) installed and **Root SSH** turned on.
2. **[webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop)** (on PC or Android) or any SSH app (like Termius or PuTTY).
3. **Any USB DAC** (or USB-to-3.5mm audio adapter) + **3.5mm AUX Speakers or Headphones**.

---

## Step-by-Step Guide

### Step 1: Check if Your TV Detects Your USB DAC (Takes 30 Seconds)
Plug your USB DAC into the TV's USB port, connect your speakers, and run these three commands in your SSH terminal:

```bash
cat /proc/asound/cards
aplay -l
arecord -l
```

#### Check Your Output Before Going Further:
* ✅ **If your USB DAC shows up in `cat /proc/asound/cards` and `aplay -l`:**
  Your TV's kernel supports USB audio!
  1. Look at `cat /proc/asound/cards` and note your DAC's card number and the **Card ID** inside the `[ ]` brackets:
     ```text
     2 [AudiocularAura ]: USB-Audio - Audiocular-Aura
                          TTGK Technology Audiocular-Aura at usb-18050000.xhci_top-1, high speed
     ```
     *(Mine is card `2` and the Card ID is **`AudiocularAura`**).*
  2. Look at `arecord -l` to find your TV's internal audio capture device. On Realtek-based LG TVs (most UHD/NanoCell models), it is **`card 0, device 13`** (`MARS CAPTURE_TEST` → **`hw:0,13`**):
     ```text
     card 0: Mars [Mars], device 13: MARS CAPTURE_TEST [MARS CAPTURE_TEST]
     ```
     *(If your TV uses a different chip and shows another capture device in `arecord -l`, just use that `hw:X,Y` number in the next steps).*

* ❌ **If your USB DAC does NOT show up at all:**
  **Stop here—don't waste your time.** Your TV model's kernel doesn't have the USB audio driver enabled. Instead, check out **[nickvsnetworking/webos-audiostream-remote](https://github.com/nickvsnetworking/webos-audiostream-remote)**, which lets you stream `hw:0,13` over Wi-Fi to your phone or PC and plug your DAC into that instead.

---

### Step 2: Test Live Sound & Buffer Sync
Play any video or song on your TV, then run this test command (replace `2,0` with your DAC's card number and `hw:0,13` if your capture device was different):

```bash
arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 | aplay -D plughw:2,0
```

Once you hear sound from your speakers, test it with **`--buffer-size=2048`** and use your DAC's **Card ID** (`plughw:AudiocularAura,0`) instead of the number so reboots never break it:

```bash
arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 --buffer-size=2048 | aplay -D plughw:AudiocularAura,0 --buffer-size=2048
```

* **Why `2048`?** Smaller buffers (`512` or `1024`) caused `underrun!!!` errors and audio pops on my TV. Buffer size `2048` was the sweet spot—zero pops, clean sound, and synced closely enough with the TV's own speakers that both can play together at the same time.
* Press **`Ctrl+C`** to stop the test.

---

### Step 3: Make It Automatic (Plug-and-Play Without Terminal)
To make the audio start automatically when the TV turns on—and automatically start/stop whenever you plug or unplug your DAC—paste this block once into your terminal:

> **Note:** Change `AudiocularAura` on the `DAC_ID=` line to your own DAC's Card ID from Step 1 (and change `hw:0,13` if your `arecord -l` device was different).

```bash
killall auto-dac.sh arecord aplay >/dev/null 2>&1
mkdir -p /var/lib/webosbrew/init.d

cat << 'EOF' > /home/root/auto-dac.sh
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

Wait 3 seconds for your speakers to start playing, then close your terminal / Dev Manager app. You can now plug and unplug your DAC whenever you want.

---

## Does This Affect TV Storage or RAM?

* **0 Bytes of TV Storage Used:** Even though the command is called `arecord`, the pipe (`|`) passes audio through a tiny **8 KB buffer in RAM** straight to your DAC. Zero audio files or logs (`>/dev/null 2>&1`) are ever saved to your TV's storage.
* **Tiny RAM Usage:** Uses only **~1.8 MB of RAM** while the DAC is plugged in, and drops to **~0.12 MB (0.0% CPU)** when unplugged.
* **No Leftover Processes:** The loop waits for the current audio stream to exit before repeating and cleans up with `killall` on unplug, so duplicate processes never build up.

---

## Uninstall

If you ever want to stop the audio and remove the startup script completely, run:

```bash
rm -f /var/lib/webosbrew/init.d/99-autodac /home/root/auto-dac.sh && killall auto-dac.sh arecord aplay
```

---

## Credits

* **[nickvsnetworking/webos-audiostream-remote](https://github.com/nickvsnetworking/webos-audiostream-remote)** — For documenting the `hw:0,13` (`MARS CAPTURE_TEST`) internal ALSA capture device on LG webOS TVs.
* **[webosbrew / OpenLGTV Community](https://github.com/webosbrew/webos-homebrew-channel)** — For Homebrew Channel, `init.d` startup hooks, and [Dev Manager](https://github.com/webosbrew/dev-manager-desktop).
* **[throwaway96/webos-kernel-drivers](https://github.com/throwaway96/webos-kernel-drivers)** — For LG webOS SoC and `init.d` documentation.
* **AI Assistance** — Troubleshooting, hotplug script structure, and formatting assisted by AI (Argon 4 High / Gemini).