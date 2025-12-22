dual_audio() {
    CONFIG_FILE="$HOME/.config/dual_audio/config"
    mkdir -p "$HOME/.config/dual_audio"
    
    # Initialize config if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "First run setup for dual audio..."
        
        echo ""
        echo "Available audio devices:"
        pactl list sinks | grep -E "Name|Description"
        
        echo ""
        read -p "Enter the sink name for white noise device: " WHITENOISE_SINK
        read -p "Enter the sink name for default device: " DEFAULT_SINK
        
        # Interactive file picker
        echo ""
        echo "Select white noise MP3 file:"
        cd "$HOME" || return 1
        WHITENOISE_FILE=$(find . -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.flac" \) 2>/dev/null | nl)
        
        if [ -z "$WHITENOISE_FILE" ]; then
            echo "No audio files found in home directory"
            return 1
        fi
        
        echo "$WHITENOISE_FILE"
        read -p "Enter the number of your choice: " FILE_NUM
        
        WHITENOISE_FILE=$(find "$HOME" -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.flac" \) 2>/dev/null | sed -n "${FILE_NUM}p")
        
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
        echo "Warning: Could not find mpv stream to move"
    fi

    
    echo "Setup complete!"
}
