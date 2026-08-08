#!/usr/bin/env bash

timeout 10 bash -c "while ! ping -c 1 1.1.1.1 &> /dev/null; do sleep 1; done"

echo "Updating services..."

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

tee /etc/systemd/system/dnsd-update.service &> /dev/null << EOF
[Unit]
Description=DNSD update.
After=dnsd.service

[Service]
Type=simple
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

echo "Checking for updates..."

current_version=$(cat /opt/dnsd/bin/dnsd.sh 2> /dev/null | sha256sum)
latest_version=$(curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd.sh 2> /dev/null | sha256sum)

current_version_update=$(cat /opt/dnsd/bin/dnsd_update.sh 2> /dev/null | sha256sum)
latest_version_update=$(curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd_update.sh 2> /dev/null | sha256sum)

if [ "${current_version}" != "${latest_version}" ] || [ "${current_version_update}" != "${latest_version_update}" ]; then
  echo "Updating to the latest version..."

  curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd.sh > /opt/dnsd/bin/dnsd.sh-tmp
  curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd_update.sh > /opt/dnsd/bin/dnsd_update.sh-tmp

  chmod +x /opt/dnsd/bin/dnsd.sh-tmp
  chmod +x /opt/dnsd/bin/dnsd_update.sh-tmp

  if cat /opt/dnsd/bin/dnsd.sh-tmp | bash -n &> /dev/null && cat /opt/dnsd/bin/dnsd_update.sh-tmp | bash -n &> /dev/null; then
    mv /opt/dnsd/bin/dnsd.sh-tmp /opt/dnsd/bin/dnsd.sh
    mv /opt/dnsd/bin/dnsd_update.sh-tmp /opt/dnsd/bin/dnsd_update.sh

    echo "Updated successfully."

    systemctl restart dnsd &> /dev/null

    systemctl restart dnsd-update &> /dev/null
    systemctl restart dnsd-update.timer &> /dev/null
  else
    rm -rf /opt/dnsd/bin/dnsd.sh-tmp
    rm -rf /opt/dnsd/bin/dnsd_update.sh-tmp

    echo "Update cancelled."
  fi
else
  echo "No updates found."
fi
