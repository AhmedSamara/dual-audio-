# Dual Audio

A small tool for Ubuntu that plays white noise on one Bluetooth device while all your other audio plays on another, with a control window and keyboard shortcuts for adjusting each one.

## What it does

- Plays white noise on one Bluetooth device (e.g., Sony WH-1000XM3)
- Plays everything else on a different Bluetooth device (e.g., AirPods Pro)
- Both devices play audio at the same time without interfering with each other

## Why would you ever do this.

Noise cancellation isn't 100% perfect. If you're someone who gets distracted easily and have to work in a noisy environment, it can be nice to have two layers of noise-cancellation (ex: a pair of headphones as well as airpod pros). 

One works well enough to muffle a conversation near you.
Two makes it so you don't know it's happening at all.

## Requirements

- Ubuntu with PulseAudio or PipeWire
- Two paired Bluetooth audio devices
- `mpv` audio player (`sudo apt install mpv`)

## Installation

Run the installer:

```bash
./install.sh
```

It:
- symlinks `dual_audio` into `~/.local/bin`, so the repo file stays the single
  source of truth and edits take effect immediately
- adds a **Dual Audio** entry to your app launcher
- offers to add keyboard shortcuts for volume (see below)

Then open a new terminal (or run `hash -r`). To uninstall:

```bash
dual_audio shortcuts remove
rm ~/.local/bin/dual_audio ~/.local/share/applications/dual-audio.desktop
```

The control window needs GTK for Python, which Ubuntu ships by default
(`sudo apt install python3-gi gir1.2-gtk-3.0` if it's missing).

## Control window

Open **Dual Audio** from your app launcher (or run `dual_audio ui`). It has:

- a **Start/Stop** button for the white noise
- a volume slider and mute button for each device
- a settings button (gear icon) to choose your devices and white noise file

The first time you open it with no configuration, the settings dialog
opens automatically. If a device is disconnected, its slider is greyed out.

## Keyboard shortcuts

Add them with `dual_audio shortcuts` (the installer offers this too):

| Shortcut                    | Action                          |
|-----------------------------|---------------------------------|
| `Ctrl+Super+Up` / `Down`       | everything else louder / quieter |
| `Ctrl+Super+Shift+Up` / `Down` | white noise louder / quieter     |

Each press shows a notification with the new level. You can rebind them in
Settings → Keyboard → Custom Shortcuts, or remove them with
`dual_audio shortcuts remove`.

## Command line

```bash
dual_audio            # start white noise (runs setup the first time)
dual_audio stop       # stop white noise
dual_audio status     # is white noise playing?
dual_audio setup      # choose devices and white noise file
dual_audio ui         # open the control window
dual_audio help       # show all commands
```

Setup lists your devices by name (e.g. "Ahmed Airpods") and lets you pick by
number, then lets you pick a white noise file from `~/Music`. Settings are
saved to `~/.config/dual_audio/config`.

White noise stops automatically if either device disconnects.

### Volume

```bash
dual_audio wn 40      # set white noise device to 40%
dual_audio def 70     # set default device to 70%
dual_audio wn +10     # bump white noise up 10%
dual_audio def -10    # turn default down 10%
dual_audio wn mute    # toggle mute on the white noise device
dual_audio def        # show the default device's current volume
```

- `wn`  = your white noise device
- `def` = your default device (everything else)

## Troubleshooting

**"mpv command not found"**
```bash
sudo apt install mpv
```

**White noise not playing on correct device**
This could be a timing issue. Try running the command again, or manually move the stream using pavucontrol:
```bash
sudo apt install pavucontrol
pavucontrol
```

Then in the "Playback" tab, you can drag streams between devices.
