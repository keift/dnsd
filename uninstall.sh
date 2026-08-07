#!/usr/bin/env bash

debug=false

for arg in "${@}"; do
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

  echo -e "  ${blue}Keift ${cyan}Uninstall DNSD ${version_text}${reset}"

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

  echo -e "  ${green}curl ${legible}-${yellow}fsSL ${cyan}https://raw.github.com/keift/dnsd/refs/heads/main/uninstall.sh ${legible}| ${green}sudo ${cyan}bash${reset}"

  echo ""

  exit 1
fi

echo -e "  ${legible}Uninstalling DNSD...${reset}"

if [ ! -d /opt/dnsd ]; then
  echo -e "  ${legible}DNSD already not installed.${reset}"

  echo ""

  exit 0
fi

rm -rf /opt/dnsd &> "${log_redirects}"

rm -rf /etc/systemd/system/dnsd.service &> "${log_redirects}"

systemctl daemon-reload &> "${log_redirects}"

systemctl disable dnsd &> "${log_redirects}"
systemctl stop dnsd &> "${log_redirects}"

tee /etc/systemd/resolved.conf &> /dev/null <<< ""

[ -f /run/systemd/resolve/stub-resolv.conf ] && ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &> "${log_redirects}"

systemctl restart systemd-resolved &> "${log_redirects}"

echo -e "  ${legible}DNSD has been successfully uninstalled.${reset}"

echo ""
