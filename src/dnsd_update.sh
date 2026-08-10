#!/usr/bin/env bash

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

    echo "Something went wrong."
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

systemctl daemon-reload &> /dev/null
