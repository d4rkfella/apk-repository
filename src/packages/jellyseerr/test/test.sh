#!/usr/bin/env bash
set -eo pipefail

TARGET_DIR="/usr/lib/Jellyseerr"
REQUIRED_PERMS="o+rx"

check_dir_perms() {
    local dir="$1"
    if ! [ -r "$dir" ] || ! [ -x "$dir" ]; then
        echo "❌ Permission error: 'others' need read/execute permissions on: $dir" >&2
        echo "   Current permissions: $(stat -c '%A %a %n' "$dir")" >&2
        exit 1
    fi
}

verify_permissions() {
    echo "Checking permissions in $TARGET_DIR..."
    
    check_dir_perms "$TARGET_DIR"
    
    find "$TARGET_DIR" -type d | while read -r dir; do
        check_dir_perms "$dir"
    done
    
    echo "✅ All directories have correct permissions"
}


verify_permissions

export NODE_ENV=production

cd "$TARGET_DIR" || exit 1

node dist/index.js 2>&1 &

timeout 20s bash -c 'until curl -s http://localhost:5055; do sleep 2; done'

version=$(curl -s http://localhost:5055/api/v1/status | jq -r '.version')
[[ "$version" == "$expected_version" ]] || {
  echo "❌ Version mismatch: $version" >&2
  exit 1
}

echo "✅ All tests passed"
