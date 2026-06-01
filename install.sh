#!/usr/bin/env bash
#
# Installs dual_audio as a command on your PATH by symlinking it into
# ~/.local/bin. Re-running is safe (idempotent).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$SCRIPT_DIR/dual_audio.sh"
BIN_DIR="$HOME/.local/bin"
TARGET="$BIN_DIR/dual_audio"

# Check dependencies
for cmd in pactl mpv; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Warning: '$cmd' is not installed. Install it with: sudo apt install $cmd"
    fi
done

mkdir -p "$BIN_DIR"
chmod +x "$SOURCE"
ln -sf "$SOURCE" "$TARGET"
echo "Linked $TARGET -> $SOURCE"

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

echo ""
echo "Done. Open a new terminal (or run 'hash -r') and use: dual_audio"
