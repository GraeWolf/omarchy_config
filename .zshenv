# zsh config dir
export ZDOTDIR=$HOME/.config/zsh

# unlock the keyring
eval $(/usr/bin/gnome-keyring-daemon --start --components=gpg,ssh,pkcs11,secrets)
export GNOME_KEYRING_CONTROL GNOME_KEYRING_PID GPG_AGENT_INFO SSH_AUTH_SOCK
export SSH_AUTH_SOCK="$GNOME_KEYRING_CONTROL/ssh"
