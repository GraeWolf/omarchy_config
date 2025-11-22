#!/usr/bin/env bash
set -euo pipefail

# Get real user info
if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    REAL_UID=$(id -u "$SUDO_USER")
    REAL_GID=$(id -g "$SUDO_USER")
else
    USER_HOME="$HOME"
    REAL_UID=$(id -u)
    REAL_GID=$(id -g)
fi

echo "=== Remote Samba/CIFS Storage Setup ==="
echo
echo "Please enter the server address (e.g. 192.168.1.50 or nas.local):"
read -r server_address

echo "Please enter the username on the server:"
read -r server_user_name

echo "Please enter the exact share name (folder) as seen on the server:"
read -r shared_directory

[[ -z "$server_address" || -z "$server_user_name" || -z "$shared_directory" ]] && {
    echo "Error: All fields are required."
    exit 1
}

mkdir -p "$USER_HOME/.data"

# ←←← THE ONLY VERSION THAT ACTUALLY WORKS ←←←
sudo bash -s <<'EOF' "$server_address" "$server_user_name" "$shared_directory" "$USER_HOME" "$REAL_UID" "$REAL_GID"
set -euo pipefail

SERVER="$1"
USER="$2"
SHARE="$3"
MOUNTPOINT="$4"
UID="$5"
GID="$6"

# Secure password prompt — this works because we use heredoc with real tty
ask_password() {
    while true; do
        echo "Please enter the password for server user '$USER':"
        read -s PASS1
        echo
        echo "Confirm password:"
        read -s PASS2
        echo
        if [[ "$PASS1" == "$PASS2" ]] && [[ -n "$PASS1" ]]; then
            echo "$PASS1"
            return 0
        elif [[ -z "$PASS1" ]]; then
            echo "Error: Password cannot be empty"
        else
            echo "Error: Passwords do not match — try again"
        fi
        echo
    done
}

# Install cifs-utils if missing
if ! command -v mount.cifs >/dev/null 2>&1; then
    echo "Installing cifs-utils..."
    apt-get update -qq && apt-get install -y cifs-utils
fi

PASS=$(ask_password)

CRED_FILE="/etc/samba_credentials"
cat > "$CRED_FILE" <<EOF2
username=$USER
password=$PASS
EOF2
chmod 600 "$CRED_FILE"

FSTAB_LINE="//$SERVER/$SHARE $MOUNTPOINT cifs credentials=$CRED_FILE,uid=$UID,gid=$GID,iocharset=utf8,file_mode=0644,dir_mode=0755,vers=3.0,nofail,_netdev 0 0"

if ! grep -q "$MOUNTPOINT" /etc/fstab; then
    echo "$FSTAB_LINE" >> /etc/fstab
    echo "Added to /etc/fstab"
else
    echo "Already in fstab — skipping"
fi

echo "Mounting //$SERVER/$SHARE → $MOUNTPOINT"
mount "$MOUNTPOINT" && echo "Mount successful!"

EOF
# ←←← end of sudo block

# Back to normal user — create symlinks
for dir in Documents Music Pictures Videos; do
    remote_dir="$USER_HOME/.data/$shared_directory/$dir"
    local_dir="$USER_HOME/$dir"

    if [[ -d "$remote_dir" ]]; then
        if [[ -e "$local_dir" && ! -L "$local_dir" ]]; then
            backup="$local_dir.backup.$(date +%Y%m%d-%H%M%S)"
            echo "Backing up $local_dir → $backup"
            mv "$local_dir" "$backup"
        fi
        ln -sfn "$remote_dir" "$local_dir"
        echo "Symlinked ~/$dir"
    else
        echo "Warning: Remote $dir not found — skipping"
    fi
done

echo
echo "Setup complete!"
echo "Reboot or run: sudo mount -a"
