#!/usr/bin/env bash
#
# dual_audio - play white noise on one audio device while everything else
# plays on another. See README.md for details.
#
# Usage:
#   dual_audio            start white noise + route default audio
#   dual_audio stop       stop white noise
#   dual_audio wn  [LVL]  control the white noise device's volume
#   dual_audio def [LVL]  control the default device's volume
#                         LVL: 50 (absolute), +10/-10 (relative), or "mute"
#                         with no LVL, prints that device's current volume

CONFIG_FILE="$HOME/.config/dual_audio/config"
mkdir -p "$HOME/.config/dual_audio"

# Handle stop command
if [ "$1" = "stop" ]; then
    killall mpv 2>/dev/null
    echo "White noise stopped"
    exit 0
fi

# Handle independent volume control: dual_audio wn|def [LEVEL]
#   LEVEL: absolute (e.g. 50), relative (e.g. +10 / -10), or "mute" to toggle.
#   With no LEVEL, prints the current volume of that sink.
if [ "$1" = "wn" ] || [ "$1" = "def" ]; then
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config found. Run dual_audio first to set up your devices."
        exit 1
    fi
    source "$CONFIG_FILE"

    if [ "$1" = "wn" ]; then
        SINK="$WHITENOISE_SINK"; LABEL="white noise"
    else
        SINK="$DEFAULT_SINK"; LABEL="default"
    fi

    LEVEL="$2"
    if [ -z "$LEVEL" ]; then
        echo "$LABEL volume:"
        pactl get-sink-volume "$SINK" 2>/dev/null | head -1
        exit 0
    fi

    if [ "$LEVEL" = "mute" ]; then
        pactl set-sink-mute "$SINK" toggle
        echo "$LABEL mute toggled"
    else
        pactl set-sink-mute "$SINK" 0 2>/dev/null
        pactl set-sink-volume "$SINK" "${LEVEL}%"
        echo "$LABEL volume set to ${LEVEL}%"
    fi
    exit 0
fi

# Kill any previous instances
killall mpv 2>/dev/null

# Initialize config if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "First run setup for dual audio..."

    echo ""
    echo "Available audio devices:"
    pactl list sinks | grep -E "Name|Description"

    echo ""
    read -p "Enter the sink name for white noise device (e.g., bluez_output.70_26_05_E0_BF_18.1): " WHITENOISE_SINK
    read -p "Enter the sink name for default device (e.g., bluez_output.98_1C_A2_E3_33_43.1): " DEFAULT_SINK

    # Interactive file picker
    echo ""
    echo "Select white noise audio file:"
    AUDIO_FILES=$(find "$HOME/Music" -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.flac" \) 2>/dev/null)

    if [ -z "$AUDIO_FILES" ]; then
        echo "No audio files found in $HOME/Music"
        exit 1
    fi

    echo "$AUDIO_FILES" | nl
    read -p "Enter the number of your choice: " FILE_NUM

    WHITENOISE_FILE=$(echo "$AUDIO_FILES" | sed -n "${FILE_NUM}p")

    # Validate file exists
    if [ ! -f "$WHITENOISE_FILE" ]; then
        echo "Error: Invalid selection or file not found"
        exit 1
    fi

    echo "Selected: $WHITENOISE_FILE"

    # Save config
    cat > "$CONFIG_FILE" << CONFIG
WHITENOISE_SINK=$WHITENOISE_SINK
DEFAULT_SINK=$DEFAULT_SINK
WHITENOISE_FILE=$WHITENOISE_FILE
CONFIG

    echo "Configuration saved to $CONFIG_FILE"
fi

# Load config
source "$CONFIG_FILE"

# Set default device
pactl set-default-sink "$DEFAULT_SINK"

echo "Starting white noise..."

# Start white noise
mpv --no-video "$WHITENOISE_FILE" --loop=inf &
WN_PID=$!

# Give it a moment to start
sleep 2

# Move the white noise stream to its device
MPVPID=$(pactl list short sink-inputs | grep mpv | awk '{print $1}' | head -1)
if [ -n "$MPVPID" ]; then
    pactl move-sink-input "$MPVPID" "$WHITENOISE_SINK"
    echo "White noise playing on white noise device"
else
    echo "Warning: Could not find white noise stream to move"
fi

echo "Setup complete!"

# Monitor for either device disconnection
(
    while true; do
        if ! pactl list sinks | grep -q "$WHITENOISE_SINK"; then
            echo "White noise device disconnected. Stopping white noise."
            killall mpv 2>/dev/null
            break
        fi
        if ! pactl list sinks | grep -q "$DEFAULT_SINK"; then
            echo "Default device disconnected. Stopping white noise."
            killall mpv 2>/dev/null
            break
        fi
        sleep 5
    done
) &

# Detach the background jobs so they keep running after this script exits
disown -a
