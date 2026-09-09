#!/usr/bin/env bash

while ! curl -sI --max-time 10 https://raw.github.com &> /dev/null; do sleep 10; done

echo "Checking for updates..."

mkdir -p /opt/dnsd/tmp &> /dev/null

if ! curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd.sh > /opt/dnsd/tmp/dnsd.sh 2> /dev/null \
  || ! curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd_update.sh > /opt/dnsd/tmp/dnsd_update.sh 2> /dev/null; then
  rm -f /opt/dnsd/tmp/dnsd.sh &> /dev/null
  rm -f /opt/dnsd/tmp/dnsd_update.sh &> /dev/null

  echo "Something went wrong."

  exit 1
fi

current_version_dnsd=$(sha256sum /opt/dnsd/bin/dnsd.sh 2> /dev/null | cut -f 1 -d " ")
latest_version_dnsd=$(sha256sum /opt/dnsd/tmp/dnsd.sh 2> /dev/null | cut -f 1 -d " ")

current_version_dnsd_update=$(sha256sum /opt/dnsd/bin/dnsd_update.sh 2> /dev/null | cut -f 1 -d " ")
latest_version_dnsd_update=$(sha256sum /opt/dnsd/tmp/dnsd_update.sh 2> /dev/null | cut -f 1 -d " ")

if [ "${current_version_dnsd}" != "${latest_version_dnsd}" ] \
  || [ "${current_version_dnsd_update}" != "${latest_version_dnsd_update}" ]; then
  echo "Updating to the latest version..."

  chmod +x /opt/dnsd/tmp/dnsd.sh &> /dev/null
  chmod +x /opt/dnsd/tmp/dnsd_update.sh &> /dev/null

  if cat /opt/dnsd/tmp/dnsd.sh | grep -iq "#!/usr/bin/env bash" \
    && cat /opt/dnsd/tmp/dnsd_update.sh | grep -iq "#!/usr/bin/env bash" \
    && bash -n /opt/dnsd/tmp/dnsd.sh &> /dev/null \
    && bash -n /opt/dnsd/tmp/dnsd_update.sh &> /dev/null; then
    mkdir -p /opt/dnsd/bin &> /dev/null

    mv /opt/dnsd/tmp/dnsd.sh /opt/dnsd/bin/dnsd.sh &> /dev/null
    mv /opt/dnsd/tmp/dnsd_update.sh /opt/dnsd/bin/dnsd_update.sh &> /dev/null

    echo "Updated successfully."

    systemctl restart dnsd &> /dev/null

    systemctl restart dnsd-update &> /dev/null
    systemctl restart dnsd-update.timer &> /dev/null
  else
    rm -f /opt/dnsd/tmp/dnsd.sh &> /dev/null
    rm -f /opt/dnsd/tmp/dnsd_update.sh &> /dev/null

    echo "Something went wrong."
  fi
else
  rm -f /opt/dnsd/tmp/dnsd.sh &> /dev/null
  rm -f /opt/dnsd/tmp/dnsd_update.sh &> /dev/null

  echo "No updates found."
fi

tee /opt/dnsd/tmp/dnsd.service &> /dev/null << EOF
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

tee /opt/dnsd/tmp/dnsd-update.service &> /dev/null << EOF
[Unit]
Description=DNSD update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/dnsd/bin/dnsd_update.sh
EOF

tee /opt/dnsd/tmp/dnsd-update.timer &> /dev/null << EOF
[Unit]
Description=DNSD update

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

current_version_dnsd_service=$(sha256sum /etc/systemd/system/dnsd.service 2> /dev/null | cut -f 1 -d " ")
latest_version_dnsd_service=$(sha256sum /opt/dnsd/tmp/dnsd.service 2> /dev/null | cut -f 1 -d " ")

current_version_dnsd_update_service=$(sha256sum /etc/systemd/system/dnsd-update.service 2> /dev/null | cut -f 1 -d " ")
latest_version_dnsd_update_service=$(sha256sum /opt/dnsd/tmp/dnsd-update.service 2> /dev/null | cut -f 1 -d " ")

current_version_dnsd_timer_service=$(sha256sum /etc/systemd/system/dnsd-update.timer 2> /dev/null | cut -f 1 -d " ")
latest_version_dnsd_timer_service=$(sha256sum /opt/dnsd/tmp/dnsd-update.timer 2> /dev/null | cut -f 1 -d " ")

if [ "${current_version_dnsd_service}" != "${latest_version_dnsd_service}" ] \
  || [ "${current_version_dnsd_update_service}" != "${latest_version_dnsd_update_service}" ] \
  || [ "${current_version_dnsd_timer_service}" != "${latest_version_dnsd_timer_service}" ]; then
  mv /opt/dnsd/tmp/dnsd.service /etc/systemd/system/dnsd.service &> /dev/null
  mv /opt/dnsd/tmp/dnsd-update.service /etc/systemd/system/dnsd-update.service &> /dev/null
  mv /opt/dnsd/tmp/dnsd-update.timer /etc/systemd/system/dnsd-update.timer &> /dev/null

  systemctl daemon-reload &> /dev/null
else
  rm -f /opt/dnsd/tmp/dnsd.service &> /dev/null
  rm -f /opt/dnsd/tmp/dnsd-update.service &> /dev/null
  rm -f /opt/dnsd/tmp/dnsd-update.timer &> /dev/null
fi
