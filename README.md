# dnsd - maintain your systemd-resolved

This tool constantly checks your systemd-resolved. It always forces DNS-over-TLS. However, if DNS-over-TLS access is blocked on your network, it starts using the DNSCrypt protocol. But if that also fails, it fallsbacks to your local DNS.

## Installation

You can install it as follows.

```shell
curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/install.sh | sudo bash
```

## Uninstall

You can uninstall it as follows.

```shell
curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/uninstall.sh | sudo bash
```

## Parameters

Installation settings can be changed in the following ways.

> | Parameter   | Default | Description                                                           |
> | ----------- | ------- | --------------------------------------------------------------------- |
> | `--updates` | `false` | This parameter indicates that it needs to update itself continuously. |
>
> Example:
>
> ```shell
> curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/install.sh | sudo bash -s -- --updates
> ```
