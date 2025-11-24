#!/usr/bin/env bash

set -euo pipefail

sudo pacman -S --noconfirm steam
setsid gtk-launch steam >/dev/nll 2>&1 &
