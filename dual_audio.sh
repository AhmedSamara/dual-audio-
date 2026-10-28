#!/usr/bin/env bash
#
# dual_audio - play white noise on one audio device while everything else
# plays on another. See README.md for details.
#
# Usage:
#   dual_audio [start]    start white noise + route default audio
#   dual_audio stop       stop white noise
#   dual_audio status     print whether white noise is playing (exit 1 if not)
#   dual_audio ui         open the graphical control window
#   dual_audio setup      pick devices and white noise file interactively
#   dual_audio setup WN_SINK DEFAULT_SINK FILE
#                         same, non-interactively (used by the control window)
#   dual_audio wn  [LVL]  control the white noise device's volume
#   dual_audio def [LVL]  control the default device's volume
#                         LVL: 50 (absolute), +10/-10 (relative), or "mute"
#                         with no LVL, prints that device's current volume
#   dual_audio shortcuts [remove]
#                         add (or remove) GNOME keyboard shortcuts for volume

CONFIG_DIR="$HOME/.config/dual_audio"
CONFIG_FILE="$CONFIG_DIR/config"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/dual_audio-$UID"
MPV_PID_FILE="$STATE_DIR/mpv.pid"
MONITOR_PID_FILE="$STATE_DIR/monitor.pid"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
mkdir -p "$CONFIG_DIR" "$STATE_DIR"

notify() {
    command -v notify-send >/dev/null 2>&1 || return
    notify-send -a "Dual Audio" -i audio-headphones \
        -h string:x-canonical-private-synchronous:dual_audio "Dual Audio" "$1" 2>/dev/null
}

# Print a message, and also show it as a desktop notification when there is
# no terminal (e.g. when run from a keyboard shortcut). The control window
# sets DUAL_AUDIO_NO_NOTIFY since it shows messages itself.
say() {
    echo "$1"
    if [ ! -t 1 ] && [ -z "$DUAL_AUDIO_NO_NOTIFY" ]; then
        notify "$1"
    fi
}

# True if a sink with the exact given name is currently present.
sink_exists() {
    pactl list short sinks | awk '{print $2}' | grep -qxF "$1"
}

# Print "name<TAB>description" for every sink.
list_sinks() {
    pactl list sinks | awk -F': ' '
        /^\tName: /        { name = $2 }
        /^\tDescription: / { print name "\t" $2 }'
}

# Human-readable description of a sink, falling back to its name.
sink_description() {
    local desc
    desc=$(list_sinks | awk -F'\t' -v n="$1" '$1 == n { print $2 }')
    echo "${desc:-$1}"
}

# Current volume of a sink as a bare number (first channel).
sink_volume() {
    pactl get-sink-volume "$1" 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d %
}

# PID from a pid file, only if that process is still alive and is what we
# expect (guards against the PID having been reused by something else).
live_pid() {
    local file="$1" comm="$2" pid
    [ -f "$file" ] || return 1
    pid=$(cat "$file")
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
    [ -z "$comm" ] || [ "$(ps -p "$pid" -o comm= 2>/dev/null)" = "$comm" ] || return 1
    echo "$pid"
}

is_running() {
    live_pid "$MPV_PID_FILE" mpv >/dev/null
}

# Stop our white noise player and its disconnect monitor (and nothing else).
stop_white_noise() {
    local pid
    if pid=$(live_pid "$MONITOR_PID_FILE"); then
        kill "$pid" 2>/dev/null
    fi
    if pid=$(live_pid "$MPV_PID_FILE" mpv); then
        kill "$pid" 2>/dev/null
    fi
    rm -f "$MPV_PID_FILE" "$MONITOR_PID_FILE"
}

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        say "No config found. Run 'dual_audio setup' (or 'dual_audio ui') first."
        exit 1
    fi
    source "$CONFIG_FILE"
}

save_config() {
    {
        printf 'WHITENOISE_SINK=%q\n' "$1"
        printf 'DEFAULT_SINK=%q\n' "$2"
        printf 'WHITENOISE_FILE=%q\n' "$3"
    } > "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE"
}

# Ask the user to pick a sink by number; prints the chosen sink name.
pick_sink() {
    local prompt="$1" num
    local -a names=("${@:2}")
    while true; do
        read -r -p "$prompt" num
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#names[@]}" ]; then
            echo "${names[$((num - 1))]}"
            return
        fi
        echo "Please enter a number between 1 and ${#names[@]}." >&2
    done
}

interactive_setup() {
    local -a names descs
    local name desc i
    while IFS=$'\t' read -r name desc; do
        names+=("$name"); descs+=("$desc")
    done < <(list_sinks)

    if [ "${#names[@]}" -lt 2 ]; then
        echo "Found ${#names[@]} audio device(s); connect both devices and try again."
        exit 1
    fi

    echo ""
    echo "Available audio devices:"
    for i in "${!names[@]}"; do
        printf '  %d) %s  (%s)\n' "$((i + 1))" "${descs[$i]}" "${names[$i]}"
    done
    echo ""

    local wn def
    wn=$(pick_sink "Which device should play white noise? " "${names[@]}")
    while true; do
        def=$(pick_sink "Which device should play everything else? " "${names[@]}")
        [ "$def" != "$wn" ] && break
        echo "Pick a different device than the white noise one."
    done

    echo ""
    echo "Select white noise audio file:"
    local -a files
    mapfile -t files < <(find "$HOME/Music" -type f \( -iname "*.mp3" -o -iname "*.wav" \
        -o -iname "*.flac" -o -iname "*.ogg" -o -iname "*.m4a" \) 2>/dev/null | sort)

    local file=""
    if [ "${#files[@]}" -eq 0 ]; then
        echo "No audio files found in $HOME/Music."
        read -r -e -p "Enter the path to an audio file: " file
        file="${file/#\~/$HOME}"
    else
        for i in "${!files[@]}"; do
            printf '  %d) %s\n' "$((i + 1))" "${files[$i]#"$HOME/Music/"}"
        done
        local num
        while true; do
            read -r -p "Enter the number of your choice: " num
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#files[@]}" ]; then
                file="${files[$((num - 1))]}"
                break
            fi
            echo "Please enter a number between 1 and ${#files[@]}."
        done
    fi

    if [ ! -f "$file" ]; then
        echo "Error: file not found: $file"
        exit 1
    fi
    echo "Selected: $file"
    save_config "$wn" "$def" "$file"
}

# Handle independent volume control: dual_audio wn|def [LEVEL]
volume_command() {
    local which="$1" level="$2" sink label
    load_config
    if [ "$which" = "wn" ]; then
        sink="$WHITENOISE_SINK"; label="White noise"
    else
        sink="$DEFAULT_SINK"; label="Everything else"
    fi

    if ! sink_exists "$sink"; then
        say "$label device ($(sink_description "$sink")) is not connected."
        exit 1
    fi

    if [ -z "$level" ]; then
        echo "$label volume: $(sink_volume "$sink")%"
        return
    fi

    if [ "$level" = "mute" ]; then
        pactl set-sink-mute "$sink" toggle
        if pactl get-sink-mute "$sink" | grep -q yes; then
            say "$label: muted"
        else
            say "$label: unmuted ($(sink_volume "$sink")%)"
        fi
        return
    fi

    if ! [[ "$level" =~ ^[+-]?[0-9]+$ ]]; then
        echo "Invalid level '$level'. Use e.g. 50, +10, -10, or mute."
        exit 1
    fi

    pactl set-sink-mute "$sink" 0
    pactl set-sink-volume "$sink" "${level}%"
    # Don't let relative bumps push past 100% (pactl allows overdriving).
    if [ "$(sink_volume "$sink")" -gt 100 ]; then
        pactl set-sink-volume "$sink" 100%
    fi
    say "$label: $(sink_volume "$sink")%"
}

# Register (or remove) GNOME custom keyboard shortcuts for volume control.
shortcuts_command() {
    local schema=org.gnome.settings-daemon.plugins.media-keys
    local base=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
    local -a entries=(
        "dual-audio-def-up|Dual Audio: everything else louder|def +5|<Control><Super>Up"
        "dual-audio-def-down|Dual Audio: everything else quieter|def -5|<Control><Super>Down"
        "dual-audio-wn-up|Dual Audio: white noise louder|wn +5|<Control><Super><Shift>Up"
        "dual-audio-wn-down|Dual Audio: white noise quieter|wn -5|<Control><Super><Shift>Down"
    )

    if ! command -v gsettings >/dev/null 2>&1; then
        echo "gsettings not found; keyboard shortcuts require GNOME."
        exit 1
    fi

    local list entry id name args binding path
    list=$(gsettings get "$schema" custom-keybindings)
    list="${list#@as }"

    for entry in "${entries[@]}"; do
        IFS='|' read -r id name args binding <<< "$entry"
        path="$base/$id/"
        # Drop any existing reference to this path first.
        list=$(echo "$list" | sed -E "s#, '$path'##; s#'$path', ##; s#'$path'##")
        if [ "$1" = "remove" ]; then
            gsettings reset-recursively "$schema.custom-keybinding:$path"
        else
            if [ "$list" = "[]" ]; then
                list="['$path']"
            else
                list="${list%]}, '$path']"
            fi
            gsettings set "$schema.custom-keybinding:$path" name "$name"
            gsettings set "$schema.custom-keybinding:$path" command "$SELF $args"
            gsettings set "$schema.custom-keybinding:$path" binding "$binding"
        fi
    done
    gsettings set "$schema" custom-keybindings "$list"

    if [ "$1" = "remove" ]; then
        echo "Removed Dual Audio keyboard shortcuts."
    else
        echo "Added keyboard shortcuts:"
        echo "  Ctrl+Super+Up / Down          everything else louder / quieter"
        echo "  Ctrl+Super+Shift+Up / Down    white noise louder / quieter"
        echo "Change them in Settings > Keyboard > Custom Shortcuts."
    fi
}

start_command() {
    if [ ! -f "$CONFIG_FILE" ]; then
        if [ -t 0 ]; then
            echo "First run setup for dual audio..."
            interactive_setup
        else
            say "No config found. Run 'dual_audio setup' (or 'dual_audio ui') first."
            exit 1
        fi
    fi
    load_config

    # Make sure both configured devices are actually connected before starting.
    if ! sink_exists "$WHITENOISE_SINK"; then
        say "White noise device ($(sink_description "$WHITENOISE_SINK")) is not connected."
        exit 1
    fi
    if ! sink_exists "$DEFAULT_SINK"; then
        say "Default device ($(sink_description "$DEFAULT_SINK")) is not connected."
        exit 1
    fi
    if [ ! -f "$WHITENOISE_FILE" ]; then
        say "White noise file not found: $WHITENOISE_FILE"
        exit 1
    fi

    stop_white_noise
    pactl set-default-sink "$DEFAULT_SINK"

    # Play white noise directly on the white noise device. Targeting the sink
    # with --audio-device avoids having to find and move the stream afterward.
    mpv --no-video --really-quiet --loop=inf --audio-device="pulse/$WHITENOISE_SINK" \
        "$WHITENOISE_FILE" </dev/null >/dev/null 2>&1 &
    local wn_pid=$!
    echo "$wn_pid" > "$MPV_PID_FILE"

    # Stop white noise if either device disconnects. Exits on its own once
    # mpv is gone, so stopping never leaves this loop behind.
    (
        while kill -0 "$wn_pid" 2>/dev/null; do
            if ! sink_exists "$WHITENOISE_SINK" || ! sink_exists "$DEFAULT_SINK"; then
                kill "$wn_pid" 2>/dev/null
                rm -f "$MPV_PID_FILE" "$MONITOR_PID_FILE"
                notify "A device disconnected. White noise stopped."
                break
            fi
            sleep 5
        done
    ) </dev/null >/dev/null 2>&1 &
    echo "$!" > "$MONITOR_PID_FILE"

    # Detach the background jobs so they keep running after this script exits
    disown -a

    echo "White noise playing on $(sink_description "$WHITENOISE_SINK")"
    echo "Everything else playing on $(sink_description "$DEFAULT_SINK")"
}

case "$1" in
    ""|start)
        start_command
        ;;
    stop)
        stop_white_noise
        say "White noise stopped"
        ;;
    status)
        if is_running; then
            echo "White noise is playing"
        else
            echo "White noise is stopped"
            exit 1
        fi
        ;;
    setup)
        if [ "$#" -eq 4 ]; then
            save_config "$2" "$3" "$4"
        else
            interactive_setup
        fi
        ;;
    wn|def)
        volume_command "$1" "$2"
        ;;
    ui)
        # Terminals inside snap apps (e.g. VS Code) inject their own GTK
        # paths, which crash system Python's GTK. Undo that before launching.
        [ -n "$XDG_DATA_DIRS_VSCODE_SNAP_ORIG" ] && export XDG_DATA_DIRS="$XDG_DATA_DIRS_VSCODE_SNAP_ORIG"
        [ -n "$XDG_CONFIG_DIRS_VSCODE_SNAP_ORIG" ] && export XDG_CONFIG_DIRS="$XDG_CONFIG_DIRS_VSCODE_SNAP_ORIG"
        unset GTK_PATH GTK_EXE_PREFIX GTK_IM_MODULE_FILE GDK_PIXBUF_MODULE_FILE \
            GDK_PIXBUF_MODULEDIR GIO_MODULE_DIR GSETTINGS_SCHEMA_DIR LOCPATH
        setsid -f python3 "$(dirname "$SELF")/dual_audio_gui.py" </dev/null >/dev/null 2>&1
        ;;
    shortcuts)
        shortcuts_command "$2"
        ;;
    -h|--help|help)
        sed -n '3,/^$/p' "$SELF" | sed 's/^# \{0,1\}//'
        ;;
    *)
        echo "Unknown command '$1'. Run 'dual_audio help' for usage."
        exit 1
        ;;
esac
