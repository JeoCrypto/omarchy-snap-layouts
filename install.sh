#!/bin/bash

# Install Snap Layouts for the current user.
# Copies the picker into ~/.config/quickshell/snap-layouts and the snap-layout
# command into ~/.local/bin. Does not touch your Hyprland config; see README.md
# for the keybinding, autostart and blur.

set -e

src="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.config/quickshell/snap-layouts" "$HOME/.local/bin"
cp "$src/shell.qml" "$src/SnapLayouts.qml" "$HOME/.config/quickshell/snap-layouts/"
mkdir -p "$HOME/.config/quickshell/snap-layouts/bin"
install -m 755 "$src/bin/snap-layout" "$HOME/.config/quickshell/snap-layouts/bin/snap-layout"
install -m 755 "$src/bin/snap-layout" "$HOME/.local/bin/snap-layout"

echo "Snap Layouts installed."
echo
echo "Start it now:            qs -c snap-layouts &"
echo "Open the picker:         qs -c snap-layouts ipc call snap toggle"
echo "Keybinding and autostart: see README.md"
