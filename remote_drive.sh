#!/usr/bin/env bash
set -euo pipefail

# Get real user info early
if [[ -n "${SUDO_USER:-}" ]]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    REAL_UID=$(id -u "$SUDO_USER")
    REAL_GID=$(id -g "$SUDO_USER")
else
    USER_HOME="$HOME"
    REAL_UID=$(id -u)
    REAL_GID=$(id -g)
fi

echo "Please enter server address (e.g. 192.168.1.100 or server.local):"
read -r server_address

echo "Please enter username for the server:"
read -r server_user_name

echo "Please enter the shared folder name exactly as it appears on the server:"
read -r shared_directory

# Validate
[[ -z "$server_address" || -z "$server_user_name" || -z "$shared_directory" ]] && {
    echo "Error: All fields are required."
    exit 1
}

mkdir -p "$USER_HOME/.data"

# === EVERYTHING REQUIRING ROOT + PASSWORD PROMPT RUNS IN ONE sudo BLOCK ===
sudo bash -c "
set -euo pipefail

# Function defined inside sudo context
password_var() {
    while true; do
        echo 'Please enter the password for server user:'
        read -s -r pass1
        echo
        echo 'Please re-enter the password:'
        read -s -r pass2
        echo
        if [[ -z \"\$pass1\" || -z \"\$pass2\" ]]; then
            echo 'Error: Password cannot be blank'
        elif [[ \"\$pass1\" == \"\$pass2\" ]]; then
            echo \"\$pass1\"
            return 0
        else
            echo 'Error: Passwords do not match'
        fi
        echo
    done
}

# Install cifs-utils if missing (Debian/Ubuntu)
if ! command -v mount.cifs >/dev/null 2>&1; then
    echo 'Installing cifs-utils...'
    apt-get update -qq && apt-get install -y cifs-utils
fi

# Ask for password NOW (inside sudo → clean terminal)
server_password=\$(password_var)

cred  echo 'Creating credentials file...'
cred_file='/etc/samba_credentials'
cat > \"\$cred_file\" <<EOF
username=$server_user_name
password=\$server_password
EOF
chmod 600 \"\$cred_file\"

# fstab line
fstab_line=\"//${server_address}/${shared_directory} ${USER_HOME}/.data cifs credentials=\$cred_file,uid=$REAL_UID,gid=$REAL_GID,iocharset=utf8,rw,file_mode=0644,dir_mode=0755,vers=3.0,nofail,_netdev 0 0\"

if ! grep -F \"${USER_HOME}/.data\" /etc/fstab >/dev/null; then
    echo \"\$fstab_line\" >> /etc/fstab
    echo 'Added entry to /etc/fstab'
else
    echo 'Entry already exists in /etc/fstab'
fi

echo 'Mounting the share...'
mount \"${USER_HOME}/.data\" && echo 'Mount successful!'

"

# === Back to user context - create symlinks ===
for dir in Documents Music Pictures Videos; do
    src=\"${USER_HOME}/.data/${shared_directory}/${dir}\"
    dst=\"${USER_HOME}/${dir}\"

    if [[ -d \"\$src\" ]]; then
        if [[ -d \"\$dst\" && ! -L \"\$dst\" ]]; then
            backup=\"\$dst.backup.\$(date +%Y%m%d-%H%M%S)\"
            echo \"Backing up local \$dir → \$backup\"
            mv \"\$dst\" \"\$backup\"
        fi
        ln -sfn \"\$src\" \"\$dst\"
        echo \"Linked ~/${dir}\"
    else
        echo \"Warning: Remote directory \$src does not exist - skipping ~/${dir}\"
    fi
done

echo
echo "All done! Your folders are now linked to the remote server."
echo "Reboot recommended (or run 'sudo mount -a' to remount everything)."
