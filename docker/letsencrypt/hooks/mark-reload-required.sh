#!/bin/sh

set -eu

if [ -z "${RENEWED_LINEAGE:-}" ]; then
    echo "RENEWED_LINEAGE is not set" >&2
    exit 1
fi

cert_name=${RENEWED_LINEAGE##*/}

case "$cert_name" in
    ""|*[!A-Za-z0-9._-]*)
        echo "Invalid certificate name: $cert_name" >&2
        exit 1
        ;;
esac

marker_dir=/var/lib/letsencrypt/reload-required

mkdir -p "$marker_dir"
touch "$marker_dir/$cert_name"

echo "Nginx reload requested for $cert_name"
