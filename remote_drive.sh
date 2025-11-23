#!/usr/bin/env bash

set -euo pipefail

storage_server_setup() {
    while true; do
        echo "Please enter server address for remote storage:"
        read -r server_address

        echo "Please enter user name for server:"
        read -r server_user_name

        echo "Please enter share name:"
        read -r shared_directory

        echo "Please enter a password for $server_user_name:"
        read -rsp 'Password: ' passvar1; echo
        echo "Please re-enter the password:"
        read -rsp 'Password: ' passvar2; echo

        if [[ -z "$passvar1" || -z "$passvar2" ]]; then
            echo -e "\nPassword cannot be blank\n"
            continue
        fi

        if [[ "$passvar1" == "$passvar2" ]]; then
            credfile="/etc/samba_credentials"

            # Write credentials safely
            printf "username=%s\npassword=%s\n" "$server_user_name" "$passvar1" | \
                sudo tee "$credfile" >/dev/null
            sudo chmod 600 "$credfile"

            # Create mount directory
            mkdir -p "$HOME/.data"

            # Add to fstab
            echo "//${server_address}/${shared_directory}  ${HOME}/.data  cifs  credentials=$credfile,uid=$(id -u),gid=$(id -g),file_mode=0644,dir_mode=0755,vers=3.0,_netdev,nofail  0 0" |
                sudo tee -a /etc/fstab >/dev/null

            # Mount
            sudo mount -a
            break
        else
            echo -e "\nPasswords did not match.\n"
        fi
    done
}

mkdir -p "$HOME/.data"
storage_server_setup

# Safer: only remove directories if they are symlinks or empty
for d in Documents Music Pictures Videos; do
    if [[ -d "$HOME/$d" && ! -L "$HOME/$d" ]]; then
        mv "$HOME/$d" "$HOME/${d}.backup.$(date +%s)"
    fi
done

ln -sfn "$HOME/.data/Documents" "$HOME/Documents"
ln -sfn "$HOME/.data/Music" "$HOME/Music"
ln -sfn "$HOME/.data/Pictures" "$HOME/Pictures"
ln -sfn "$HOME/.data/Videos" "$HOME/Videos"

echo "Setup complete."

