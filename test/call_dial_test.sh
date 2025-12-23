#!/bin/bash
# Integration test for POST /call/dial endpoint

set -e

# Configuration
BASE_URL="${DAEMON_URL:-http://127.0.0.1:8080}"
SECRET="${DAEMON_SECRET:-test-secret-key-change-me}"
TEST_NUMBER="+15551234567"  # Safe test number (won't actually dial in test mode)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# HMAC signing function
sign_request() {
    local body="$1"
    local timestamp=$(date +%s%3N)  # Milliseconds
    local to_sign="${body}${timestamp}"
    local signature=$(echo -n "$to_sign" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)
    
    echo "$signature|$timestamp"
}

echo -e "${YELLOW}=== OhMyPhone Call Dial Integration Test ===${NC}\n"

# Test 1: Dial with valid phone number
echo -e "${YELLOW}Test 1: Dial valid phone number${NC}"
BODY='{"number":"'"$TEST_NUMBER"'"}'
AUTH_DATA=$(sign_request "$BODY")
SIGNATURE=$(echo "$AUTH_DATA" | cut -d'|' -f1)
TIMESTAMP=$(echo "$AUTH_DATA" | cut -d'|' -f2)

RESPONSE=$(curl -s -X POST "$BASE_URL/call/dial" \
    -H "Content-Type: application/json" \
    -H "X-Auth: $SIGNATURE" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | jq -e '.success == true' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: Successfully initiated dial${NC}\n"
else
    echo -e "${RED}✗ FAIL: Expected success=true${NC}\n"
    exit 1
fi

# Test 2: Dial with invalid phone number (too short)
echo -e "${YELLOW}Test 2: Reject invalid phone number (too short)${NC}"
BODY='{"number":"123"}'
AUTH_DATA=$(sign_request "$BODY")
SIGNATURE=$(echo "$AUTH_DATA" | cut -d'|' -f1)
TIMESTAMP=$(echo "$AUTH_DATA" | cut -d'|' -f2)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/call/dial" \
    -H "Content-Type: application/json" \
    -H "X-Auth: $SIGNATURE" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY")

if [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✓ PASS: Correctly rejected invalid number${NC}\n"
else
    echo -e "${RED}✗ FAIL: Expected HTTP 400, got $HTTP_CODE${NC}\n"
    exit 1
fi

# Test 3: Dial with invalid format (contains letters)
echo -e "${YELLOW}Test 3: Reject phone number with letters${NC}"
BODY='{"number":"123abc456"}'
AUTH_DATA=$(sign_request "$BODY")
SIGNATURE=$(echo "$AUTH_DATA" | cut -d'|' -f1)
TIMESTAMP=$(echo "$AUTH_DATA" | cut -d'|' -f2)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/call/dial" \
    -H "Content-Type: application/json" \
    -H "X-Auth: $SIGNATURE" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY")

if [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✓ PASS: Correctly rejected invalid format${NC}\n"
else
    echo -e "${RED}✗ FAIL: Expected HTTP 400, got $HTTP_CODE${NC}\n"
    exit 1
fi

# Test 4: Missing authentication header
echo -e "${YELLOW}Test 4: Reject request without authentication${NC}"
BODY='{"number":"'"$TEST_NUMBER"'"}'

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/call/dial" \
    -H "Content-Type: application/json" \
    -d "$BODY")

if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✓ PASS: Correctly rejected unauthenticated request${NC}\n"
else
    echo -e "${RED}✗ FAIL: Expected HTTP 401, got $HTTP_CODE${NC}\n"
    exit 1
fi

# Test 5: International number format
echo -e "${YELLOW}Test 5: Dial international number${NC}"
BODY='{"number":"+919876543210"}'
AUTH_DATA=$(sign_request "$BODY")
SIGNATURE=$(echo "$AUTH_DATA" | cut -d'|' -f1)
TIMESTAMP=$(echo "$AUTH_DATA" | cut -d'|' -f2)

RESPONSE=$(curl -s -X POST "$BASE_URL/call/dial" \
    -H "Content-Type: application/json" \
    -H "X-Auth: $SIGNATURE" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY")

echo "Response: $RESPONSE"
if echo "$RESPONSE" | jq -e '.success == true' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: Successfully initiated international dial${NC}\n"
else
    echo -e "${RED}✗ FAIL: Expected success=true${NC}\n"
    exit 1
fi

# Test 6: Missing number field
echo -e "${YELLOW}Test 6: Reject request without number${NC}"
BODY='{}'
AUTH_DATA=$(sign_request "$BODY")
SIGNATURE=$(echo "$AUTH_DATA" | cut -d'|' -f1)
TIMESTAMP=$(echo "$AUTH_DATA" | cut -d'|' -f2)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/call/dial" \
    -H "Content-Type: application/json" \
    -H "X-Auth: $SIGNATURE" \
    -H "X-Time: $TIMESTAMP" \
    -d "$BODY")

if [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✓ PASS: Correctly rejected missing number${NC}\n"
else
    echo -e "${RED}✗ FAIL: Expected HTTP 400, got $HTTP_CODE${NC}\n"
    exit 1
fi

echo -e "${GREEN}=== All Call Dial Tests Passed ===${NC}"
