#!/bin/bash
# Quick test script for daemon

SECRET="your-secret-key-here-generate-new-one"
TIMESTAMP=$(date +%s%3N)
HMAC=$(echo -n "$TIMESTAMP" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')

echo "Testing GET /status..."
curl -s \
  -H "X-Auth: $HMAC" \
  -H "X-Time: $TIMESTAMP" \
  http://127.0.0.1:8080/status | jq '.' || echo "Failed"
