#!/usr/bin/env bash

auto_update=false
debug=false

for arg in "${@}"; do
  [ "${arg}" = "--auto-update" ] && auto_update=true
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

echo -e "  ${legible}Downloading DNSD...${reset}"

rm -rf /opt/dnsd &> "${log_redirects}"

mkdir -p /opt/dnsd/bin &> "${log_redirects}"

curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd.sh > /opt/dnsd/bin/dnsd.sh

chmod +x /opt/dnsd/bin/dnsd.sh &> "${log_redirects}"

echo -e "  ${legible}Installing DNSD...${reset}"

rm -rf /etc/systemd/system/dnsd.service &> "${log_redirects}"

systemctl daemon-reload &> "${log_redirects}"

tee /etc/systemd/system/dnsd.service &> /dev/null << EOF
[Unit]
Description=Maintain your systemd-resolved.
After=systemd-resolved.service

[Service]
Type=simple
ExecStart=/opt/dnsd/bin/dnsd.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload &> "${log_redirects}"

systemctl enable dnsd &> "${log_redirects}"
systemctl start dnsd &> "${log_redirects}"

if [ "${auto_update}" = true ]; then
  mkdir -p /opt/dnsd/bin &> "${log_redirects}"

  curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd_auto_update.sh > /opt/dnsd/bin/dnsd_auto_update.sh

  chmod +x /opt/dnsd/bin/dnsd_auto_update.sh &> "${log_redirects}"

  tee /etc/systemd/system/dnsd-auto-update.service &> /dev/null << EOF
[Unit]
Description=dnsd auto update.
After=dnsd.service

[Service]
Type=simple
ExecStart=/opt/dnsd/bin/dnsd_auto_update.sh
EOF

  tee /etc/systemd/system/dnsd-auto-update.timer &> /dev/null << EOF
[Unit]
Description=dnsd auto update.

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload &> "${log_redirects}"

  systemctl enable dnsd-auto-update.timer &> "${log_redirects}"
  systemctl start dnsd-auto-update.timer &> "${log_redirects}"
fi

echo -e "  ${legible}DNSD was successfully installed.${reset}"

echo ""
