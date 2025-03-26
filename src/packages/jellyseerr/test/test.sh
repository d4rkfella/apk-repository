#!/usr/bin/env bash
set -eo pipefail

node dist/index.js > /tmp/server.log 2>&1 &
SERVER_PID=$!

echo "Waiting for server to start..."
for i in {1..5}; do
  if curl -s http://localhost:5055 >/dev/null; then
    break
  fi
  sleep $i
  echo "Attempt $i/5..."
done

response=$(curl -sf http://localhost:5055/api/v1/status)

version=$(echo "$response" | jq -r '.version')
expected_version="${{package.version}}"

if [[ -z "$version" ]]; then
  echo "❌ Version field missing in response"
  echo "Full response: $response"
  exit 1
elif [[ "$version" != "$expected_version" ]]; then
  echo "❌ Version mismatch: got '$version', expected '$expected_version'"
  exit 1
fi
echo "✅ Version check passed ($version)"

echo "$response" | jq -e '
  .updateAvailable | type == "boolean" and
  .restartRequired | type == "boolean"
' >/dev/null || {
  echo "❌ Missing required boolean fields"
  exit 1
}
echo "✅ Field types validated"

kill $SERVER_PID
echo -e "\nAll tests passed!"
