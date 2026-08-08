#!/usr/bin/env bash

timeout 10 bash -c "while ! ping -c 1 1.1.1.1 &> /dev/null; do sleep 1; done"

echo "Checking for updates..."

current_version=$(cat /opt/dnsd/bin/dnsd.sh 2> /dev/null | sha256sum)
latest_version=$(curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd.sh 2> /dev/null | sha256sum)

if [ "${current_version}" != "${latest_version}" ]; then
  echo "Updating to the latest version..."

  curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd.sh > /opt/dnsd/bin/dnsd.sh-tmp
  curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/src/dnsd_auto_update.sh > /opt/dnsd/bin/dnsd_auto_update.sh-tmp

  chmod +x /opt/dnsd/bin/dnsd.sh-tmp
  chmod +x /opt/dnsd/bin/dnsd_auto_update.sh-tmp

  if cat /opt/dnsd/bin/dnsd.sh-tmp | bash -n &> /dev/null && cat /opt/dnsd/bin/dnsd_auto_update.sh-tmp | bash -n &> /dev/null; then
    mv /opt/dnsd/bin/dnsd.sh-tmp /opt/dnsd/bin/dnsd.sh
    mv /opt/dnsd/bin/dnsd_auto_update.sh-tmp /opt/dnsd/bin/dnsd_auto_update.sh

    echo "Updated successfully."

    systemctl restart dnsd &> /dev/null

    systemctl restart dnsd-auto-update &> /dev/null
    systemctl restart dnsd-auto-update.timer &> /dev/null
  else
    rm -rf /opt/dnsd/bin/dnsd.sh-tmp
    rm -rf /opt/dnsd/bin/dnsd_auto_update.sh-tmp

    echo "Update cancelled."
  fi
else
  echo "No updates found."
fi
