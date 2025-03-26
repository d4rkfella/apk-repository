#!/usr/bin/env bash
set -eo pipefail

export NODE_ENV=production

cd /usr/lib/Jellyseerr

node dist/index.js > /tmp/server.log 2>&1 &

timeout 20s bash -c 'until curl -s http://localhost:5055; do sleep 2; done'

version=$(curl -s http://localhost:5055/api/v1/status | jq -r '.version')
[[ "$version" == "$expected_version" ]] || {
  echo "❌ Version mismatch: $version" >&2
  exit 1
}

echo "✅ All tests passed"
