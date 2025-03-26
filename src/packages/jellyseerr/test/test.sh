#!/usr/bin/env bash
set -eo pipefail

# Configuration
TARGET_DIR="/usr/lib/Jellyseerr"
EXPECTED_VERSION="${EXPECTED_VERSION}"
SERVER_PORT=5055
STARTUP_TIMEOUT=20

# --------------------------------------------------
# Function: Verify Directory Permissions
# --------------------------------------------------
verify_permissions() {
    echo "Checking directory permissions..."
    find "$TARGET_DIR" -type d | while read -r dir; do
        if ! [ -r "$dir" ] || ! [ -x "$dir" ]; then
            echo "❌ Permission error: Need read/execute permissions on: $dir" >&2
            stat -c '%A %a %n' "$dir" >&2
            exit 1
        fi
    done
    echo "✅ All directories have correct permissions"
}

# --------------------------------------------------
# Function: Start and Test Server
# --------------------------------------------------
run_tests() {
    export NODE_ENV=production
    cd "$TARGET_DIR" || exit 1

    echo "Starting server (expecting version: ${EXPECTED_VERSION})..."
    node dist/index.js >/tmp/server.log 2>&1 &

    echo "Waiting for server readiness (max ${STARTUP_TIMEOUT}s)..."
    timeout $STARTUP_TIMEOUT bash -c "
        while ! curl -sSf http://localhost:$SERVER_PORT >/dev/null 2>&1; do
            sleep 1
        done
    " || {
        echo "❌ Server failed to start within ${STARTUP_TIMEOUT}s" >&2
        echo "=== Server logs ===" >&2
        cat /tmp/server.log >&2
        exit 1
    }

    version=$(curl -sSf http://localhost:$SERVER_PORT/api/v1/status | jq -r '.version')
    [[ "$version" == "$EXPECTED_VERSION" ]] || {
        echo "❌ Version mismatch: expected ${EXPECTED_VERSION}, got ${version}" >&2
        exit 1
    }
    echo "✅ Version check passed (${version})"
}

# --------------------------------------------------
# Main Execution
# --------------------------------------------------
verify_permissions
run_tests

echo "✅ All tests completed successfully"
