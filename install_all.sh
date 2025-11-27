#!/usr/bin/env bash

set -euo pipefail

# Run all install and setup scripts
./extra_apps.sh
./remote_drive.sh
./setup_nvim.sh
./install_zsh.sh
./set_shell.sh
./ssh_setup.sh
./steam_install.sh

