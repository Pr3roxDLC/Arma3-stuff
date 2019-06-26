#!/bin/bash
steam_home="/home/steam/"
a3_dir="$steam_home"arma3server
yum install epel-release -y
yum install -y glibc libstdc++ glibc.i686 libstdc++.i686 jq unzip dos2unix
useradd -m steam
cp server.sh hc.sh update-mods.sh "$steam_home"

if [ ! -f ${steam_home}secret.key ]; then
  cryptkey=$(< /dev/urandom tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
  echo "$cryptkey" > ${steam_home}secret.key
  chmod 600 ${steam_home}secret.key
  chown steam:steam ${steam_home}secret.key
else
  cryptkey=$(cat "$steam_home"secret.key)
fi

if [ ! -f "$steam_home"config.cfg ]; then
 cp config.cfg "$steam_home"config.cfg
fi
cd "$steam_home" || exit
sudo -u steam bash -c 'curl -sL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -'
sudo -u steam bash -c './steamcmd.sh +login anonymous +quit'
if [ ! -d  $a3_dir ]; then
  if ! mkdir -p $a3_dir; then
    printf "Could not create %s \n" $a3_dir
    exit 1
  fi
fi
chown -R steam:steam "$steam_home"
cat <<EOF > /etc/systemd/system/arma3-server.service
[Unit]
Description=Arma 3 Server
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=${steam_home}server.sh
User=steam

[Install]
WantedBy=multi-user.target

EOF
chmod 664 /etc/systemd/system/arma3-server.service
cat <<EOF > /etc/systemd/system/arma3-hc.service
[Unit]
Description=Arma 3 Headless Client
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=${steam_home}hc.sh
User=steam

[Install]
WantedBy=multi-user.target

EOF
chmod 664 /etc/systemd/system/arma3-hc.service
systemctl daemon-reload

# shellcheck source=config.cfg
# shellcheck disable=SC1091
source "$steam_home"config.cfg


echo foobar | openssl enc -aes-256-cbc -a -salt -pass pass:"${cryptkey}"
echo "U2FsdGVkX1+cTNMgPtKnStYDtIWu8ZvodVqJXezW7rk=" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"${cryptkey}"

printf "\n"
printf "Please enter steam user credentials for the server\n"
printf "This user should be a blank user, with no games, vallets or anything!\n"
printf "Disable any 2 factor auth for this user\n"
printf "\n"
printf "Arma 3 dedicated server is a free tool, so DO NOT USER YOUR PERSONAL STEAM ACCCOUNT HERE!\n"
printf "\n"
read -rp "username (${STEAMUSER}):" STEAMUSER_new
if [[ -n $STEAMUSER_new ]]; then
    STEAMUSER=${STEAMUSER_new}
    sed -i "/STEAMUSER=/c\STEAMUSER=\"${STEAMUSER}\"" "$steam_home"config.cfg
fi

# shellcheck disable=2153
if [[ -n $STEAMPASS ]]; then
  STEAMPASS_decrypted=$(echo "${STEAMPASS}" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"${cryptkey}")
fi
read -rp "password (${STEAMPASS_decrypted}):" STEAMPASS_new
if [[ -n $STEAMPASS_new ]]; then
    STEAMPASS_new_crypted=$(echo "${STEAMPASS_new}" | openssl enc -aes-256-cbc -a -salt -pass pass:"${cryptkey}")
    sed -i "/STEAMPASS=/c\STEAMPASS=\"${STEAMPASS_new_crypted}\"" "$steam_home"config.cfg
fi

is_set=false
while [[ $is_set = "false" ]]; do
    printf "\n"
    read -rp "Do you want to use the steam workshop to download mods for Arma 3 Server? (y|n)" yn
    if [[ $yn = "y" || $yn = "n" ]]; then
      is_set=true
    fi
done

if [[ $yn = "y" ]]; then
  printf "\n"
  printf "\n"
  printf "Steam workshop downloads for Arma 3 need an account that owns the Arma 3 Game\n"
  printf "\n"
  printf "Please set the steam users steam guard to mail token, so we can now authentificate on this server\n"
  printf "\n"
  printf "Please enter the steam username, which owns Arma3\n"

  read -rp "username (${STEAMWSUSER}):" STEAMWSUSER_new
  if [[ -n $STEAMWSUSER_new ]]; then
    STEAMWSUSER=${STEAMWSUSER_new}
    sed -i "/STEAMWSUSER=/c\STEAMWSUSER=\"${STEAMWSUSER}\"" "$steam_home"config.cfg
  fi

  # shellcheck disable=2153
  if [[ -n $STEAMWSPASS ]]; then
    STEAMWSPASS_decrypted=$(echo "${STEAMWSPASS}" | openssl enc -aes-256-cbc -a -d -salt -pass pass:"${cryptkey}")
  fi
  read -rp "password (${STEAMWSPASS_decrypted}):" STEAMPASS_new
  if [[ -n $STEAMWSPASS_new ]]; then
      STEAMWSPASS_new_crypted=$(echo "${STEAMWSPASS_new}" | openssl enc -aes-256-cbc -a -salt -pass pass:"${cryptkey}")
      sed -i "/STEAMWSPASS=/c\STEAMWSPASS=\"${STEAMWSPASS_new_crypted}\"" "$steam_home"config.cfg
  fi

  sed -i "/MODUPDATE=/c\MODUPDATE=workshop" "$steam_home"config.cfg
  printf "\n"
  sudo -u steam bash -i -c "./steamcmd.sh +login ${STEAMWSUSER} ${STEAMWSPASS} +quit"
  printf "\n"

  is_ynids_set=false
  while [[ $is_ynids_set = "false" ]]; do
    printf "\n"
    read -rp "Do you want to configure the modlist now? You will need the workshop item IDs for this. (y|n)" ynids
    printf "\n"
    if [[ $ynids = "y" || $ynids = "n" ]]; then
      is_ynids_set=true
    fi
  done
  declare -a ws_ids
  if [[ $ynids = "y" ]]; then
    numbers_finished=false
    while [ "$numbers_finished" == "false" ]; do
      read -rp "Workshop ID or empty if you are finished:" id
      if [[ $id =~ ^[0-9]+$ ]]; then
        ws_ids+=("$id")
      else
        numbers_finished=true
      fi
    done
  sed -i "/WS_IDS=/c\WS_IDS=(${ws_ids[*]})" "$steam_home"config.cfg
  else
    printf "Don't forget to configure your mod IDs as a list (WS_IDS) in %sconfig.cfg\n" "$steam_home"
  fi
fi

printf "\n"
printf "You can now start the server with \'systemctl start arma3-server.service\' \n"
printf "Or you can start the headless client with \'systemctl start arma3-hc.service\' \n"
printf "\n"
printf "The initial start will take some time, as we have to download arma3 server\n"
printf "\n"
printf "Make sure to edit the %sconfig.cfg to match your requirements! \n" "$steam_home"
printf "If you use direct mod download, you will need a .secrets in %s \n" "$steam_home"
printf "\n"
