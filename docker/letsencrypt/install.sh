#!/usr/bin/env bash

set -Eeuo pipefail

expected_root=/opt/dalae37/letsencrypt
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ $EUID -ne 0 ]]; then
    echo "Run this installer as root" >&2
    exit 1
fi

if [[ "$script_dir" != "$expected_root" ]]; then
    echo "Place this directory at $expected_root before installation" >&2
    exit 1
fi

required_files=(
    "$script_dir/compose.yaml"
    "$script_dir/scripts/renew.sh"
    "$script_dir/secret/cloudflare.api"
    "$script_dir/systemd/certbot-renew@.service"
    "$script_dir/systemd/certbot-renew@.timer"
)

if [[ ! -d "$script_dir/config" ]]; then
    echo "Required directory not found: $script_dir/config" >&2
    exit 1
fi

shopt -s nullglob
certbot_configs=("$script_dir"/config/*.let)

if [[ ${#certbot_configs[@]} -eq 0 ]]; then
    echo "No Certbot configuration found in $script_dir/config" >&2
    exit 1
fi

for certbot_config in "${certbot_configs[@]}"; do
    if [[ ! -f "$certbot_config" || -L "$certbot_config" ]]; then
        echo "Invalid Certbot configuration: $certbot_config" >&2
        exit 1
    fi
done

for required_file in "${required_files[@]}"; do
    if [[ ! -f "$required_file" ]]; then
        echo "Required file not found: $required_file" >&2
        exit 1
    fi
done

for required_command in docker flock systemctl; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "Required command is not installed: $required_command" >&2
        exit 1
    fi
done

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose is not installed" >&2
    exit 1
fi

install -d -m 0755 \
    "$script_dir/certs" \
    "$script_dir/work" \
    "$script_dir/logs"

chmod 0700 "$script_dir/secret"
chmod 0600 "$script_dir/secret/cloudflare.api"
chmod 0755 "$script_dir/config"
chmod 0644 "${certbot_configs[@]}"

install -m 0755 \
    "$script_dir/scripts/renew.sh" \
    /usr/local/sbin/certbot-renew

install -m 0644 \
    "$script_dir/systemd/certbot-renew@.service" \
    /etc/systemd/system/certbot-renew@.service

install -m 0644 \
    "$script_dir/systemd/certbot-renew@.timer" \
    /etc/systemd/system/certbot-renew@.timer

systemctl daemon-reload

echo "Certificate renewal service installed"
