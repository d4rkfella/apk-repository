#!/usr/bin/env bash
set -eo pipefail

# Configuration
TARGET_DIR="/usr/lib/Jellyseerr"
EXPECTED_VERSION="$EXPECTED_VERSION"
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

    # Start server (no PID tracking needed in containers)
    echo "Starting server..."
    node dist/index.js 2>&1 &

    # Wait for startup
    echo "Waiting for server (max ${STARTUP_TIMEOUT}s)..."
    timeout $STARTUP_TIMEOUT bash -c "
        until curl -sSf http://localhost:$SERVER_PORT; do
            sleep 2
        done
    " || {
        echo "❌ Server failed to start" >&2
        exit 1
    }

    # Version test
    version=$(curl -sSf http://localhost:$SERVER_PORT/api/v1/status | jq -r '.version')
    [[ "$version" == "$EXPECTED_VERSION" ]] || {
        echo "❌ Version mismatch: expected $EXPECTED_VERSION, got $version" >&2
        exit 1
    }
    echo "✅ Version check passed ($version)"
}

# --------------------------------------------------
# Main Execution
# --------------------------------------------------
verify_permissions
run_tests

echo "✅ All tests completed successfully"
