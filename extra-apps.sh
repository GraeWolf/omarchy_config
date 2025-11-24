#!/usr/bin/env bash

extra_apps=(bitwarden calibre pcmanfm kdenlive betterbird brave)

for app in "${extra_apps[@]}"; do
	sudo yay -S --noconfirm --needed $app
done


