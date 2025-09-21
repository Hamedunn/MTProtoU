#!/bin/bash
regex='^[0-9]+$'
function RemoveMultiLineUser() {
  local SECRET_T=$(python3 -c 'import config;print(getattr(config, "USERS",""))')
  SECRET_T=$(echo "$SECRET_T" | tr "'" '"')
  python3 -c "import re;f = open('config.py', 'r');s = f.read();p = re.compile('USERS\\s*=\\s*\\{.*?\\}', re.DOTALL);nonBracketedString = p.sub('', s);f = open('config.py', 'w');f.write(nonBracketedString)"
  echo "" >>config.py
  echo "USERS = $SECRET_T" >>config.py
}
function GetRandomPort() {
  if ! [ "$INSTALLED_LSOF" == true ]; then
    echo "Installing lsof package. Please wait."
    apt-get -y install lsof >/dev/null
    local RETURN_CODE=$?
    if [ $RETURN_CODE -ne 0 ]; then
      echo "$(tput setaf 3)Warning!$(tput sgr 0) lsof package did not installed successfully. The randomized port may be in use."
    else
      INSTALLED_LSOF=true
    fi
  fi
  PORT=$((RANDOM % 16383 + 49152))
  if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; then
    GetRandomPort
  fi
}
function GenerateConnectionLimiterConfig() {
  LIMITER_CONFIG=""
  LIMITER_FILE=""
  for user in "${!limits[@]}"; do
    LIMITER_CONFIG+='"'
    LIMITER_CONFIG+=$user
    LIMITER_CONFIG+='": '
    LIMITER_CONFIG+=${limits[$user]}
    LIMITER_CONFIG+=" , "
    LIMITER_FILE+="$user;${limits[$user]}\n"
  done
  if ! [[ ${#limits[@]} == 0 ]]; then
    LIMITER_CONFIG=${LIMITER_CONFIG::${#LIMITER_CONFIG}-2}
  fi
}
function RestartService() {
  pid=$(systemctl show --property MainPID mtprotoproxy)
  arrPID=(${pid//=/ })
  pid=${arrPID[1]}
  kill -USR2 "$pid"
}
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root"
  exit 1
fi
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [ -d "/opt/mtprotoproxy" ]; then
  cd /opt/mtprotoproxy/ || exit 2
  if [ $# -ge 1 ]; then
    OPTION=$1
    case $OPTION in
    1)
      PUBLIC_IP="$(curl https://api.ipify.org -sS)"
      CURL_EXIT_STATUS=$?
      if [ $CURL_EXIT_STATUS -ne 0 ]; then
        PUBLIC_IP="YOUR_IP"
      fi
      PORT=$(python3 -c 'import config;print(getattr(config, "PORT",-1))')
      SECRET=$(python3 -c 'import config;print(getattr(config, "USERS",""))')
      SECRET_COUNT=$(python3 -c 'import config;print(len(getattr(config, "USERS","")))')
      TLS_DOMAIN=$(python3 -c 'import config;print(getattr(config, "TLS_DOMAIN", "www.google.com"))')
      if [ "$SECRET_COUNT" == "0" ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) You have no secrets."
        exit 4
      fi
      RemoveMultiLineUser
      SECRET=$(echo "$SECRET" | tr "'" '"')
      echo "$SECRET" >tempSecrets.json
      SECRET_ARY=()
      mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
      for user in "${SECRET_ARY[@]}"; do
        SECRET=$(jq --arg u "$user" -r '.[$u]' tempSecrets.json)
        s=$(python3 -c "print(\"ee\" + \"$SECRET\" + \"$TLS_DOMAIN\".encode().hex())")
        echo "$user: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s"
      done
      rm -f tempSecrets.json
      ;;
    2)
      read -r OPTION
      if [[ "$OPTION" == "y" ]]; then
        systemctl stop mtprotoproxy
        mv /opt/mtprotoproxy/config.py /tmp/config.py
        git pull
        mv /tmp/config.py /opt/mtprotoproxy/config.py
        pip3.8 install --upgrade cryptography uvloop
        systemctl start mtprotoproxy
        echo "Proxy updated."
      fi
      ;;
    3)
      read -r TAG
      if [ -n "$TAG" ]; then
        echo "" >>config.py
        TAGTEMP="AD_TAG = \"$TAG\""
        echo "$TAGTEMP" >>config.py
      else
        sed -i '/^AD_TAG/ d' config.py
      fi
      sed -i '/^$/d' config.py
      RestartService
      echo "Done"
      ;;
    4)
      read -r NEW_USR
      read -r SECRET
      if [ -z "$SECRET" ]; then
        SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
      fi
      SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
      if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The secret is not valid."
        exit 1
      fi
      SECRETS=$(python3 -c 'import config;print(getattr(config, "USERS","{}"))')
      SECRETS=$(echo "$SECRETS" | tr "'" '"')
      SECRETS="${SECRETS::-1}, \"$NEW_USR\":\"$SECRET\"}"
      sed -i "s/^USERS =.*/USERS = $SECRETS/" config.py
      RestartService
      echo "Done"
      ;;
    5)
      read -r USER_TO_REVOKE
      SECRET=$(python3 -c 'import config;print(getattr(config, "USERS",""))')
      SECRET_COUNT=$(python3 -c 'import config;print(len(getattr(config, "USERS","")))')
      if [ "$SECRET_COUNT" == "0" ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) You have no secrets."
        exit 4
      fi
      RemoveMultiLineUser
      SECRET=$(echo "$SECRET" | tr "'" '"')
      echo "$SECRET" >tempSecrets.json
      SECRET_ARY=()
      mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
      if ! [[ $USER_TO_REVOKE =~ $regex ]]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
        exit 1
      fi
      USER_TO_REVOKE=$((USER_TO_REVOKE - 1))
      if [ "$USER_TO_REVOKE" -lt 0 ] || [ "$USER_TO_REVOKE" -ge "${#SECRET_ARY[@]}" ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid number"
        exit 1
      fi
      KEY=${SECRET_ARY[$USER_TO_REVOKE]}
      SECRET=$(jq -r "del(.[\"$KEY\"])" tempSecrets.json)
      sed -i "s/^USERS =.*/USERS = $SECRET/" config.py
      rm -f tempSecrets.json
      RestartService
      echo "Done"
      ;;
    6)
      read -r USER_TO_LIMIT
      read -r LIMIT
      if ! [[ $USER_TO_LIMIT =~ $regex ]]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
        exit 1
      fi
      LIMIT=$((LIMIT * 8))
      SECRET=$(python3 -c 'import config;print(getattr(config, "USERS",""))')
      SECRET_COUNT=$(python3 -c 'import config;print(len(getattr(config, "USERS","")))')
      if [ "$SECRET_COUNT" == "0" ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) You have no secrets."
        exit 4
      fi
      RemoveMultiLineUser
      SECRET=$(echo "$SECRET" | tr "'" '"')
      echo "$SECRET" >tempSecrets.json
      SECRET_ARY=()
      mapfile -t SECRET_ARY < <(jq -r 'keys[]' tempSecrets.json)
      USER_TO_LIMIT=$((USER_TO_LIMIT - 1))
      if [ "$USER_TO_LIMIT" -lt 0 ] || [ "$USER_TO_LIMIT" -ge "${#SECRET_ARY[@]}" ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid number"
        exit 1
      fi
      KEY=${SECRET_ARY[$USER_TO_LIMIT]}
      LIMITER_CONFIG=$(python3 -c 'import config;print(getattr(config, "USER_MAX_TCP_CONNS","{}"))')
      LIMITER_CONFIG=$(echo "$LIMITER_CONFIG" | tr "'" '"')
      LIMITER_CONFIG="${LIMITER_CONFIG::-1}, \"$KEY\":$LIMIT}"
      sed -i "s/^USER_MAX_TCP_CONNS =.*/USER_MAX_TCP_CONNS = $LIMITER_CONFIG/" config.py
      echo "$KEY;$LIMIT" >> limits_bash.txt
      rm -f tempSecrets.json
      RestartService
      echo "Done"
      ;;
    7|8|9|10|11)
      echo "$(tput setaf 1)Not implemented$(tput sgr 0)"
      exit 1
      ;;
    *)
      echo "$(tput setaf 1)Invalid option$(tput sgr 0)"
      exit 1
      ;;
    esac
    exit 0
  fi
fi
PORT=443
SECRETS=""
SECRET_END_ARY=()
USERNAME_END_ARY=()
TAG=""
SECURE_MODE="MODES = { \"classic\": False, \"secure\": False, \"tls\": True }"
TLS_DOMAIN="www.cloudflare.com"
if [ $# -ge 2 ]; then
  PORT=$1
  shift
  while [ $# -gt 0 ]; do
    USERNAME_END_ARY+=("$1")
    SECRET_END_ARY+=("$2")
    SECRETTEMP="\"$1\":\"$2\""
    SECRETS+="$SECRETTEMP , "
    shift 2
  done
  SECRETS=${SECRETS::${#SECRETS}-2}
  TAG=$1
  SECURE_MODE="MODES = { \"classic\": $([ "$2" == "1" ] && echo "True" || echo "False"), \"secure\": $([ "$2" != "3" ] && echo "True" || echo "False"), \"tls\": True }"
  TLS_DOMAIN=$3
fi
if [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
  apt-get update
  apt-get -y install python3 python3-pip sed git curl jq ca-certificates
else
  echo "Your OS is not supported"
  exit 2
fi
timedatectl set-ntp on
pip3 install cryptography uvloop
cd /opt || exit 2
git clone https://github.com/alexbers/mtprotoproxy.git
cd mtprotoproxy || exit 2
chmod 0777 config.py
echo "PORT = $PORT
USERS = { $SECRETS }
USER_MAX_TCP_CONNS = {}
TLS_DOMAIN = \"$TLS_DOMAIN\"
$SECURE_MODE" >config.py
if [ -n "$TAG" ]; then
  echo "AD_TAG = \"$TAG\"" >>config.py
fi
echo "{}" >> limits_bash.txt
echo "{}" >> limits_date.json
echo "{}" >> limits_quota.json
cd /etc/systemd/system || exit 2
echo "[Unit]
Description = MTProto Proxy Service
After=network.target
[Service]
Type = simple
ExecStart = /usr/bin/python3 /opt/mtprotoproxy/mtprotoproxy.py
StartLimitBurst=0
[Install]
WantedBy = multi-user.target" >mtprotoproxy.service
systemctl daemon-reload
systemctl enable mtprotoproxy
systemctl start mtprotoproxy
PUBLIC_IP="$(curl https://api.ipify.org -sS)"
CURL_EXIT_STATUS=$?
[ $CURL_EXIT_STATUS -ne 0 ] && PUBLIC_IP="YOUR_IP"
COUNTER=0
for i in "${SECRET_END_ARY[@]}"; do
  s=$(python3 -c "print(\"ee\" + \"$i\" + \"$TLS_DOMAIN\".encode().hex())")
  echo "${USERNAME_END_ARY[$COUNTER]}: tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$s"
  COUNTER=$((COUNTER + 1))
done
