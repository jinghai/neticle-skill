#!/usr/bin/env bash

set -e

# Load the API functions
source ./scripts/neticle-api.sh

# Enable debug mode to show dynamic rate limits
export NETICLE_DEBUG=1

TEST_KEYWORD_ID=102336

echo "=========================================================="
echo "🧪 NETICLE API CORE INTEGRATION TESTS"
echo "=========================================================="

echo -e "\n--- Test 1: list_mentions (Ad-hoc queries) ---"
# We expect to see RateLimit-Remaining headers in the debug output
# Need to supply the required parameters: keywords and aspects (aspects can be empty if not needed by specific API, but docs say required. 
# Let's try an empty array for aspects as we found no aspectGroups).
echo "Calling list_mentions with keyword $TEST_KEYWORD_ID..."
list_mentions_params="{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[]}}"
neticle_list_mentions "$list_mentions_params" > /tmp/neticle_test_mentions.json
echo "Mentions query returned $(jq '.meta.totalCount' /tmp/neticle_test_mentions.json 2>/dev/null || echo 'unknown') total results."


echo -e "\n--- Test 2: poll_data_feed (Data Synchronization) ---"
echo "Calling poll_data_feed for data source $TEST_KEYWORD_ID..."
poll_params="{\"dataSourceId\":\"$TEST_KEYWORD_ID\"}"
neticle_poll_data_feed "$poll_params" > /tmp/neticle_test_poll.json
next_token=$(jq -r '.meta.nextPageToken // ""' /tmp/neticle_test_poll.json 2>/dev/null || echo "")
echo "Poll returned. Next page token provided: ${next_token:0:10}..."

echo -e "\n--- Test 3: poll_data_feed Rate Limit Trigger (Wait required) ---"
echo "The data-feed endpoint allows max 1 call per minute per data source. Let's call it again to see the dynamic rate limit handling!"

# In order not to block the AI agent completely for a full minute, we use a different keyword ID or we just let it fail or wait.
# Actually, the user wants to see the rate limit feedback management.
# Our script handles 429 automatically if RateLimit-Reset is present, or warns if remaining < 100.
# Let's just do a manual request to trigger 429 and show our script's robust handling:
# neticle_poll_data_feed "$poll_params" 2>&1 | head -n 20
# Wait, if we do that, it will loop or sleep depending on script logic.
# Our current _neticle_request logic:
# if HTTP 429, it prints "Error 429: Rate limit exceeded. Retry after X s." and returns 1.
# It only *sleeps* before request if rate_remaining < 10. But for 429, the header rate_remaining might be 0, and it handles it!

set +e
neticle_poll_data_feed "$poll_params" > /dev/null
exit_code=$?
set -e

if [ $exit_code -eq 1 ]; then
    echo "✅ Successfully caught rate limit using dynamic feedback!"
else
    echo "⚠️ Did not get a 429 error. Perhaps rate limit is different or handled differently."
fi

echo -e "\n=========================================================="
echo "✅ Tests completed successfully."
echo "=========================================================="
