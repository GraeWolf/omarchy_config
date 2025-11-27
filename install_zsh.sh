#!/usr/bin/env bash

set -euo pipefail

if ! command -v zsh &>/dev/null; then
	sudo pacman -S --noconfirm zsh
	ln -sfn "$HOME/.local/share/omarchy_config/zsh" "$HOME/.config/"
	ln -sfn "$HOME/.local/share/omarchy_config/.zshenv" "$HOME/"
fi
