#!/usr/bin/env bash

set -e

# Load the API functions
source ./scripts/neticle-api.sh

# Enable debug mode to see headers and rate limits
export NETICLE_DEBUG=1

TEST_KEYWORD_ID=102336

echo "=========================================================="
echo "🧪 NETICLE API FULL ENDPOINT TESTS"
echo "=========================================================="

# Define a helper function to safely test a read-only endpoint
test_read_endpoint() {
    local name="$1"
    local command="$2"
    local params="${3:-}"
    
    echo -e "\n--- Test: $name ---"
    echo "Running: $command $params"
    
    # Run the command and capture output and exit code
    set +e
    if [[ -z "$params" ]]; then
        output=$($command 2>&1)
    else
        output=$($command "$params" 2>&1)
    fi
    exit_code=$?
    set -e
    
    if [[ $exit_code -ne 0 && $exit_code -ne 429 && $exit_code -ne 141 ]]; then
        echo "❌ Command failed with exit code $exit_code."
        echo "$output" | head -n 10 || true
        # return 1 # We won't exit the whole script to allow other tests to run
    else
        echo "✅ Success! Output snippet:"
        echo "$output" | grep -v 'DEBUG' | grep -v 'RateLimit' | jq -c '.data' 2>/dev/null | cut -c 1-100 || echo "$output" | head -n 5 || true
    fi
}

echo "=== 1. RESOURCES & CORE DATA ==="
test_read_endpoint "List Resources" "neticle_list_resources"
test_read_endpoint "List Mentions (Keyword $TEST_KEYWORD_ID)" "neticle_list_mentions" "{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[]}}"
test_read_endpoint "Data Feed Changes (Keyword $TEST_KEYWORD_ID)" "neticle_poll_data_feed" "{\"dataSourceId\":\"$TEST_KEYWORD_ID\"}"

echo "=== 2. AGGREGATIONS & INSIGHTS ==="
test_read_endpoint "Get KPIs" "neticle_get_kpis" "{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[]}}"
test_read_endpoint "Get Interactions" "neticle_get_interactions" "{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[]}}"
test_read_endpoint "List Chart Templates" "neticle_list_chart_templates"
# test_read_endpoint "List Insights" "neticle_list_insights" "{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[],\"interval\":{\"start\":1700000000000,\"end\":1710000000000}}}"

echo "=== 3. CONFIGURATION MANAGEMENT ==="
test_read_endpoint "List Keywords" "neticle_list_keywords"
test_read_endpoint "Get Keyword ($TEST_KEYWORD_ID)" "neticle_get_keyword" "$TEST_KEYWORD_ID"
test_read_endpoint "List Keyword Groups" "neticle_list_keyword_groups"
test_read_endpoint "List Aspects" "neticle_list_aspects"
test_read_endpoint "List Aspect Groups" "neticle_list_aspect_groups"
test_read_endpoint "List Own Channels" "neticle_list_own_channels"

echo "=== 4. FILTERS & SUGGESTIONS ==="
test_read_endpoint "List Keyword Filters" "neticle_list_keyword_filters" "$TEST_KEYWORD_ID"
test_read_endpoint "List Synonyms" "neticle_list_synonyms" "$TEST_KEYWORD_ID"
test_read_endpoint "List Excludes" "neticle_list_excludes" "$TEST_KEYWORD_ID"
test_read_endpoint "Filter Suggestions" "neticle_keyword_filter_suggestions" "$TEST_KEYWORD_ID"
test_read_endpoint "Synonym Suggestions" "neticle_synonym_suggestions" "$TEST_KEYWORD_ID"
test_read_endpoint "Exclude Suggestions" "neticle_exclude_suggestions" "$TEST_KEYWORD_ID"

echo "=== 5. REFERENCE DATA ==="
test_read_endpoint "List Sources" "neticle_list_sources"
test_read_endpoint "List Languages" "neticle_list_languages"
test_read_endpoint "List Countries" "neticle_list_countries"
test_read_endpoint "List Clients" "neticle_list_clients"
test_read_endpoint "List Profiles" "neticle_list_profiles"

echo -e "\n=========================================================="
echo "✅ All read-only endpoint tests completed."
echo "=========================================================="
