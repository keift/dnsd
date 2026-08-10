#!/usr/bin/env bash

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
    rpm-ostree install -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "apt" ]; then
    apt install -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "dnf" ]; then
    dnf install -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "pacman" ]; then
    pacman -S --noconfirm "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "zypper" ]; then
    zypper -n install "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "xbps" ]; then
    xbps-install -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "apk" ]; then
    apk add "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "emerge" ]; then
    emerge "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "slackpkg" ]; then
    slackpkg -batch=on -default_answer=y install "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "eopkg" ]; then
    eopkg install -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "opkg" ]; then
    opkg install "${package_name}" &> /dev/null
  else
    echo "Unsupported package manager."

    exit 1
  fi
}

uninstall_package() {
  local package_name="${1}"

  if [ "${package_manager}" = "rpm-ostree" ]; then
    rpm-ostree uninstall -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "apt" ]; then
    apt remove -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "dnf" ]; then
    dnf remove -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "pacman" ]; then
    pacman -R --noconfirm "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "zypper" ]; then
    zypper -n remove "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "xbps" ]; then
    xbps-remove -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "apk" ]; then
    apk del "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "emerge" ]; then
    emerge --unmerge "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "slackpkg" ]; then
    slackpkg -batch=on -default_answer=y remove "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "eopkg" ]; then
    eopkg remove -y "${package_name}" &> /dev/null
  elif [ "${package_manager}" = "opkg" ]; then
    opkg remove "${package_name}" &> /dev/null
  else
    echo "Unsupported package manager."

    exit 1
  fi
}

install_package curl

[ "${package_manager}" = "rpm-ostree" ] && rpm-ostree apply-live &> /dev/null

while ! curl -sI --max-time 10 https://raw.github.com &> /dev/null; do sleep 1; done

echo "Checking for updates..."

if ! curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd.sh > /opt/dnsd/bin/dnsd.sh-tmp 2> /dev/null; then
  rm -f /opt/dnsd/bin/dnsd.sh-tmp

  echo "Something went wrong."

  exit 1
fi

if ! curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd_update.sh > /opt/dnsd/bin/dnsd_update.sh-tmp 2> /dev/null; then
  rm -f /opt/dnsd/bin/dnsd_update.sh-tmp

  echo "Something went wrong."

  exit 1
fi

current_version=$(sha256sum /opt/dnsd/bin/dnsd.sh 2> /dev/null | cut -f1 -d " ")
latest_version=$(sha256sum /opt/dnsd/bin/dnsd.sh-tmp 2> /dev/null | cut -f1 -d " ")

current_version_update=$(sha256sum /opt/dnsd/bin/dnsd_update.sh 2> /dev/null | cut -f1 -d " ")
latest_version_update=$(sha256sum /opt/dnsd/bin/dnsd_update.sh-tmp 2> /dev/null | cut -f1 -d " ")

if [ "${current_version}" != "${latest_version}" ] || [ "${current_version_update}" != "${latest_version_update}" ]; then
  echo "Updating to the latest version..."

  chmod +x /opt/dnsd/bin/dnsd.sh-tmp &> /dev/null
  chmod +x /opt/dnsd/bin/dnsd_update.sh-tmp &> /dev/null

  if bash -n /opt/dnsd/bin/dnsd.sh-tmp &> /dev/null \
    && bash -n /opt/dnsd/bin/dnsd_update.sh-tmp &> /dev/null; then
    mv /opt/dnsd/bin/dnsd.sh-tmp /opt/dnsd/bin/dnsd.sh &> /dev/null
    mv /opt/dnsd/bin/dnsd_update.sh-tmp /opt/dnsd/bin/dnsd_update.sh &> /dev/null

    echo "Updated successfully."

    systemctl restart dnsd &> /dev/null

    systemctl restart dnsd-update &> /dev/null
    systemctl restart dnsd-update.timer &> /dev/null
  else
    rm -f /opt/dnsd/bin/dnsd.sh-tmp &> /dev/null
    rm -f /opt/dnsd/bin/dnsd_update.sh-tmp &> /dev/null

    echo "Update cancelled."
  fi
else
  rm -f /opt/dnsd/bin/dnsd.sh-tmp &> /dev/null
  rm -f /opt/dnsd/bin/dnsd_update.sh-tmp &> /dev/null

  echo "No updates found."
fi

tee /etc/systemd/system/dnsd.service &> /dev/null << EOF
[Unit]
Description=Maintain your systemd-resolved
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/dnsd/bin/dnsd.sh

[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/dnsd-update.service &> /dev/null << EOF
[Unit]
Description=DNSD update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/dnsd/bin/dnsd_update.sh
EOF

tee /etc/systemd/system/dnsd-update.timer &> /dev/null << EOF
[Unit]
Description=DNSD update

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
