#!/usr/bin/env bash

set -Eeuo pipefail
export LC_ALL=C

usage() {
    echo "Usage: $0 <fqdn> [--dry-run]" >&2
}

fqdn=${1:-}
mode=${2:-}

if [[ $# -gt 2 ]]; then
    usage
    exit 2
fi

if [[ -n "$mode" && "$mode" != "--dry-run" ]]; then
    usage
    exit 2
fi

if [[ ! "$fqdn" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.dalae37\.com$ ]]; then
    echo "Invalid FQDN: $fqdn" >&2
    usage
    exit 2
fi

letsencrypt_root=/opt/dalae37/letsencrypt
cert_name=$fqdn
nginx_service="web-${fqdn//./-}"

certbot_compose="$letsencrypt_root/compose.yaml"
certbot_request_config="$letsencrypt_root/config/$fqdn.let"
marker_dir="$letsencrypt_root/work/reload-required"
lock_file="$letsencrypt_root/work/renew.lock"

for required_file in "$certbot_compose" "$certbot_request_config"; do
    if [[ ! -f "$required_file" || -L "$required_file" ]]; then
        echo "Required regular file not found: $required_file" >&2
        exit 1
    fi
done

trim() {
    local value=$1

    value=${value#"${value%%[![:space:]]*}"}
    value=${value%"${value##*[![:space:]]}"}

    printf '%s' "$value"
}

configured_domains=
configured_cert_name=
seen_domains=0
seen_cert_name=0
line_no=0

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    ((++line_no))

    raw_line=${raw_line%$'\r'}
    if (( line_no == 1 )); then
        raw_line=${raw_line#$'\xEF\xBB\xBF'}
    fi

    config_line=$(trim "$raw_line")
    if [[ -z "$config_line" || "$config_line" == \#* ]]; then
        continue
    fi

    if [[ "$config_line" != *=* ]]; then
        continue
    fi

    key=$(trim "${config_line%%=*}")
    value=$(trim "${config_line#*=}")

    case "$key" in
        domains)
            if (( seen_domains )); then
                echo "Duplicate domains setting at $certbot_request_config:$line_no" >&2
                exit 1
            fi
            configured_domains=$value
            seen_domains=1
            ;;
        cert-name)
            if (( seen_cert_name )); then
                echo "Duplicate cert-name setting at $certbot_request_config:$line_no" >&2
                exit 1
            fi
            configured_cert_name=$value
            seen_cert_name=1
            ;;
    esac
done < "$certbot_request_config"

if (( ! seen_domains || ! seen_cert_name )); then
    echo "domains and cert-name are required in $certbot_request_config" >&2
    exit 1
fi

if [[ "$configured_domains" != "$fqdn" || "$configured_cert_name" != "$fqdn" ]]; then
    echo "domains and cert-name must match $fqdn in $certbot_request_config" >&2
    exit 1
fi

marker_file="$marker_dir/$cert_name"

mkdir -p "$marker_dir"

exec 9>"$lock_file"
lock_acquired=0

for (( attempt = 1; attempt <= 60; attempt++ )); do
    if flock -n 9; then
        lock_acquired=1
        break
    fi

    sleep 10
done

if (( ! lock_acquired )); then
    echo "Timed out waiting for another certificate renewal" >&2
    exit 1
fi

reload_if_required() {
    local -a web_containers
    local web_container

    if [[ ! -f "$marker_file" ]]; then
        return 0
    fi

    echo "Applying renewed certificate for $cert_name"

    mapfile -t web_containers < <(
        docker ps \
            --filter "status=running" \
            --filter "label=com.docker.compose.service=$nginx_service" \
            --format '{{.ID}}'
    )

    if [[ ${#web_containers[@]} -ne 1 ]]; then
        echo "Expected one running $nginx_service container, found ${#web_containers[@]}" >&2
        return 1
    fi

    web_container=${web_containers[0]}

    if ! docker exec "$web_container" nginx -t; then
        echo "Nginx configuration validation failed for $cert_name" >&2
        return 1
    fi

    if ! docker exec "$web_container" nginx -s reload; then
        echo "Nginx reload failed for $cert_name" >&2
        return 1
    fi

    rm -f -- "$marker_file"
    echo "Nginx reloaded for $cert_name"
}

# Retry a reload left pending by an earlier failed run.
if ! reload_if_required; then
    echo "The pending Nginx reload will be retried after certificate renewal" >&2
fi

certbot_args=(
    renew
    --quiet
    --cert-name "$cert_name"
    --deploy-hook "/bin/sh /etc/certbot/hooks/mark-reload-required.sh"
)

if [[ "$mode" == "--dry-run" ]]; then
    certbot_args+=(--dry-run --run-deploy-hooks)
fi

docker compose -f "$certbot_compose" run --rm --no-deps -T certbot "${certbot_args[@]}"

# The deploy hook creates this marker only after a successful renewal.
reload_if_required
