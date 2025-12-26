#!/bin/bash
# Test POST /radio/data endpoint with HMAC authentication

set -e

# Configuration
SECRET="${SECRET:-fe0b169e98708033563a3d20808687ceffedec4d7b0392ee08eb104c5f689188}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
BASE_URL="http://${HOST}:${PORT}"

generate_hmac() {
    local body="$1"
    local timestamp="$2"
    # Use printf for binary-safe concatenation
    printf "%s%s" "$body" "$timestamp" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}'
}



# Test 1: Enable mobile data
echo "=== Test 1: Enable mobile data ==="
BODY='{"enable":true}'
TIMESTAMP=$(date +%s%3N)
HMAC=$(generate_hmac "$BODY" "$TIMESTAMP")

echo "Request: POST /radio/data"
echo "Body: $BODY"
echo "Timestamp: $TIMESTAMP"
echo "HMAC: $HMAC"
echo ""

RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY" \
    "${BASE_URL}/radio/data")

echo "Response:"
echo "$RESPONSE" | jq . || echo "$RESPONSE"
echo ""

# Wait a bit
sleep 2



# # Test 2: Disable mobile data
# echo "=== Test 2: Disable mobile data ==="
# BODY='{"enable":false}'
# TIMESTAMP=$(date +%s%3N)
# HMAC=$(generate_hmac "$BODY" "$TIMESTAMP")

# echo "Request: POST /radio/data"
# echo "Body: $BODY"
# echo "Timestamp: $TIMESTAMP"
# echo "HMAC: $HMAC"
# echo ""

# RESPONSE=$(curl -s -X POST \
#     -H "Content-Type: application/json" \
#     -H "X-Auth: $HMAC" \
#     -H "X-Time: $TIMESTAMP" \
#     -d "$BODY" \
#     "${BASE_URL}/radio/data")

# echo "Response:"
# echo "$RESPONSE" | jq . || echo "$RESPONSE"
# echo ""

# Test 3: Invalid auth (wrong secret)
echo "=== Test 3: Invalid authentication (should fail) ==="
BODY='{"enable":true}'
TIMESTAMP=$(date +%s%3N)
HMAC="invalid_hmac_signature"

echo "Request: POST /radio/data"
echo "Body: $BODY"
echo "Using invalid HMAC"
echo ""

RESPONSE=$(curl -s -w "\nHTTP Status: %{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY" \
    "${BASE_URL}/radio/data")

echo "Response:"
echo "$RESPONSE"
echo ""

echo "=== Tests completed ==="
