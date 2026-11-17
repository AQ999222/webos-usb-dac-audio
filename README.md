# webos-usb-dac-audio

![Platform](https://img.shields.io/badge/platform-LG%20webOS%20(Rooted)-crimson)
![Tested](https://img.shields.io/badge/tested-webOS%2010%20(25)%20%7C%20k8lpn-blue)
![Audio](https://img.shields.io/badge/audio-ALSA%20USB%20DAC-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Get lossless audio output from your rooted LG webOS TV through a USB DAC (USB to 3.5mm AUX) to your external speakers automatically.

---

## Why I Made This

Many modern LG TVs no longer come with a 3.5mm AUX headphone jack and only give you Optical, HDMI ARC, or Bluetooth. If you have good wired AUX speakers without an optical port (or an older Bluetooth receiver that compresses the sound), you cannot connect them directly to the TV. Also, if you plug a USB DAC into the TV, webOS does not show it in the Sound Settings menu.

However, LG left the `snd-usb-audio` driver inside the TV's Linux kernel.

By using `arecord` on the TV to grab the internal ALSA audio and sending it to `aplay` on the USB DAC, you can get clean 48kHz / 16-bit stereo PCM audio straight out of the USB port into your 3.5mm AUX speakers.

With a `2048` buffer size, the audio from the external speakers and the TV's internal speakers stays in sync. You do not need to change any audio settings on your TV. Both the TV speakers and external speakers can play together at the same time with their own separate volume controls.

```text
[ TV Internal Audio (hw:0,13) ] ──(48kHz Stereo PCM)──> [ USB DAC (snd-usb-audio) ] ──> [ 3.5mm AUX Speakers ]
```

---

## Transparency & What I Tested This On

| Part | My Setup |
| :--- | :--- |
| **TV Model** | LG 43UR8050PSB (43" 4K UHD Smart TV) |
| **Chip / OS** | Realtek `k8lpn` running LG `webOS 25` (`webOS 10.x`, Rooted) |
| **USB DAC** | Audiocular Aura (CS43131 + SGM8262) with a USB-A to USB-C OTG Adapter |
| **Speakers** | Mitashi TWR-8480 BT (2.0 Tower Speakers connected with 3.5mm to RCA AUX) |

**Honest note on compatibility:**
I only own and tested this on my **LG 43UR8050PSB** (`Realtek k8lpn`). It should also work on other rooted LG TVs that use Realtek chips (`k6hp`, `k7lp`, `k8lp`, `k8lpn`, `k8hp`, `k8hpp`, etc. You can [check your TV's chip here](https://github.com/throwaway96/webos-kernel-drivers)).

I have not personally tested this on LG OLED TVs (Alpha chips) or MediaTek LG TVs, and those chips handle internal audio differently. Because of that, **Step 1 below takes only 30 seconds** and will tell you right away if your TV supports this so you do not waste your time.

---

## What You Need

1. A rooted LG webOS TV with [webOS Homebrew Channel (`webosbrew`)](https://github.com/webosbrew/webos-homebrew-channel) installed and Root SSH turned on.
2. [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop) (on PC or Android) or any SSH app (like Termius or PuTTY).
3. A USB DAC (or USB to 3.5mm audio adapter).
4. External speakers or headphones with a 3.5mm AUX cable.

---

## Setup Guide

### Step 1: Check if Your TV Supports Your USB DAC & Audio Capture (30 Seconds)
Plug your USB DAC into your TV's USB port and connect your speakers. Run these 3 commands in your SSH terminal:

```bash
cat /proc/asound/cards
aplay -l
arecord -l
```

#### 1. Check `cat /proc/asound/cards` and `aplay -l` for your USB DAC:
* ✅ **If your USB DAC shows up:** Your TV kernel supports USB audio. Note your DAC's card number and the **Card ID** written inside the `[ ]` brackets:
  ```text
  2 [AudiocularAura ]: USB-Audio - Audiocular-Aura
                       TTGK Technology Audiocular-Aura at usb-18050000.xhci_top-1, high speed
  ```
  *(On my TV, the card number is **`2`** and the Card ID is **`AudiocularAura`**).*
* ❌ **If your USB DAC does NOT show up at all:**
  **Stop here so you do not waste your time.** Your TV model does not have the USB audio driver enabled in its kernel. If your TV still shows `hw:0,13` in `arecord -l` below, you can use [nickvsnetworking/webos-audiostream-remote](https://github.com/nickvsnetworking/webos-audiostream-remote) to stream your TV audio over Wi-Fi to a phone or PC and plug your DAC into that device instead.

#### 2. Check `arecord -l` for your TV's internal audio capture device (`hw:X,Y`):
In `arecord -l`, `card X, device Y` means **`hw:X,Y`**:
```text
card 0: Mars [Mars], device 12: MARS DSNOOP [MARS DSNOOP]
card 0: Mars [Mars], device 13: MARS CAPTURE_TEST [MARS CAPTURE_TEST]
```
* **If you have a Realtek LG TV:** Use **`hw:0,13`** (`card 0, device 13: MARS CAPTURE_TEST`), or **`hw:0,12`** (`card 0, device 12: MARS DSNOOP`) on some older Realtek models.
* **Important:** Do **not** use `FARFIELD` (that is the voice control microphone, not TV sound).
* **If you have an LG OLED or MediaTek TV:** Those chips do not have `MARS CAPTURE_TEST`. Look at `arecord -l` to see if another loopback capture device is listed (not a mic). If no loopback device is listed in `arecord -l`, your TV's chip routes audio through closed hardware blocks that ALSA cannot read, so this script will not work on your TV.

---

### Step 2: Test Live Sound & Buffer Size
Play any video or song on your TV. Run this command to test sound output (replace `2,0` with your DAC's card number from Step 1):

```bash
arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 | aplay -D plughw:2,0
```

Once you hear sound from your speakers, test it with `--buffer-size=2048` and use your DAC's **Card ID** (`plughw:AudiocularAura,0`) instead of the card number so it never breaks after a reboot:

```bash
arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 --buffer-size=2048 | aplay -D plughw:AudiocularAura,0 --buffer-size=2048
```

* **Why `2048`?** When I tested smaller buffer sizes (`512` and `1024`), I got `underrun!!!` errors and popping sounds. Buffer size `2048` had zero popping, clean sound, and stayed synced with the TV speakers.
* Press **`Ctrl+C`** to stop the manual test.

---

### Step 3: Make It Automatic (No Terminal Needed Again)
Paste the block below once into your terminal. It will start the audio automatically when your TV turns on, and automatically start or stop whenever you plug or unplug your DAC.

> **Important:** Change `AudiocularAura` on the `DAC_ID=` line to match your own DAC's Card ID from Step 1 (and change `hw:0,13` if your capture device in Step 1 was `hw:0,12`).

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

Wait 3 seconds for your speakers to start playing, then close your terminal and Dev Manager app. You can now plug and unplug your DAC whenever you want.

---

## Does This Affect TV Storage or RAM?

* **0 Bytes of Storage Used:** Even though the command is named `arecord`, the pipe (`|`) sends the audio directly to your DAC through a tiny **8 KB buffer in RAM**. No audio files or log files are ever saved to your TV's storage (`>/dev/null 2>&1`).
* **Very Low RAM Usage:** It uses about **1.8 MB of RAM** while your DAC is plugged in. When unplugged, it drops to **0.12 MB of RAM** and **0.0% CPU**.
* **No Leftover Processes:** The loop waits for the current audio stream to close before repeating and runs `killall` when unplugged, so duplicate processes never build up.

---

## Uninstall

If you ever want to stop the audio and remove the startup script completely, run:

```bash
rm -f /var/lib/webosbrew/init.d/99-autodac /home/root/auto-dac.sh && killall auto-dac.sh arecord aplay
```

---

## Credits & Thanks

* [nickvsnetworking/webos-audiostream-remote](https://github.com/nickvsnetworking/webos-audiostream-remote) for documenting the `hw:0,13` (`MARS CAPTURE_TEST`) internal ALSA capture device on LG webOS TVs.
* [webosbrew / OpenLGTV Community](https://github.com/webosbrew/webos-homebrew-channel) for the Homebrew Channel, `init.d` startup system, and [Dev Manager](https://github.com/webosbrew/dev-manager-desktop).
* [throwaway96/webos-kernel-drivers](https://github.com/throwaway96/webos-kernel-drivers) for LG webOS chip and `init.d` documentation.
* AI Assistance (Argon 4 High / Gemini) for help with The hotplug script, and formatting this guide.
