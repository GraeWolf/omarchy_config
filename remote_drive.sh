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

echo "=== Samba/CIFS Remote Storage Setup ==="
echo

read -p "Server address (IP or hostname): " server_address
read -p "Username on the server: " server_user_name
read -p "Exact share name on the server: " shared_directory

[[ -z "$server_address" || -z "$server_user_name" || -z "$shared_directory" ]] && {
    echo "Error: All fields required"
    exit 1
}

mkdir -p "$USER_HOME/.data"

# THIS IS THE ONLY METHOD THAT NEVER HANGS
sudo script -q -c "
set -euo pipefail

ask_password() {
    while :; do
        echo -n 'Password for $server_user_name: '
        read -rs pass1; echo
        echo -n 'Confirm password: '
        read -rs pass2; echo
        [[ -n \"\$pass1\" && \"\$pass1\" == \"\$pass2\" ]] && { echo \"\$pass1\"; return; }
        [[ -z \"\$pass1\" ]] && echo 'Password cannot be empty' || echo 'Passwords do not match'
        echo
    done
}

# Install cifs-utils if missing
command -v mount.cifs >/dev/null || {
    echo 'Installing cifs-utils…'
    apt-get update -qq && apt-get install -y cifs-utils
}

PASS=\$(ask_password)

cat > /etc/samba_credentials <<EOF
username=$server_user_name
password=\$PASS
EOF
chmod 600 /etc/samba_credentials

LINE=\"//$server_address/$shared_directory $USER_HOME/.data cifs credentials=/etc/samba_credentials,uid=$REAL_UID,gid=$REAL_GID,iocharset=utf8,file_mode=0644,dir_mode=0755,vers=3.0,nofail,_netdev 0 0\"

if ! grep -F \"$USER_HOME/.data\" /etc/fstab >/dev/null 2>&1; then
    echo \"\$LINE\" >> /etc/fstab
    echo 'Added to /etc/fstab'
fi

echo 'Mounting…'
mount \"$USER_HOME/.data\" && echo 'Mount successful!'
" /dev/null

# Back to normal user – symlinks
for d in Documents Music Pictures Videos; do
    src=\"$USER_HOME/.data/$shared_directory/$d\"
    dst=\"$USER_HOME/$d\"
    if [[ -d \"\$src\" ]]; then
        [[ -e \"\$dst\" && ! -L \"\$dst\" ]] && mv \"\$dst\" \"\$dst.backup.$(date +%Y%m%d-%H%M%S)\"
        ln -sfn \"\$src\" \"\$dst\"
        echo \"Linked ~/$d\"
    else
        echo \"Warning: Remote $d not found\"
    fi
done

echo
echo "All done! Reboot or run: sudo mount -a"
