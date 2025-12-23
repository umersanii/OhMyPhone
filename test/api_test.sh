#!/bin/bash
# API Integration Test Script for OhMyPhone Daemon
# Requires: jq, openssl

set -e

# Configuration
HOST="${DAEMON_HOST:-127.0.0.1}"
PORT="${DAEMON_PORT:-8080}"
SECRET="${DAEMON_SECRET:-your-secret-key-here-generate-new-one}"
BASE_URL="http://${HOST}:${PORT}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to generate HMAC signature
generate_hmac() {
    local body="$1"
    local timestamp="$2"
    local message="${body}${timestamp}"
    echo -n "$message" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}'
}

# Function to make authenticated request
api_request() {
    local method="$1"
    local endpoint="$2"
    local body="${3:-}"

    local timestamp=$(date +%s%3N)  # Unix milliseconds
    local hmac=$(generate_hmac "$body" "$timestamp")

    echo -e "${YELLOW}Testing: $method $endpoint${NC}"

    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" \
            -X GET \
            -H "X-Auth: $hmac" \
            -H "X-Time: $timestamp" \
            "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "X-Auth: $hmac" \
            -H "X-Time: $timestamp" \
            -d "$body" \
            "$BASE_URL$endpoint")
    fi

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | head -n-1)

    if [ "$http_code" -eq 200 ]; then
        echo -e "${GREEN}✓ Success (HTTP $http_code)${NC}"
        echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
    else
        echo -e "${RED}✗ Failed (HTTP $http_code)${NC}"
        echo "$response_body"
        return 1
    fi
    echo ""
}

# Test 1: Check if daemon is running
echo "============================================"
echo "OhMyPhone Daemon API Tests"
echo "============================================"
echo "Target: $BASE_URL"
echo "Secret: ${SECRET:0:10}..."
echo ""

# Test 2: GET /status
echo "Test 1: GET /status"
echo "--------------------------------------------"
api_request GET "/status" || echo -e "${RED}Status check failed${NC}\n"

# Test 3: Authentication failure (wrong HMAC)
echo "Test 2: Authentication Failure (Invalid HMAC)"
echo "--------------------------------------------"
timestamp=$(date +%s%3N)
invalid_hmac="0000000000000000000000000000000000000000000000000000000000000000"
response=$(curl -s -w "\n%{http_code}" \
    -X GET \
    -H "X-Auth: $invalid_hmac" \
    -H "X-Time: $timestamp" \
    "$BASE_URL/status")
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" -eq 401 ]; then
    echo -e "${GREEN}✓ Correctly rejected invalid HMAC (HTTP 401)${NC}"
else
    echo -e "${RED}✗ Expected HTTP 401, got $http_code${NC}"
fi
echo ""

# Test 4: Timestamp expiry (old timestamp)
echo "Test 3: Replay Protection (Expired Timestamp)"
echo "--------------------------------------------"
old_timestamp=$(($(date +%s%3N) - 60000))  # 60 seconds ago
old_hmac=$(generate_hmac "" "$old_timestamp")
response=$(curl -s -w "\n%{http_code}" \
    -X GET \
    -H "X-Auth: $old_hmac" \
    -H "X-Time: $old_timestamp" \
    "$BASE_URL/status")
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" -eq 401 ]; then
    echo -e "${GREEN}✓ Correctly rejected expired timestamp (HTTP 401)${NC}"
else
    echo -e "${RED}✗ Expected HTTP 401, got $http_code${NC}"
fi
echo ""

# Test 5: Replay attack (same request twice)
echo "Test 4: Replay Protection (Duplicate Request)"
echo "--------------------------------------------"
timestamp=$(date +%s%3N)
hmac=$(generate_hmac "" "$timestamp")
# First request
curl -s -o /dev/null -w "%{http_code}" \
    -X GET \
    -H "X-Auth: $hmac" \
    -H "X-Time: $timestamp" \
    "$BASE_URL/status" > /dev/null
# Second request (replay)
response=$(curl -s -w "\n%{http_code}" \
    -X GET \
    -H "X-Auth: $hmac" \
    -H "X-Time: $timestamp" \
    "$BASE_URL/status")
http_code=$(echo "$response" | tail -n1)
if [ "$http_code" -eq 401 ]; then
    echo -e "${GREEN}✓ Correctly rejected replay attack (HTTP 401)${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Replay not detected (HTTP $http_code)${NC}"
fi
echo ""

echo "============================================"
echo "Test Suite Complete"
echo "============================================"
