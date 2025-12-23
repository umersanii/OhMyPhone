#!/bin/bash
# Integration test for airplane mode toggle endpoint

set -e

# Configuration
BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
SECRET="${SECRET:-supersecretkey123}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to generate HMAC-SHA256 signature
generate_hmac() {
    local body="$1"
    local timestamp=$(date +%s)000
    local message="${body}${timestamp}"
    local signature=$(echo -n "$message" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)
    echo "${signature}|${timestamp}"
}

# Function to make authenticated POST request
authenticated_post() {
    local endpoint="$1"
    local body="$2"

    local hmac_result=$(generate_hmac "$body")
    local signature=$(echo "$hmac_result" | cut -d'|' -f1)
    local timestamp=$(echo "$hmac_result" | cut -d'|' -f2)

    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "X-Auth: $signature" \
        -H "X-Time: $timestamp" \
        -d "$body" \
        "${BASE_URL}${endpoint}"
}

# Function to get status
get_status() {
    local timestamp=$(date +%s)000
    local message="$timestamp"
    local signature=$(echo -n "$message" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

    curl -s -X GET \
        -H "X-Auth: $signature" \
        -H "X-Time: $timestamp" \
        "${BASE_URL}/status"
}

echo -e "${YELLOW}=== OhMyPhone Airplane Mode Integration Test ===${NC}"
echo ""

# Test 1: Enable airplane mode
echo -e "${YELLOW}Test 1: Enabling airplane mode...${NC}"
RESPONSE=$(authenticated_post "/radio/airplane" '{"enable":true}')
echo "Response: $RESPONSE"

if echo "$RESPONSE" | jq -e '.success == true and .enabled == true' > /dev/null; then
    echo -e "${GREEN}✓ Airplane mode enabled successfully${NC}"
else
    echo -e "${RED}✗ Failed to enable airplane mode${NC}"
    exit 1
fi

echo ""
sleep 2

# Test 2: Verify airplane mode is enabled via status
echo -e "${YELLOW}Test 2: Verifying airplane mode is enabled...${NC}"
STATUS=$(get_status)
echo "Status: $STATUS"

if echo "$STATUS" | jq -e '.airplane_mode == true' > /dev/null; then
    echo -e "${GREEN}✓ Airplane mode confirmed enabled${NC}"
else
    echo -e "${RED}✗ Status does not show airplane mode enabled${NC}"
    exit 1
fi

echo ""
sleep 2

# Test 3: Disable airplane mode
echo -e "${YELLOW}Test 3: Disabling airplane mode...${NC}"
RESPONSE=$(authenticated_post "/radio/airplane" '{"enable":false}')
echo "Response: $RESPONSE"

if echo "$RESPONSE" | jq -e '.success == true and .enabled == false' > /dev/null; then
    echo -e "${GREEN}✓ Airplane mode disabled successfully${NC}"
else
    echo -e "${RED}✗ Failed to disable airplane mode${NC}"
    exit 1
fi

echo ""
sleep 2

# Test 4: Verify airplane mode is disabled via status
echo -e "${YELLOW}Test 4: Verifying airplane mode is disabled...${NC}"
STATUS=$(get_status)
echo "Status: $STATUS"

if echo "$STATUS" | jq -e '.airplane_mode == false' > /dev/null; then
    echo -e "${GREEN}✓ Airplane mode confirmed disabled${NC}"
else
    echo -e "${RED}✗ Status does not show airplane mode disabled${NC}"
    exit 1
fi

echo ""
sleep 2

# Test 5: Re-enable airplane mode (cycle test)
echo -e "${YELLOW}Test 5: Re-enabling airplane mode (cycle test)...${NC}"
RESPONSE=$(authenticated_post "/radio/airplane" '{"enable":true}')

if echo "$RESPONSE" | jq -e '.success == true and .enabled == true' > /dev/null; then
    echo -e "${GREEN}✓ Airplane mode re-enabled successfully${NC}"
else
    echo -e "${RED}✗ Failed to re-enable airplane mode${NC}"
    exit 1
fi

echo ""
sleep 2

# Test 6: Final disable to restore original state
echo -e "${YELLOW}Test 6: Restoring to disabled state...${NC}"
RESPONSE=$(authenticated_post "/radio/airplane" '{"enable":false}')

if echo "$RESPONSE" | jq -e '.success == true and .enabled == false' > /dev/null; then
    echo -e "${GREEN}✓ Airplane mode restored to disabled${NC}"
else
    echo -e "${RED}✗ Failed to restore airplane mode state${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=== All airplane mode tests passed! ===${NC}"
