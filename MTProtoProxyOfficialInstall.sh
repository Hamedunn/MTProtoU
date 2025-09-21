#!/bin/bash
regex='^[0-9]+$'
function GetRandomPort() {
  if ! [ "$INSTALLED_LSOF" == true ]; then
    echo "Installing lsof package. Please wait."
    if [[ $distro =~ "CentOS" ]]; then
      yum -y -q install lsof
    elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
      apt-get -y install lsof >/dev/null
    fi
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
function GenerateService() {
  local ARGS_STR="-u nobody -H $PORT"
  for i in "${SECRET_ARY[@]}"; do
    ARGS_STR+=" -S $i"
  done
  if [ -n "$TAG" ]; then
    ARGS_STR+=" -P $TAG "
  fi
  if [ -n "$TLS_DOMAIN" ]; then
    ARGS_STR+=" -D $TLS_DOMAIN "
  fi
  if [ "$HAVE_NAT" == "y" ]; then
    ARGS_STR+=" --nat-info $PRIVATE_IP:$PUBLIC_IP "
  fi
  NEW_CORE=$((CPU_CORES - 1))
  ARGS_STR+=" -M $NEW_CORE $CUSTOM_ARGS --aes-pwd proxy-secret proxy-multi.conf"
  SERVICE_STR="[Unit]
Description=MTProxy
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt/MTProxy/objs/bin
ExecStart=/opt/MTProxy/objs/bin/mtproto-proxy $ARGS_STR
Restart=on-failure
StartLimitBurst=0
[Install]
WantedBy=multi-user.target"
}
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root"
  exit 1
fi
if [ $# -ge 1 ]; then
  OPTION=$1
  case $OPTION in
  1)
    PUBLIC_IP="$(curl https://api.ipify.org -sS)"
    CURL_EXIT_STATUS=$?
    if [ $CURL_EXIT_STATUS -ne 0 ]; then
      PUBLIC_IP="YOUR_IP"
    fi
    source /opt/MTProxy/objs/bin/mtconfig.conf
    HEX_DOMAIN=$(printf "%s" "$TLS_DOMAIN" | xxd -pu)
    HEX_DOMAIN="$(echo $HEX_DOMAIN | tr '[A-Z]' '[a-z]')"
    for i in "${SECRET_ARY[@]}"; do
      if [ -z "$TLS_DOMAIN" ]; then
        echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$i"
      else
        echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=ee$i$HEX_DOMAIN"
      fi
    done
    exit 0
    ;;
  2|3|4|5|6|7|8|9|10)
    source /opt/MTProxy/objs/bin/mtconfig.conf
    case $OPTION in
    2)
      read -r TAG
      cd /etc/systemd/system || exit 2
      systemctl stop MTProxy
      GenerateService
      echo "$SERVICE_STR" >MTProxy.service
      systemctl daemon-reload
      systemctl start MTProxy
      cd /opt/MTProxy/objs/bin/ || exit 2
      sed -i "s/^TAG=.*/TAG=\"$TAG\"/" mtconfig.conf
      echo "Done"
      ;;
    3)
      if [ "${#SECRET_ARY[@]}" -ge 16 ]; then
        echo "$(tput setaf 1)Error$(tput sgr 0) You cannot have more than 16 secrets"
        exit 1
      fi
      read -r SECRET
      SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
      if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
        SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
      fi
      SECRET_ARY+=("$SECRET")
      cd /etc/systemd/system || exit 2
      systemctl stop MTProxy
      GenerateService
      echo "$SERVICE_STR" >MTProxy.service
      systemctl daemon-reload
      systemctl start MTProxy
      cd /opt/MTProxy/objs/bin/ || exit 2
      SECRET_ARY_STR=${SECRET_ARY[*]}
      sed -i "s/^SECRET_ARY=.*/SECRET_ARY=($SECRET_ARY_STR)/" mtconfig.conf
      echo "Done"
      PUBLIC_IP="$(curl https://api.ipify.org -sS)"
      CURL_EXIT_STATUS=$?
      if [ $CURL_EXIT_STATUS -ne 0 ]; then
        PUBLIC_IP="YOUR_IP"
      fi
      echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$SECRET"
      ;;
    4)
      NUMBER_OF_SECRETS=${#SECRET_ARY[@]}
      if [ "$NUMBER_OF_SECRETS" -le 1 ]; then
        echo "Cannot remove the last secret."
        exit 1
      fi
      read -r USER_TO_REVOKE
      if ! [[ $USER_TO_REVOKE =~ $regex ]]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
        exit 1
      fi
      USER_TO_REVOKE1=$((USER_TO_REVOKE - 1))
      if [ "$USER_TO_REVOKE" -lt 1 ] || [ "$USER_TO_REVOKE" -gt "$NUMBER_OF_SECRETS" ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid number"
        exit 1
      fi
      SECRET_ARY=("${SECRET_ARY[@]:0:$USER_TO_REVOKE1}" "${SECRET_ARY[@]:$USER_TO_REVOKE}")
      cd /etc/systemd/system || exit 2
      systemctl stop MTProxy
      GenerateService
      echo "$SERVICE_STR" >MTProxy.service
      systemctl daemon-reload
      systemctl start MTProxy
      cd /opt/MTProxy/objs/bin/ || exit 2
      SECRET_ARY_STR=${SECRET_ARY[*]}
      sed -i "s/^SECRET_ARY=.*/SECRET_ARY=($SECRET_ARY_STR)/" mtconfig.conf
      echo "Done"
      ;;
    5)
      read -r CPU_CORES
      if ! [[ $CPU_CORES =~ $regex ]]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
        exit 1
      fi
      if [ "$CPU_CORES" -lt 1 ]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) Enter number more than 1."
        exit 1
      fi
      if [ "$CPU_CORES" -gt 16 ]; then
        echo "$(tput setaf 3)Warning:$(tput sgr 0) Values more than 16 can cause problems."
      fi
      cd /etc/systemd/system || exit 2
      systemctl stop MTProxy
      GenerateService
      echo "$SERVICE_STR" >MTProxy.service
      systemctl daemon-reload
      systemctl start MTProxy
      cd /opt/MTProxy/objs/bin/ || exit 2
      sed -i "s/^CPU_CORES=.*/CPU_CORES=$CPU_CORES/" mtconfig.conf
      echo "Done"
      ;;
    6)
      read -r HAVE_NAT
      if [[ "$HAVE_NAT" == "y" ]]; then
        read -r PUBLIC_IP
        read -r PRIVATE_IP
      fi
      cd /opt/MTProxy/objs/bin/ || exit 2
      sed -i "s/^HAVE_NAT=.*/HAVE_NAT=\"$HAVE_NAT\"/" mtconfig.conf
      sed -i "s/^PUBLIC_IP=.*/PUBLIC_IP=\"$PUBLIC_IP\"/" mtconfig.conf
      sed -i "s/^PRIVATE_IP=.*/PRIVATE_IP=\"$PRIVATE_IP\"/" mtconfig.conf
      cd /etc/systemd/system || exit 2
      systemctl stop MTProxy
      GenerateService
      echo "$SERVICE_STR" >MTProxy.service
      systemctl daemon-reload
      systemctl start MTProxy
      echo "Done"
      ;;
    7)
      read -r CUSTOM_ARGS
      cd /etc/systemd/system || exit 2
      systemctl stop MTProxy
      GenerateService
      echo "$SERVICE_STR" >MTProxy.service
      systemctl daemon-reload
      systemctl start MTProxy
      cd /opt/MTProxy/objs/bin/ || exit 2
      sed -i "s/^CUSTOM_ARGS=.*/CUSTOM_ARGS=\"$CUSTOM_ARGS\"/" mtconfig.conf
      echo "Done"
      ;;
    8)
      source /opt/MTProxy/objs/bin/mtconfig.conf
      if [[ $distro =~ "CentOS" ]]; then
        echo "firewall-cmd --zone=public --add-port=$PORT/tcp"
        echo "firewall-cmd --runtime-to-permanent"
      elif [[ $distro =~ "Ubuntu" ]]; then
        echo "ufw allow $PORT/tcp"
      elif [[ $distro =~ "Debian" ]]; then
        echo "iptables -A INPUT -p tcp --dport $PORT --jump ACCEPT"
        echo "iptables-save > /etc/iptables/rules.v4"
      fi
      read -r OPTION
      if [[ "$OPTION" == "y" ]]; then
        if [[ $distro =~ "CentOS" ]]; then
          firewall-cmd --zone=public --add-port="$PORT"/tcp
          firewall-cmd --runtime-to-permanent
        elif [[ $distro =~ "Ubuntu" ]]; then
          ufw allow "$PORT"/tcp
        elif [[ $distro =~ "Debian" ]]; then
          iptables -A INPUT -p tcp --dport "$PORT" --jump ACCEPT
          iptables-save >/etc/iptables/rules.v4
        fi
      fi
      ;;
    9)
      systemctl stop MTProxy
      systemctl disable MTProxy
      rm -rf /opt/MTProxy /etc/systemd/system/MTProxy.service
      systemctl daemon-reload
      if [[ $distro =~ "CentOS" ]]; then
        firewall-cmd --remove-port="$PORT"/tcp
        firewall-cmd --runtime-to-permanent
      elif [[ $distro =~ "Ubuntu" ]]; then
        ufw delete allow "$PORT"/tcp
      elif [[ $distro =~ "Debian" ]]; then
        iptables -D INPUT -p tcp --dport "$PORT" --jump ACCEPT
        iptables-save >/etc/iptables/rules.v4
      fi
      echo "Done"
      ;;
    10)
      echo "MTProtoInstaller script by Hirbod Behnam"
      echo "Source at https://github.com/TelegramMessenger/MTProxy"
      echo "Github repo of script: https://github.com/HirbodBehnam/MTProtoProxyInstaller"
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
SECRET_ARY=()
TAG=""
CPU_CORES=$(nproc --all)
ENABLE_UPDATER="y"
TLS_DOMAIN="www.cloudflare.com"
HAVE_NAT="n"
PUBLIC_IP=""
PRIVATE_IP=""
CUSTOM_ARGS=""
if [ $# -ge 2 ]; then
  while [ $# -gt 0 ]; do
    case $1 in
      -p|--port) PORT="$2"; shift 2 ;;
      -s|--secret) SECRET_ARY+=("$2"); shift 2 ;;
      -t|--tag) TAG="$2"; shift 2 ;;
      --workers) CPU_CORES="$2"; shift 2 ;;
      --disable-updater) ENABLE_UPDATER="n"; shift ;;
      --tls) TLS_DOMAIN="$2"; shift 2 ;;
      --nat-info) IFS=':' read PRIVATE_IP PUBLIC_IP <<< "$2"; HAVE_NAT="y"; shift 2 ;;
      --custom-args) CUSTOM_ARGS="$2"; shift 2 ;;
      --no-bbr|--no-nat) shift ;;
      *) shift ;;
    esac
  done
else
  if [ "$PORT" == "-1" ]; then
    GetRandomPort
  fi
  while true; do
    read -r SECRET
    if [ -z "$SECRET" ]; then
      SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
    fi
    SECRET="$(echo $SECRET | tr '[A-Z]' '[a-z]')"
    if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
      echo "$(tput setaf 1)Error:$(tput sgr 0) Enter hexadecimal characters and secret must be 32 characters."
      exit 1
    fi
    SECRET_ARY+=("$SECRET")
    read -r OPTION
    if [[ "$OPTION" != "y" ]]; then break; fi
  done
  read -r OPTION
  if [[ "$OPTION" == "y" ]]; then
    read -r TAG
  fi
  read -r CPU_CORES
  if ! [[ $CPU_CORES =~ $regex ]]; then
    echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
    exit 1
  fi
  if [ "$CPU_CORES" -lt 1 ]; then
    echo "$(tput setaf 1)Error:$(tput sgr 0) Enter number more than 1."
    exit 1
  fi
  read -r ENABLE_UPDATER
  read -r TLS_DOMAIN
  read -r HAVE_NAT
  if [[ "$HAVE_NAT" == "y" ]]; then
    PUBLIC_IP="$(curl https://api.ipify.org -sS)"
    read -r PUBLIC_IP
    IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | head -1)
    read -r PRIVATE_IP
  fi
  read -r CUSTOM_ARGS
fi
if [[ $distro =~ "CentOS" ]]; then
  yum -y install epel-release
  yum -y install openssl-devel zlib-devel curl ca-certificates sed cronie vim-common
  yum -y groupinstall "Development Tools"
elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
  apt-get update
  apt-get -y install git curl build-essential libssl-dev zlib1g-dev sed cron ca-certificates vim-common
fi
timedatectl set-ntp on
cd /opt || exit 2
git clone -b gcc10 https://github.com/krepver/MTProxy.git
cd MTProxy || exit 2
make
BUILD_STATUS=$?
if [ $BUILD_STATUS -ne 0 ]; then
  echo "$(tput setaf 1)Error:$(tput sgr 0) Build failed with exit code $BUILD_STATUS"
  rm -rf /opt/MTProxy
  exit 3
fi
cd objs/bin || exit 2
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
echo "PORT=$PORT" >mtconfig.conf
echo "CPU_CORES=$CPU_CORES" >>mtconfig.conf
echo "SECRET_ARY=(${SECRET_ARY[*]})" >>mtconfig.conf
echo "TAG=\"$TAG\"" >>mtconfig.conf
echo "CUSTOM_ARGS=\"$CUSTOM_ARGS\"" >>mtconfig.conf
echo "TLS_DOMAIN=\"$TLS_DOMAIN\"" >>mtconfig.conf
echo "HAVE_NAT=\"$HAVE_NAT\"" >>mtconfig.conf
echo "PUBLIC_IP=\"$PUBLIC_IP\"" >>mtconfig.conf
echo "PRIVATE_IP=\"$PRIVATE_IP\"" >>mtconfig.conf
cd /etc/systemd/system || exit 2
GenerateService
echo "$SERVICE_STR" >MTProxy.service
systemctl daemon-reload
systemctl start MTProxy
systemctl enable MTProxy
if [ "$ENABLE_UPDATER" = "y" ]; then
  echo '#!/bin/bash
systemctl stop MTProxy
cd /opt/MTProxy/objs/bin
curl -s https://core.telegram.org/getProxySecret -o proxy-secret1
STATUS_SECRET=$?
if [ $STATUS_SECRET -eq 0 ]; then
  cp proxy-secret1 proxy-secret
fi
rm proxy-secret1
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf1
STATUS_CONF=$?
if [ $STATUS_CONF -eq 0 ]; then
  cp proxy-multi.conf1 proxy-multi.conf
fi
rm proxy-multi.conf1
systemctl start MTProxy
echo "Updater runned at $(date). Exit codes of getProxySecret and getProxyConfig are $STATUS_SECRET and $STATUS_CONF" >> updater.log' >/opt/MTProxy/objs/bin/updater.sh
  echo "0 0 * * * root cd /opt/MTProxy/objs/bin && bash updater.sh" >>/etc/crontab
  if [[ $distro =~ "CentOS" ]]; then
    systemctl restart crond
  elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
    systemctl restart cron
  fi
fi
PUBLIC_IP="$(curl https://api.ipify.org -sS)"
CURL_EXIT_STATUS=$?
[ $CURL_EXIT_STATUS -ne 0 ] && PUBLIC_IP="YOUR_IP"
HEX_DOMAIN=$(printf "%s" "$TLS_DOMAIN" | xxd -pu)
HEX_DOMAIN="$(echo $HEX_DOMAIN | tr '[A-Z]' '[a-z]')"
for i in "${SECRET_ARY[@]}"; do
  if [ -z "$TLS_DOMAIN" ]; then
    echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=dd$i"
  else
    echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=ee$i$HEX_DOMAIN"
  fi
done
