#!/usr/bin/env bash

updates=false
debug=false

for arg in "${@}"; do
  [ "${arg}" = "--updates" ] && updates=true
  [ "${arg}" = "--debug" ] && debug=true
done

log_redirects="/dev/null"

[ "${debug}" = true ] && log_redirects="/dev/stdout"

reset="\e[0m"
bold="\x1b[1m"
dim="\x1b[2m"
italic="\x1b[3m"
underline="\x1b[4m"
blink="\x1b[5m"
inverse="\x1b[7m"
hidden="\x1b[8m"
strikethrough="\x1b[9m"

legible="\e[0m"
black="\e[30m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
cyan="\e[36m"
white="\e[37m"
gray="\e[90m"

version="1.0"

last_commit_id=$(curl -s --max-time 10 https://api.github.com/repos/keift/dnsd/commits/main | grep -m 1 '"sha":' | cut -d '"' -f 4 | cut -c 1-7)

detect_system() {
  if command -v rpm-ostree &> /dev/null; then
    package_manager="rpm-ostree"
  elif command -v apt &> /dev/null; then
    package_manager="apt"
  elif command -v dnf &> /dev/null; then
    package_manager="dnf"
  elif command -v pacman &> /dev/null; then
    package_manager="pacman"
  elif command -v zypper &> /dev/null; then
    package_manager="zypper"
  elif command -v xbps-install &> /dev/null; then
    package_manager="xbps"
  elif command -v apk &> /dev/null; then
    package_manager="apk"
  elif command -v emerge &> /dev/null; then
    package_manager="emerge"
  elif command -v slackpkg &> /dev/null; then
    package_manager="slackpkg"
  elif command -v eopkg &> /dev/null; then
    package_manager="eopkg"
  elif command -v opkg &> /dev/null; then
    package_manager="opkg"
  else
    package_manager="unknown"
  fi
}

detect_system

install_package() {
  local package_name="${1}"

  if [ "${package_manager}" = "rpm-ostree" ]; then
    rpm-ostree install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apt" ]; then
    apt install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "dnf" ]; then
    dnf install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pacman" ]; then
    pacman -S --noconfirm "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "zypper" ]; then
    zypper -n install "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "xbps" ]; then
    xbps-install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apk" ]; then
    apk add "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "emerge" ]; then
    emerge "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "slackpkg" ]; then
    slackpkg -batch=on -default_answer=y install "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "eopkg" ]; then
    eopkg install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "opkg" ]; then
    opkg install "${package_name}" &> "${log_redirects}"
  else
    print_head

    echo -e "  ${red}Unsupported package manager.${reset}"

    echo ""

    exit 1
  fi
}

uninstall_package() {
  local package_name="${1}"

  if [ "${package_manager}" = "rpm-ostree" ]; then
    rpm-ostree uninstall -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apt" ]; then
    apt remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "dnf" ]; then
    dnf remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pacman" ]; then
    pacman -R --noconfirm "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "zypper" ]; then
    zypper -n remove "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "xbps" ]; then
    xbps-remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apk" ]; then
    apk del "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "emerge" ]; then
    emerge --unmerge "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "slackpkg" ]; then
    slackpkg -batch=on -default_answer=y remove "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "eopkg" ]; then
    eopkg remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "opkg" ]; then
    opkg remove "${package_name}" &> "${log_redirects}"
  else
    print_head

    echo -e "  ${red}Unsupported package manager.${reset}"

    echo ""

    exit 1
  fi
}

print_head() {
  clear

  echo ""

  if [ -n "${last_commit_id}" ]; then
    local version_text="${gray}v${version} (${last_commit_id})"
  else
    local version_text="${gray}v${version}"
  fi

  echo -e "  ${blue}Keift ${cyan}Install DNSD ${version_text}${reset}"

  echo ""
}

print_head

if ! command -v systemctl &> /dev/null; then
  print_head

  echo -e "  ${red}It only works on Systemd devices.${reset}"

  echo ""

  exit 1
fi

if [ "${EUID}" != "0" ]; then
  print_head

  echo -e "  ${red}Missing permissions. Try running it with the following command.${reset}"

  echo ""

  echo -e "  ${green}curl ${legible}-${yellow}fsSL ${cyan}https://raw.github.com/keift/dnsd/refs/heads/main/install.sh ${legible}| ${green}sudo ${cyan}bash${reset}"

  echo ""

  exit 1
fi

echo -e "  ${legible}Installing dependencies...${reset}"

! command -v dig &> /dev/null && install_package bind-tools
! command -v dig &> /dev/null && install_package bind-utils
! command -v dig &> /dev/null && install_package bind9-dnsutils
! command -v dig &> /dev/null && install_package bind

install_package curl
install_package systemd-resolved

[ "${package_manager}" = "rpm-ostree" ] && rpm-ostree apply-live &> "${log_redirects}"

echo -e "  ${legible}Downloading DNSD...${reset}"

rm -rf /opt/dnsd &> "${log_redirects}"

rm -f /etc/systemd/system/dnsd.service &> "${log_redirects}"

rm -f /etc/systemd/system/dnsd-update.service &> "${log_redirects}"
rm -f /etc/systemd/system/dnsd-update.timer &> "${log_redirects}"

systemctl disable dnsd &> "${log_redirects}"
systemctl stop dnsd &> "${log_redirects}"

systemctl disable dnsd-update &> "${log_redirects}"
systemctl stop dnsd-update &> "${log_redirects}"

systemctl disable dnsd-update.timer &> "${log_redirects}"
systemctl stop dnsd-update.timer &> "${log_redirects}"

mkdir -p /opt/dnsd/bin &> "${log_redirects}"

curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd.sh > /opt/dnsd/bin/dnsd.sh

chmod +x /opt/dnsd/bin/dnsd.sh &> "${log_redirects}"

echo -e "  ${legible}Installing DNSD...${reset}"

tee /etc/systemd/system/dnsd.service &> /dev/null << EOF
[Unit]
Description=Maintain your systemd-resolved.
After=network-online.target

[Service]
Type=simple
ExecStart=/opt/dnsd/bin/dnsd.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl enable dnsd &> "${log_redirects}"
systemctl start dnsd &> "${log_redirects}"

if [ "${updates}" = true ]; then
  curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd_update.sh > /opt/dnsd/bin/dnsd_update.sh

  chmod +x /opt/dnsd/bin/dnsd_update.sh &> "${log_redirects}"

  tee /etc/systemd/system/dnsd-update.service &> /dev/null << EOF
[Unit]
Description=DNSD update.
After=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/dnsd/bin/dnsd_update.sh
EOF

  tee /etc/systemd/system/dnsd-update.timer &> /dev/null << EOF
[Unit]
Description=DNSD update.

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl enable dnsd-update &> "${log_redirects}"
  systemctl start dnsd-update &> "${log_redirects}"

  systemctl enable dnsd-update.timer &> "${log_redirects}"
  systemctl start dnsd-update.timer &> "${log_redirects}"
fi

echo -e "  ${legible}DNSD was successfully installed.${reset}"

echo ""
