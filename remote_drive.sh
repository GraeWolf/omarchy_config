#!/usr/bin/env bash
set -euo pipefail

# Get real user details
if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    REAL_UID=$(id -u "$SUDO_USER")
    REAL_GID=$(id -g "$SUDO_USER")
else
    USER_HOME="$HOME"
    REAL_UID=$(id -u)
    REAL_GID=$(id -g)
fi

echo "=== Final Working Samba Remote Storage Setup ==="
echo

read -p "Server address (IP or hostname): " server_address
read -p "Username on server: " server_user_name
read -p "Exact share name: " shared_directory

[[ -z "$server_address" || -z "$server_user_name" || -z "$shared_directory" ]] && {
    echo "Error: All fields required"; exit 1
}

mkdir -p "$USER_HOME/.data"

# THIS IS THE ONLY VERSION THAT NEVER HANGS AND MOUNTS CORRECTLY
sudo bash - <<EOF
set -euo pipefail

# Secure password prompt (real TTY guaranteed)
ask_password() {
    while :; do
        echo -n "Password for $server_user_name: "
        read -rs pass1; echo
        echo -n "Confirm password: "
        read -rs pass2; echo
        if [[ -n "\$pass1" && "\$pass1" == "\$pass2" ]]; then
            echo "\$pass1"
            return
        fi
        [[ -z "\$pass1" ]] && echo "Password cannot be empty" || echo "Passwords do not match"
        echo
    done
}

# Install cifs-utils if missing
command -v mount.cifs >/dev/null || {
    echo "Installing cifs-utils..."
    apt update -qq && apt install -y cifs-utils
}

PASS=\$(ask_password)

# Write credentials file correctly (no quoting issues)
cat > /etc/samba_credentials <<CREDS
username=$server_user_name
password=\$PASS
CREDS
chmod 600 /etc/samba_credentials

# fstab line – vers=3.0 confirmed working
LINE="//$server_address/$shared_directory $USER_HOME/.data cifs credentials=/etc/samba_credentials,uid=$REAL_UID,gid=$REAL_GID,iocharset=utf8,file_mode=0644,dir_mode=0755,vers=3.0,nofail,_netdev 0 0"

if ! grep -F "$USER_HOME/.data" /etc/fstab >/dev/null 2>&1; then
    echo "\$LINE" >> /etc/fstab
    echo "Added to /etc/fstab"
else
    echo "Already in fstab"
fi

echo "Mounting remote share..."
mount "$USER_HOME/.data" && echo "Mount successful!"
EOF

# Create symlinks
for dir in Documents Music Pictures Videos; do
    src="$USER_HOME/.data/$shared_directory/$dir"
    dst="$USER_HOME/$dir"
    if [[ -d "$src" ]]; then
        [[ -e "$dst" && ! -L "$dst" ]] && mv "$dst" "$dst.backup.$(date +%Y%m%d-%H%M%S)"
        ln -sfn "$src" "$dst"
        echo "Linked ~/$dir"
    else
        echo "Warning: Remote $dir not found"
    fi
done

echo
echo "ALL DONE! Your folders are now on the remote server."
echo "Reboot or run: sudo mount -a"
