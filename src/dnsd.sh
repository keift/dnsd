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

if ! command -v systemctl &> /dev/null; then
  echo "It only works on Systemd devices."

  exit 1
fi

install_package systemd-resolved

[ "${package_manager}" = "rpm-ostree" ] && rpm-ostree apply-live &> /dev/null

systemctl enable systemd-resolved &> /dev/null
systemctl start systemd-resolved &> /dev/null

chattr -i /etc/resolv.conf &> /dev/null

[ -f /run/systemd/resolve/stub-resolv.conf ] && ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &> /dev/null

mkdir -p /opt/dnsd/cache &> /dev/null

strategy=$(cat /opt/dnsd/cache/strategy 2> /dev/null || echo "none")

echo "DNSD started with the \"${strategy}\" strategy."

check() {
  if dig -p 853 +tls +tries=1 +time=10 @1.1.1.1 &> /dev/null; then
    local switch="dns_over_tls"
  else
    local switch="dnscrypt"
  fi

  if [ "${strategy}" = "dnscrypt" ] && (! dig -p 5300 +tries=1 +time=10 @127.0.0.1 &> /dev/null || ! dig -p 5300 +tries=1 +time=10 @::1 &> /dev/null); then
    systemctl restart dnscrypt-proxy &> /dev/null

    sleep 10

    if ! dig -p 5300 +tries=1 +time=10 @127.0.0.1 &> /dev/null || ! dig -p 5300 +tries=1 +time=10 @::1 &> /dev/null; then
      local switch="local"
    fi
  fi

  if ! dig -p 53 +tries=1 +time=10 @127.0.0.53 &> /dev/null || [ -z "$(dig -p 53 +tries=1 +time=10 +short @127.0.0.53)" ]; then
    systemctl restart systemd-resolved &> /dev/null

    sleep 10

    if ! dig -p 53 +tries=1 +time=10 @127.0.0.53 &> /dev/null || [ -z "$(dig -p 53 +tries=1 +time=10 +short @127.0.0.53)" ]; then
      local switch="local"
    fi
  fi

  if [ "${strategy}" = "${switch}" ]; then
    sleep 10

    check

    return 0
  fi

  echo "Switching to \"${switch}\" strategy..."

  if [ "${switch}" = "dns_over_tls" ]; then
    tee /etc/systemd/resolved.conf &> /dev/null << EOF
[Resolve]
DNS=1.1.1.1#one.one.one.one
DNS=2606:4700:4700::1111#one.one.one.one
DNS=1.0.0.1#one.one.one.one
DNS=2606:4700:4700::1001#one.one.one.one

Domains=~.
DNSOverTLS=yes
EOF

    systemctl restart systemd-resolved &> /dev/null

    uninstall_package dnscrypt-proxy

    [ "${package_manager}" = "rpm-ostree" ] && rpm-ostree apply-live &> /dev/null
  elif [ "${switch}" = "dnscrypt" ]; then
    tee /etc/systemd/resolved.conf &> /dev/null <<< ""

    systemctl restart systemd-resolved &> /dev/null

    install_package dnscrypt-proxy

    [ "${package_manager}" = "rpm-ostree" ] && rpm-ostree apply-live &> /dev/null

    systemctl enable dnscrypt-proxy &> /dev/null
    systemctl start dnscrypt-proxy &> /dev/null

    dnscrypt_configs=(
      "/etc/dnscrypt-proxy.toml"
      "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"

      "/usr/local/etc/dnscrypt-proxy.toml"
      "/usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml"

      "/opt/etc/dnscrypt-proxy.toml"
      "/opt/etc/dnscrypt-proxy/dnscrypt-proxy.toml"

      "/opt/dnscrypt-proxy/dnscrypt-proxy.toml"
    )

    for config in "${dnscrypt_configs[@]}"; do
      if [ -f "${config}" ]; then
        dnscrypt_config="${config}"

        break
      fi
    done

    if [ -z "${dnscrypt_config}" ]; then
      if [ -f "/usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml" ]; then
        mkdir -p /etc/dnscrypt-proxy &> /dev/null

        cp /usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.toml &> /dev/null

        dnscrypt_config="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
      else
        echo "\"dnscrypt-proxy\" config file was not found."
      fi
    fi

    mkdir -p /var/cache/dnscrypt-proxy &> /dev/null

    tee "${dnscrypt_config}" &> /dev/null << EOF
listen_addresses = ["127.0.0.1:5300", "[::1]:5300"]

[sources.public-resolvers]
urls = [
  "https://raw.github.com/dnscrypt/dnscrypt-resolvers/refs/heads/master/v3/public-resolvers.md",
  "https://raw.githack.com/dnscrypt/dnscrypt-resolvers/refs/heads/master/v3/public-resolvers.md",
  "https://cdn.jsdelivr.net/gh/dnscrypt/dnscrypt-resolvers/v3/public-resolvers.md",
  "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
]
minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
cache_file = "/var/cache/dnscrypt-proxy/public-resolvers.md"
EOF

    systemctl restart dnscrypt-proxy &> /dev/null

    tee /etc/systemd/resolved.conf &> /dev/null << EOF
[Resolve]
DNS=127.0.0.1:5300
DNS=[::1]:5300

Domains=~.
DNSOverTLS=no
EOF

    systemctl restart systemd-resolved &> /dev/null
  elif [ "${switch}" = "local" ]; then
    tee /etc/systemd/resolved.conf &> /dev/null <<< ""

    systemctl restart systemd-resolved &> /dev/null

    uninstall_package dnscrypt-proxy

    [ "${package_manager}" = "rpm-ostree" ] && rpm-ostree apply-live &> /dev/null
  fi

  strategy="${switch}"

  echo "${strategy}" > /opt/dnsd/cache/strategy

  echo "Successfully switched to \"${switch}\" strategy."

  sleep 10

  check
}

check
