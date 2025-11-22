#!/usr/bin/env bash
set -euo pipefail

# ——— Get real user details (even when script is run with sudo) ———
if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    REAL_UID=$(id -u "$SUDO_USER")
    REAL_GID=$(id -g "$SUDO_USER")
else
    USER_HOME="$HOME"
    REAL_UID=$(id -u)
    REAL_GID=$(id -g)
fi

echo "=== Samba/CIFS Remote Storage Setup ==="
echo
read -p "Server address (e.g. 192.168.1.100 or nas.local): " server_address
read -p "Username on the server: " server_user_name
read -p "Exact share name on the server: " shared_directory

[[ -z "$server_address" || -z "$server_user_name" || -z "$shared_directory" ]] && {
    echo "Error: All fields are required."
    exit 1
}

mkdir -p "$USER_HOME/.data"

# ——— Everything that needs root + interactive password prompt ———
sudo bash -s <<EOF "$server_address" "$server_user_name" "$shared_directory" "$USER_HOME" "$REAL_UID" "$REAL_GID"
set -euo pipefail

SERVER="\$1"
USER="\$2"
SHARE="\$3"
MOUNTPOINT="\$4"
TARGET_UID="\$5"   # ← renamed to avoid clash with readonly UID
TARGET_GID="\$6"

# Secure password prompt (works because we have a real TTY)
ask_password() {
    while true; do
        echo "Please enter password for server user '\$USER':"
        read -rs PASS1; echo
        echo "Confirm password:"
        read -rs PASS2; echo
        if [[ "\$PASS1" == "\$PASS2" && -n "\$PASS1" ]]; then
            echo "\$PASS1"
            return 0
        elif [[ -z "\$PASS1" ]]; then
            echo "Password cannot be empty"
        else
            echo "Passwords do not match – try again"
        fi
        echo
    done
}

# Install cifs-utils if missing
if ! command -v mount.cifs >/dev/null 2>&1; then
    echo "Installing cifs-utils..."
    apt-get update -qq && apt-get install -y cifs-utils
fi

PASSWORD=\$(ask_password)

CRED_FILE="/etc/samba_credentials"
cat > "\$CRED_FILE" <<CREDS
username=\$USER
password=\$PASSWORD
CREDS
chmod 600 "\$CRED_FILE"

FSTAB_LINE="//\$SERVER/\$SHARE \$MOUNTPOINT cifs credentials=\$CRED_FILE,uid=\$TARGET_UID,gid=\$TARGET_GID,iocharset=utf8,file_mode=0644,dir_mode=0755,vers=3.0,nofail,_netdev 0 0"

if ! grep -F "\$MOUNTPOINT" /etc/fstab >/dev/null 2>&1; then
    echo "\$FSTAB_LINE" >> /etc/fstab
    echo "Added to /etc/fstab"
else
    echo "Already present in /etc/fstab"
fi

echo "Mounting //\$SERVER/\$SHARE → \$MOUNTPOINT"
mount "\$MOUNTPOINT" && echo "Mount successful!"
EOF

# ——— Back to normal user: create symlinks ———
for dir in Documents Music Pictures Videos; do
    remote="$USER_HOME/.data/$shared_directory/$dir"
    local="$USER_HOME/$dir"

    if [[ -d "$remote" ]]; then
        if [[ -e "$local" && ! -L "$local" ]]; then
            mv "$local" "$local.backup.$(date +%Y%m%d-%H%M%S)"
            echo "Backed up $local"
        fi
        ln -sfn "$remote" "$local"
        echo "Symlinked ~/$dir"
    else
        echo "Warning: Remote $dir not found – skipping"
    fi
done

echo
echo "Setup complete! Reboot or run 'sudo mount -a' to remount."
