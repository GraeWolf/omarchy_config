#!/usr/bin/env bash
set -euo pipefail

# Function to securely ask for password twice
password_var() {
    while true; do
        echo "Please enter a password for server user:"
        read -s -r passvar1
        echo
        echo "Please re-enter the password for server user:"
        read -s -r passvar2
        echo

        if [[ -z "$passvar1" || -z "$passvar2" ]]; then
            echo "Error: Password cannot be blank."
        elif [[ "$passvar1" == "$passvar2" ]]; then
            printf '%s\n' "$passvar1"
            return 0
        else
            echo "Error: Passwords did not match."
        fi
        echo
    done
}

# Get real user home (works even when run with sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    REAL_UID=$(id -u "$SUDO_USER")
    REAL_GID=$(id -g "$SUDO_USER")
else
    USER_HOME="$HOME"
    REAL_UID=$(id -u)
    REAL_GID=$(id -g)
fi

echo "Please enter server address for remote storage (e.g. 192.168.1.100 or myserver.local):"
read -r server_address

echo "Please enter username for the server:"
read -r server_user_name

echo "Please enter the shared directory name on the server (the top-level share):"
read -r shared_directory

# Get password securely (capture output of the function)
echo
server_password=$(password_var)

# Validate inputs
if [[ -z "$server_address" || -z "$server_user_name" || -z "$shared_directory" ]]; then
    echo "Error: All fields are required."
    exit 1
fi

# Create mount point
mkdir -p "$USER_HOME/.data"

# Everything that requires root privileges
sudo bash -c "
set -euo pipefail

# Install cifs-utils if missing (Debian/Ubuntu)
if ! command -v mount.cifs >/dev/null 2>&1; then
    echo 'Installing cifs-utils...'
    apt-get update && apt-get install -y cifs-utils
fi

# Create credentials file securely
cred_file='/etc/samba_credentials'
umask 077
cat > \"\$cred_file\" <<EOF
username=$server_user_name
password=$server_password
EOF
chmod 600 \"\$cred_file\"

# Add to fstab (only if not already present)
fstab_line=\"//${server_address}/${shared_directory} ${USER_HOME}/.data cifs credentials=\$cred_file,uid=$REAL_UID,gid=$REAL_GID,iocharset=utf8,file_mode=0644,dir_mode=0755,vers=3.0,nofail,_netdev 0 0\"

if ! grep -q \"${USER_HOME}/.data\" /etc/fstab; then
    echo \"\$fstab_line\" >> /etc/fstab
    echo 'Entry added to /etc/fstab'
else
    echo 'Mount point already exists in /etc/fstab, skipping.'
fi

# Perform the mount
echo 'Mounting the share...'
mount \"${USER_HOME}/.data\" || {
    echo 'Mount failed. Check server address, credentials, and network.'
    exit 1
}

echo 'Successfully mounted //${server_address}/${shared_directory} → ${USER_HOME}/.data'
"

# Create symlinks (only if real directories exist and are not already symlinks)
for dir in Documents Music Pictures Videos; do
    target="$USER_HOME/.data/$shared_directory/$dir"
    link="$USER_HOME/$dir"

    if [[ -d "$target" && ! -L "$link" && -d "$link" ]]; then
        echo "Moving existing $dir to $dir.backup.$(date +%Y%m%d-%H%M%S)"
        mv "$link" "$link.backup.$(date +%Y%m%d-%H%M%S)"
    fi

    if [[ -d "$target" ]]; then
        ln -sfn "$target" "$link"
        echo "Linked ~/$dir → remote $dir"
    else
        echo "Warning: Remote directory $target does not exist, skipping ~/$dir"
    fi
done

echo
echo "Setup complete!"
echo "Your Documents, Music, Pictures and Videos are now stored on the remote server."
echo "Reboot recommended for the mount to be fully persistent."
