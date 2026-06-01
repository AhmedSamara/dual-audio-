# Dual Audio

A bash function for Ubuntu that allows you to play white noise on one Bluetooth device while using Spotify (or other audio) on another simultaneously.

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

Run the installer. It symlinks `dual_audio` into `~/.local/bin` (which is on
most Ubuntu users' `PATH`), so the repo file stays the single source of truth —
edits take effect immediately, no copy-pasting or shell reload:

```bash
./install.sh
```

Then open a new terminal (or run `hash -r`) and use `dual_audio` like any other
command. To uninstall, just remove the symlink: `rm ~/.local/bin/dual_audio`.

## First Run Setup

When you run `dual_audio` for the first time, it will:

1. Show you all available audio devices and ask you to select which one gets white noise
2. Ask you to select which one should be your default device.
3. Let you pick your white noise audio file from your `~/Music` directory. 
4. Save all this configuration to `~/.config/dual_audio/config`

## Usage

Simply run:
```bash
dual_audio
```

To stop, run: 
```
dual_audio stop
```
(It will also stop if the device is disconnected.)

This will:
- Start white noise on your white noise device
- Route everything else (your default audio) to your default device
- Both will play simultaneously

## Controlling volume independently

Each device has its own sink, so you can adjust them separately:

```bash
dual_audio wn 40      # set white noise device to 40%
dual_audio def 70     # set default device to 70%
dual_audio wn +10     # bump white noise up 10%
dual_audio def -10    # turn default down 10%
dual_audio wn mute    # toggle mute on the white noise device
dual_audio def        # show the default device's current volume
```

- `wn`  = your white noise device
- `def` = your default device

## Reconfiguring

If you need to change your devices or audio file, delete the config file and run `dual_audio` again:
```bash
rm ~/.config/dual_audio/config
dual_audio
```

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
