#!/usr/bin/env bash

set -euo pipefail

# Check to see if the .data directory is mounted and the .ssh directory exists
if [ -d "~/.data/.ssh" ]; then
	cp -R ".data/.ssh" "$HOME/"
	chmod 700 "$HOME/.ssh"
	chmod 600 "$HOME/.ssh/id_"* "$HOME/.ssh/config"
	chmod 644 "$HOME/.ssh/"*.pub
	echo ".ssh has been copied over and permissions set"
else
	echo "Directory not found"
fi
