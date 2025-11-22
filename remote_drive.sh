#!/usr/bin/env bash


password_var() {
	while [ true ]
  do
      echo "Please enter a password for server user :"
      read -sp 'Password: ' passvar1
      echo "Please re-enter the password for server user :"
      read -sp 'Password: ' passvar2

      if [ -z $passvar1 ] || [ -z $passvar2 ]
      then
          echo "Password cannot be blank"
          echo ""
          echo ""
          echo ""

      elif [ $passvar1 == $passvar2 ]
      then
          echo $password1 >> /etc/samba_credentials
          break

      else
          echo "passwords did not match."
          echo ""
          echo ""
          echo ""
      fi
  done
}

mkdir $HOME/.data
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
echo "Please enter server address for remote storage:"
read -p 'Address: ' server_address

echo "Please enter user name for server:"
read -p 'Username: ' server_user_name

sudo sh -c '
  touch /etc/samba_credentials
  echo "username=$server_user_name" >> /etc/samba_credentials
  password_var
  chmod 600 /etc/samba_credentials
  echo "//$server_address     $USER_HOME/.data     cifs    credentials=/etc/samba_credentials,uid=1000,gid=1000,file_mode=0644,dir_mode=0755,vers=3.0,_netdev,nofail,x-systemd.after=wait-for-ping.service    0 0" >> /etc/fstab
  mount -t cifs //$server_address $USER_HOME/.data -o credentials=/etc/samba_credentials
'
rm -rf {Documents,Music,Pictures,Videos}
echo "\nPlease enter the shared directory name:"
read -p 'Shared directory: ' shared_directory

ln -sf $HOME/.data/$shared_directory/Documents $HOME/Documents
ln -sf $HOME/.data/$shared_directory/Music $HOME/Music
ln -sf $HOME/.data/$shared_directory/Pictures $HOME/Pictures
ln -sf $HOME/.data/$shared_directory/Videos $HOME/Videos

