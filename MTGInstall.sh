#!/bin/bash
regex='^[0-9]+$'
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root"
  exit 1
fi
distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
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
function GetArch() {
  arch=$(uname -m)
  case $arch in
  "i386" | "i686") ;;
  "x86_64") arch=2 ;;
  *)
    if [[ "$arch" =~ "armv" ]]; then
      arch=${arch:4:1}
      if [ "$arch" -gt 7 ]; then
        arch=4
      else
        arch=3
      fi
    else
      arch=0
    fi
    ;;
  esac
  if [ "$arch" == "0" ]; then
    arch=1
    echo "Cannot automatically determine architecture."
  fi
  read -r arch
  case $arch in
  1) arch="386" ;;
  2) arch="amd64" ;;
  3) arch="arm" ;;
  4) arch="arm64" ;;
  *) echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid option"; exit 1 ;;
  esac
}
function DownloadProxy() {
  local url="https://github.com/9seconds/mtg/releases/download/v1.0.10/mtg-linux-$arch"
  wget -O mtg "$url"
  chmod +x mtg
  mv mtg /usr/bin
}
function ParseService() {
  PORT=$(awk '/^Environment=MTG_BIND/ {split($1,a,":"); print(a[2])}' /etc/systemd/system/mtg.service)
  SECRET=$(grep "ExecStart=/usr/bin/mtg" /etc/systemd/system/mtg.service | cut -d\  -f3)
}
function RemoveTrailingSpaces() {
  sed -i 's/ *$//' /etc/systemd/system/mtg.service
}
function GetLink() {
  ParseService
  PUBLIC_IP="$(curl https://api.ipify.org -sS)"
  CURL_EXIT_STATUS=$?
  [ $CURL_EXIT_STATUS -ne 0 ] && PUBLIC_IP="YOUR_IP"
  echo "tg://proxy?server=$PUBLIC_IP&port=$PORT&secret=$SECRET"
}
if [ -f "/usr/bin/mtg" ]; then
  if [ $# -ge 1 ]; then
    OPTION=$1
    case $OPTION in
    1) GetLink ;;
    2)
      read -r arch
      case $arch in
      1) arch="386" ;;
      2) arch="amd64" ;;
      3) arch="arm" ;;
      4) arch="arm64" ;;
      *) echo "$(tput setaf 1)Error:$(tput sgr 0) Invalid option"; exit 1 ;;
      esac
      DownloadProxy
      systemctl restart mtg
      echo "Done"
      ;;
    3)
      read -r TAG
      RemoveTrailingSpaces
      WORDS_EXE_LINE=$(grep "ExecStart=/usr/bin/mtg" /etc/systemd/system/mtg.service | wc -w)
      for (( ; WORDS_EXE_LINE>3; WORDS_EXE_LINE-- )); do
        sed -i "/ExecStart=\/usr\/bin\/mtg/s/\w*$//" /etc/systemd/system/mtg.service
      done
      RemoveTrailingSpaces
      sed -i "/ExecStart=\/usr\/bin\/mtg/s/$/ $TAG/" /etc/systemd/system/mtg.service
      systemctl daemon-reload
      systemctl restart mtg
      echo "Done"
      ;;
    4)
      read -r SECRET
      read -r PROXY_MODE
      read -r TLS_DOMAIN
      if [ -z "$SECRET" ]; then
        SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
      fi
      SECRET=$(echo "$SECRET" | tr '[A-Z]' '[a-z]')
      if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
        echo "$(tput setaf 1)Error:$(tput sgr 0) Enter hexadecimal characters and secret must be 32 characters."
        exit 1
      fi
      if [[ "$PROXY_MODE" == "2" ]]; then
        SECRET="dd$SECRET"
      elif [[ "$PROXY_MODE" == "3" ]]; then
        TLS_DOMAIN=$(hexdump -v -e ' /1 "%02x"' <<< "$TLS_DOMAIN")
        SECRET="ee$SECRET$TLS_DOMAIN"
      fi
      SECRET_OLD=$(grep "ExecStart=/usr/bin/mtg" /etc/systemd/system/mtg.service | cut -d\  -f3)
      sed -i "s|$SECRET_OLD|$SECRET|" /etc/systemd/system/mtg.service
      systemctl daemon-reload
      systemctl restart mtg
      GetLink
      ;;
    5)
      ParseService
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
    6)
      read -r OPTION
      if [[ "$OPTION" == "y" ]]; then
        ParseService
        systemctl stop mtg
        systemctl disable mtg
        rm -f /etc/systemd/system/mtg.service /usr/bin/mtg
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
      fi
      ;;
    7)
      echo "MTProtoInstaller script by Hirbod Behnam"
      echo "Source at https://github.com/9seconds/mtg"
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
SECRET=""
TAG=""
TLS_DOMAIN=""
PROXY_MODE="3"
if [ $# -ge 1 ]; then
  PORT=$1
  if [ $# -ge 2 ]; then
    SECRET=$2
    if [ $# -ge 3 ]; then
      TAG=$3
      if [ $# -ge 4 ]; then
        PROXY_MODE=$4
        TLS_DOMAIN=$5
      fi
    fi
  fi
fi
if [[ $PORT == "-1" ]]; then
  GetRandomPort
fi
if ! [[ $PORT =~ $regex ]]; then
  echo "$(tput setaf 1)Error:$(tput sgr 0) The input is not a valid number"
  exit 1
fi
if [ "$PORT" -gt 65535 ]; then
  echo "$(tput setaf 1)Error:$(tput sgr 0): Number must be less than 65536"
  exit 1
fi
if [ -z "$SECRET" ]; then
  SECRET="$(hexdump -vn "16" -e ' /1 "%02x"' /dev/urandom)"
fi
SECRET=$(echo "$SECRET" | tr '[A-Z]' '[a-z]')
if ! [[ $SECRET =~ ^[0-9a-f]{32}$ ]]; then
  echo "$(tput setaf 1)Error:$(tput sgr 0) Enter hexadecimal characters and secret must be 32 characters."
  exit 1
fi
if [[ "$PROXY_MODE" == "2" ]]; then
  SECRET="dd$SECRET"
elif [[ "$PROXY_MODE" == "3" ]]; then
  TLS_DOMAIN=$(hexdump -v -e ' /1 "%02x"' <<< "$TLS_DOMAIN")
  SECRET="ee$SECRET$TLS_DOMAIN"
fi
if [[ $distro =~ "CentOS" ]]; then
  yum -y install epel-release
  yum -y install ca-certificates sed grep wget
elif [[ $distro =~ "Ubuntu" ]] || [[ $distro =~ "Debian" ]]; then
  apt-get update
  apt-get -y install ca-certificates sed grep wget
fi
GetArch
DownloadProxy
echo "[Unit]
Description=MTG Proxy Service
After=network-online.target
Wants=network-online.target
[Service]
Environment=MTG_BIND=0.0.0.0:$PORT
Type=simple
User=root
Group=root
ExecStart=/usr/bin/mtg run $SECRET $TAG
[Install]
WantedBy=multi-user.target" >/etc/systemd/system/mtg.service
systemctl daemon-reload
systemctl start mtg
systemctl enable mtg
GetLink
