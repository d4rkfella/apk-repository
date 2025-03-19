#!/bin/env bash

set -euo pipefail

OUTPUT_FILE="/etc/ssl/certs/bundled/combined-ca-certificates.crt"
CERTS_DIR="/etc/ssl/certs"
FINGERPRINTS_FILE=$(mktemp)

mkdir -p "$(dirname "$OUTPUT_FILE")"

> "$OUTPUT_FILE"

get_fingerprint() {
    echo "$1" | openssl x509 -noout -fingerprint -sha256 | sed 's/://g' | awk -F= '{print $2}'
}

validate_certificate() {
    echo "$1" | openssl x509 -noout > /dev/null 2>&1
    return $?
}

add_certs_to_bundle() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        echo "Processing certificates from $cert_file..."
        awk '
            /BEGIN CERTIFICATE/,/END CERTIFICATE/ {
                print $0
            }
        ' "$cert_file" | while read -r line; do
            if [[ "$line" == *"END CERTIFICATE"* ]]; then
                cert+="$line"
                if validate_certificate "$cert"; then
                    local fingerprint
                    fingerprint=$(get_fingerprint "$cert")
                    echo "Found valid certificate with fingerprint: $fingerprint"
                    if ! grep -q "$fingerprint" "$FINGERPRINTS_FILE"; then
                        echo "$fingerprint" >> "$FINGERPRINTS_FILE"
                        echo "$cert" >> "$OUTPUT_FILE"
                        echo "Added certificate to bundle."
                    else
                        echo "Duplicate certificate found in $cert_file with fingerprint: $fingerprint"
                        echo "Skipping duplicate certificate."
                    fi
                else
                    echo "Invalid certificate found in $cert_file. Skipping."
                fi
                cert=""
            else
                cert+="$line"$'\n'
            fi
        done
    else
        echo "Warning: $cert_file does not exist"
    fi
}

for cert_file in "$CERTS_DIR"/*.{crt,pem}; do
    if [[ -f "$cert_file" ]]; then
        add_certs_to_bundle "$cert_file"
    fi
done

rm -f "$FINGERPRINTS_FILE"

echo "Certificates have been combined into $OUTPUT_FILE"
