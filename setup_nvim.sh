#!/usr/bin/env bash

set -euo pipefail

echo "Setting up Nvim"
if [ -d "$HOME/.config/nvim" ]; then
	rm -rf "$HOME/.config/nvim"
	ln -sfn "$HOME/.local/share/omarchy_config/nvim $HOME/.config/nvim"
else
	ln -sfn "$HOME/.local/share/omarchy_config/nvim $HOME/.config/nvim"
fi
