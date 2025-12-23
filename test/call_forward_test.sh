#!/bin/bash
# Test POST /call/forward endpoint with HMAC authentication

set -e

# Configuration
SECRET="${SECRET:-your-secret-key-here-generate-new-one}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8080}"
BASE_URL="http://${HOST}:${PORT}"

# Function to generate HMAC
generate_hmac() {
    local body="$1"
    local timestamp="$2"
    local message="${body}${timestamp}"
    echo -n "$message" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}'
}

# Test 1: Enable call forwarding with valid number
echo "=== Test 1: Enable call forwarding ==="
BODY='{"enable":true,"number":"+1234567890"}'
TIMESTAMP=$(date +%s%3N)
HMAC=$(generate_hmac "$BODY" "$TIMESTAMP")

echo "Request: POST /call/forward"
echo "Body: $BODY"
echo "Timestamp: $TIMESTAMP"
echo "HMAC: $HMAC"
echo ""

RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY" \
    "${BASE_URL}/call/forward")

echo "Response:"
echo "$RESPONSE" | jq . || echo "$RESPONSE"
echo ""

# Wait a bit
sleep 2

# Test 2: Check status to verify call forwarding is enabled
echo "=== Test 2: Check status (should show call_forwarding: true) ==="
TIMESTAMP=$(date +%s%3N)
HMAC=$(generate_hmac "" "$TIMESTAMP")

RESPONSE=$(curl -s -X GET \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    "${BASE_URL}/status")

echo "Response:"
echo "$RESPONSE" | jq . || echo "$RESPONSE"
echo ""

sleep 2

# Test 3: Disable call forwarding
echo "=== Test 3: Disable call forwarding ==="
BODY='{"enable":false}'
TIMESTAMP=$(date +%s%3N)
HMAC=$(generate_hmac "$BODY" "$TIMESTAMP")

echo "Request: POST /call/forward"
echo "Body: $BODY"
echo "Timestamp: $TIMESTAMP"
echo "HMAC: $HMAC"
echo ""

RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY" \
    "${BASE_URL}/call/forward")

echo "Response:"
echo "$RESPONSE" | jq . || echo "$RESPONSE"
echo ""

sleep 2

# Test 4: Enable without number (should fail)
echo "=== Test 4: Enable call forwarding without number (should fail) ==="
BODY='{"enable":true}'
TIMESTAMP=$(date +%s%3N)
HMAC=$(generate_hmac "$BODY" "$TIMESTAMP")

echo "Request: POST /call/forward"
echo "Body: $BODY"
echo ""

RESPONSE=$(curl -s -w "\nHTTP Status: %{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY" \
    "${BASE_URL}/call/forward")

echo "Response:"
echo "$RESPONSE"
echo ""

sleep 1

# Test 5: Invalid phone number format (should fail)
echo "=== Test 5: Invalid phone number format (should fail) ==="
BODY='{"enable":true,"number":"abc123"}'
TIMESTAMP=$(date +%s%3N)
HMAC=$(generate_hmac "$BODY" "$TIMESTAMP")

echo "Request: POST /call/forward"
echo "Body: $BODY"
echo ""

RESPONSE=$(curl -s -w "\nHTTP Status: %{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY" \
    "${BASE_URL}/call/forward")

echo "Response:"
echo "$RESPONSE"
echo ""

sleep 1

# Test 6: Invalid authentication (should fail)
echo "=== Test 6: Invalid authentication (should fail) ==="
BODY='{"enable":true,"number":"+1234567890"}'
TIMESTAMP=$(date +%s%3N)
HMAC="invalid_hmac_signature"

echo "Request: POST /call/forward"
echo "Using invalid HMAC"
echo ""

RESPONSE=$(curl -s -w "\nHTTP Status: %{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -H "X-Auth: $HMAC" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY" \
    "${BASE_URL}/call/forward")

echo "Response:"
echo "$RESPONSE"
echo ""

echo "==================================="
echo "Call forwarding tests completed!"
echo "==================================="
