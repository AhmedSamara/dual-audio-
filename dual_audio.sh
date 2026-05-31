dual_audio() {
    CONFIG_FILE="$HOME/.config/dual_audio/config"
    mkdir -p "$HOME/.config/dual_audio"
    
    # Handle stop command
    if [ "$1" = "stop" ]; then
        killall mpv 2>/dev/null
        echo "White noise stopped"
        return 0
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
            return 1
        fi

        echo "$AUDIO_FILES" | nl
        read -p "Enter the number of your choice: " FILE_NUM

        WHITENOISE_FILE=$(echo "$AUDIO_FILES" | sed -n "${FILE_NUM}p")
        
        # Validate file exists
        if [ ! -f "$WHITENOISE_FILE" ]; then
            echo "Error: Invalid selection or file not found"
            return 1
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
}