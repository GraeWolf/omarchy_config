#!/usr/bin/env bash

set -euo pipefail

extra_apps=(bitwarden calibre pcmanfm kdenlive betterbird brave-bin)

for app in "${extra_apps[@]}"; do
	yay -S --noconfirm --needed $app
done


