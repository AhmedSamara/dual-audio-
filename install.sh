#!/usr/bin/env bash
#
# Installs dual_audio as a command on your PATH by symlinking it into
# ~/.local/bin, and adds a "Dual Audio" entry to your app launcher.
# Re-running is safe (idempotent).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/dual_audio.sh"
BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/dual_audio"
APPS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPS_DIR/dual-audio.desktop"

# Check dependencies
for cmd in pactl mpv; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Warning: '$cmd' is not installed. Install it with: sudo apt install $cmd"
    fi
done
if ! python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null; then
    echo "Warning: the control window needs GTK for Python. Install it with:"
    echo "    sudo apt install python3-gi gir1.2-gtk-3.0"
fi

mkdir -p "$BIN_DIR" "$APPS_DIR"
chmod +x "$SOURCE" "$SCRIPT_DIR/dual_audio_gui.py"
ln -sf "$SOURCE" "$TARGET"
echo "Linked $TARGET -> $SOURCE"

cat > "$DESKTOP_FILE" << DESKTOP
[Desktop Entry]
Type=Application
Name=Dual Audio
Comment=Control white noise and default audio on separate devices
Exec=$TARGET ui
Icon=audio-headphones
Terminal=false
Categories=AudioVideo;Audio;
DESKTOP
echo "Added app launcher entry: $DESKTOP_FILE"

# Warn if ~/.local/bin isn't on PATH
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo ""
        echo "NOTE: $BIN_DIR is not on your PATH. Add this to your ~/.bashrc:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

# Offer to remove an old copy-pasted dual_audio() function from ~/.bashrc
if grep -q "^dual_audio()" "$HOME/.bashrc" 2>/dev/null; then
    echo ""
    echo "Found an old dual_audio() function pasted in ~/.bashrc."
    echo "It now shadows the installed command. Remove it manually, or run:"
    echo "    sed -i '/^dual_audio() {/,/^}/d' ~/.bashrc"
fi

# Offer GNOME keyboard shortcuts for volume control
if command -v gsettings >/dev/null 2>&1 && [ -t 0 ]; then
    echo ""
    read -r -p "Add keyboard shortcuts for volume (Ctrl+Super+Up/Down, add Shift for white noise)? [y/N] " answer
    if [[ "$answer" =~ ^[Yy] ]]; then
        "$TARGET" shortcuts
    else
        echo "Skipped. You can add them later with: dual_audio shortcuts"
    fi
fi

echo ""
echo "Done. Open \"Dual Audio\" from your app launcher, or use: dual_audio"
echo "(Open a new terminal or run 'hash -r' first if the command isn't found.)"
