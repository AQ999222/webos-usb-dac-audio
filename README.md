# webos-usb-dac-audio

![Platform](https://img.shields.io/badge/platform-LG%20webOS%20(Rooted)-crimson)
![Tested](https://img.shields.io/badge/tested-webOS%2010%20(25)%20%7C%20k8lpn-blue)
![Audio](https://img.shields.io/badge/audio-ALSA%20USB%20DAC-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Send direct, uncompressed audio from a rooted LG webOS TV through a USB DAC to external 3.5mm AUX speakers, with automatic start and stop when you plug or unplug the DAC.

---

## Why I Made This

Many newer LG TVs do not have a 3.5mm AUX port anymore, leaving only Optical, HDMI ARC, and Bluetooth. If you already own wired AUX speakers without an Optical port (or with an older Bluetooth chip that makes audio sound flat), you cannot plug them straight into the TV. And if you plug a USB DAC into the TV's USB port, webOS ignores it in the Sound Settings menu.

However, LG left the `snd-usb-audio` driver compiled inside the TV's Linux kernel on many models.

By reading the TV's internal ALSA audio stream with `arecord` and sending it straight to `aplay` on the USB DAC, you get uncompressed 48kHz 16 bit stereo PCM audio directly from the USB port to your 3.5mm AUX speakers.

Using a `2048` buffer size keeps the sound matched closely enough with the TV's internal speakers that you do not need to change any TV sound settings or mute the TV. Both the TV speakers and your external speakers can play together, each with its own volume control.

```text
[ TV Internal Audio (hw:0,13) ] ──(48kHz Stereo PCM)──> [ USB DAC (snd-usb-audio) ] ──> [ 3.5mm AUX Speakers ]
```

---

## What Was Actually Tested (And What Was Not)

| Part | My Tested Setup |
| :--- | :--- |
| **TV Model** | LG 43UR8050PSB (43" 4K UHD Smart TV) |
| **SoC / OS** | Realtek `k8lpn`, LG `webOS 25` (`webOS 10.x`, Rooted) |
| **USB DAC** | Audiocular Aura (CS43131 + SGM8262) with a USB-A to USB-C OTG Adapter |
| **Speakers** | Mitashi TWR-8480 BT (2.0 Tower Speakers via 3.5mm to RCA AUX cable) |

**Honest transparency note on compatibility:**
* **Tested:** Only on the setup listed above.
* **Expected to work (not personally tested):** Other rooted Realtek LG TVs (`k6hp`, `k7lp`, `k8lp`, `k8hp`, `k8hpp`, check your TV chip on [throwaway96/webos-kernel-drivers](https://github.com/throwaway96/webos-kernel-drivers)) and other standard plug and play USB DACs, as long as your TV kernel includes `snd-usb-audio`.
* **Not supported:** LG OLED TVs (Alpha chips like `O18`, `O20`, `O22`, `O24`) and MediaTek TVs (`M16P`, `LM21A`) do not use the Realtek `Mars` audio driver, so `MARS CAPTURE_TEST` does not exist on them. On those chips, media and HDMI audio usually bypass standard ALSA capture devices. Step 1 below lets you check your TV in 30 seconds so you do not waste your time.

---

## What You Need

1. A rooted LG webOS TV with [webOS Homebrew Channel (`webosbrew`)](https://github.com/webosbrew/webos-homebrew-channel) installed and Root SSH enabled.
2. [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop) (on PC or Android) or any SSH app (such as Termius or PuTTY).
3. A USB DAC (or USB to 3.5mm audio adapter) and external 3.5mm AUX speakers or headphones.

---

## Step by Step Setup

### Step 1: Check Your TV First (Takes 30 Seconds)
Plug your USB DAC into the TV's USB port, connect your speakers, and run these three read only commands in your SSH terminal:

```bash
cat /proc/asound/cards
aplay -l
arecord -l
```

#### 1. Check `cat /proc/asound/cards` and `aplay -l` for your USB DAC:
* **If your USB DAC shows up:** Your TV kernel supports USB audio. Note your DAC's card number and the exact **Card ID** inside the `[ ]` brackets:
  ```text
  2 [AudiocularAura ]: USB-Audio - Audiocular-Aura
                       TTGK Technology Audiocular-Aura at usb-18050000.xhci_top-1, high speed
  ```
  *(In my case, the card number is `2` and the Card ID is `AudiocularAura`).*
* **If your USB DAC does NOT show up at all:** Stop here so you do not waste your time. Your TV model's kernel was compiled without `snd-usb-audio`. Instead, look at [nickvsnetworking/webos-audiostream-remote](https://github.com/nickvsnetworking/webos-audiostream-remote), which streams `hw:0,13` over Wi-Fi to a phone or PC where you can plug in your DAC.

#### 2. Check `arecord -l` for your TV's internal audio capture device (`hw:X,Y`):
In `arecord -l`, `card X, device Y` becomes `hw:X,Y`:
```text
card 0: Mars [Mars], device 12: MARS DSNOOP [MARS DSNOOP]
card 0: Mars [Mars], device 13: MARS CAPTURE_TEST [MARS CAPTURE_TEST]
```
* **Realtek LG TVs:** Use `hw:0,13` (`MARS CAPTURE_TEST`) on newer models, or `hw:0,12` (`MARS DSNOOP`) on some older models if `hw:0,13` is missing.
* **Other LG TVs:** Do **not** use `FARFIELD` or `Mic` entries, as those are voice microphones. If no loopback device appears in `arecord -l`, your TV chip does not expose an ALSA capture tap for this method. *(Note: webOS also runs PulseAudio, which can be checked with `pactl list short sources`, though hardware decoded movies and HDMI audio on OLED TVs typically bypass PulseAudio).*

---

### Step 2: Test Live Sound and Buffer Size
Play any video or music on your TV, then run this test command (replace `2,0` with your DAC's card number, and `hw:0,13` if your capture device was different):

```bash
arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 | aplay -D plughw:2,0
```

Once you hear audio from your speakers, test it with `--buffer-size=2048` and your DAC's **Card ID** (`plughw:AudiocularAura,0`) instead of the card number so reboots do not break it if card numbers shift:

```bash
arecord -D hw:0,13 -f S16_LE -r 48000 -c 2 --buffer-size=2048 | aplay -D plughw:AudiocularAura,0 --buffer-size=2048
```

* **Why `2048`?** On my TV, smaller buffers (`512` and `1024`) caused `underrun!!!` errors and audio pops. A `2048` buffer (~42ms) played cleanly with no underruns and stayed matched with the TV's internal speakers. *(If your TV still prints `underrun!!!` lines at `2048`, try `4096`).*
* Press `Ctrl+C` to stop the manual test.

---

### Step 3: Make It Automatic (No Terminal Needed)
Paste this block once into your terminal to start audio automatically when the TV turns on, and to start or stop automatically whenever you plug or unplug your DAC.

> **Important:** Change `AudiocularAura` in `DAC_ID=` to your own DAC's Card ID from Step 1, and change `hw:0,13` if your capture device in `arecord -l` was different.

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

Wait 3 seconds for your speakers to start playing, then close your terminal and Dev Manager. You can plug and unplug your DAC anytime. *(Note: On rare occasions after waking the TV from Quick Start+ standby, unplugging the DAC for 4 seconds and plugging it back in resets the audio stream).*

---

## Does This Affect TV Storage or RAM?

* **Zero TV storage used:** Even though the command is named `arecord`, the pipe (`|`) passes audio through a tiny 8 KB buffer in RAM directly to `aplay`. Zero audio files or log files (`>/dev/null 2>&1`) are written to your TV's storage.
* **Very small RAM usage:** Uses roughly 1.8 MB of RAM while the DAC is plugged in, and drops to roughly 0.12 MB (0.0% CPU) when unplugged.
* **No leftover processes:** The loop waits for the current audio stream to close before looping again and runs `killall` on unplug, so duplicate processes do not stack up.

---

## Uninstall

To stop playback and delete the startup script completely, run:

```bash
rm -f /var/lib/webosbrew/init.d/99-autodac /home/root/auto-dac.sh && killall auto-dac.sh arecord aplay
```

---

## Credits

* **[nickvsnetworking/webos-audiostream-remote](https://github.com/nickvsnetworking/webos-audiostream-remote)** for documenting the `hw:0,13` (`MARS CAPTURE_TEST`) internal ALSA audio capture device on LG webOS TVs.
* **[webosbrew / OpenLGTV Community](https://github.com/webosbrew/webos-homebrew-channel)** for the Homebrew Channel, `init.d` startup hooks, and [Dev Manager](https://github.com/webosbrew/dev-manager-desktop).
* **[throwaway96/webos-kernel-drivers](https://github.com/throwaway96/webos-kernel-drivers)** for LG webOS SoC and `init.d` documentation.
* **AI Assistance** for help with hotplug script structure, and documentation formatting (Argon 4 High / Gemini).
