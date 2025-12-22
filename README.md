# Dual Audio

A bash function for Ubuntu that allows you to play white noise on one Bluetooth device while using Spotify (or other audio) on another simultaneously.

## What it does

- Plays white noise on one Bluetooth device (e.g., Sony WH-1000XM3)
- Plays Spotify on a different Bluetooth device (e.g., AirPods Pro)
- Both devices play audio at the same time without interfering with each other

## Why would you ever do this.

Noise cancellation isn't 100% perfect. If you're someone who gets distracted easily and have to work in a noisy environment, it can be nice to have two layers of noise-cancellation (ex: a pair of headphones as well as airpod pros). 

One works well enough to muffle a conversation near you.
Two makes it so you don't know it's happening at all.

## Requirements

- Ubuntu with PulseAudio or PipeWire
- Two paired Bluetooth audio devices
- `mpv` audio player (`sudo apt install mpv`)
- Spotify installed and available from command line

## Installation

Add the function to your `~/.bashrc` file and reload:
```bash
source ~/.bashrc
```

## First Run Setup

When you run `dual_audio` for the first time, it will:

1. Show you all available audio devices and ask you to select which one gets white noise
2. Ask you to select which one should be your default device.
3. Let you pick your white noise audio file from your home directory. 
4. Save all this configuration to `~/.config/dual_audio/config`

## Usage

Simply run:
```bash
dual_audio
```

This will:
- Start white noise on your white noise device
- Start Spotify on your default device
- Both will play simultaneously

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
