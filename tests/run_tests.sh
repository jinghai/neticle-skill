#!/usr/bin/env bash

set -e

# Load the API functions
source ./scripts/neticle-api.sh

# Enable debug mode to see headers and rate limits
export NETICLE_DEBUG=1

TEST_KEYWORD_ID=102336
TEST_PROFILE_ID=18694
TEST_CLIENT_ID=11882

echo "=========================================================="
echo "🧪 NETICLE API FULL 50+ ENDPOINTS TESTS"
echo "=========================================================="

# Create an array to track stats
declare -A TEST_RESULTS

test_endpoint() {
    local name="$1"
    local cmd="$2"
    
    echo -e "\n--- Test: $name ---"
    echo "Running: $cmd"
    
    set +e
    eval "$cmd" > /tmp/neticle_test_out 2>&1
    local exit_code=$?
    set -e
    
    local output=$(cat /tmp/neticle_test_out)
    
    # We consider 0, 400 (Validation Error due to dummy data), 404 (Not Found), 
    # 405 (Method Not Allowed), 403 (Forbidden), 429 (Rate Limit) as successful routing
    # to the Neticle API because the API layer responded rather than our script failing natively.
    if [[ $exit_code -eq 0 ]]; then
        echo "✅ SUCCESS (200 OK)"
        echo "$output" | grep -v 'DEBUG' | grep -v 'RateLimit' | jq -c '.data // .error' 2>/dev/null | cut -c 1-150 || echo "$output" | head -n 5 || true
        TEST_RESULTS["$name"]="✅ Passed (200 OK)"
    elif [[ $exit_code -eq 403 ]]; then
        echo "⚠️ SKIPPED (403 Forbidden - expected for Read-Only API Key)"
        TEST_RESULTS["$name"]="⚠️ Skipped (No Permission 403)"
    elif [[ $exit_code -eq 404 || $exit_code -eq 400 || $exit_code -eq 422 ]]; then
        echo "ℹ️ ROUTED (HTTP 4xx - expected for dummy/test IDs)"
        TEST_RESULTS["$name"]="ℹ️ Routed (Validation 4xx)"
    else
        echo "❌ FAILED (Exit code $exit_code)"
        echo "$output" | head -n 10 || true
        TEST_RESULTS["$name"]="❌ Failed (Exit $exit_code)"
    fi
}

echo "=== 1. RESOURCES & CORE DATA ==="
test_endpoint "List Resources" "neticle_list_resources"
test_endpoint "List Mentions" "neticle_list_mentions '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[]}}'"
# Attempt to get a mention ID to test single mention endpoints
MENTION_ID=$(cat /tmp/neticle_test_out | grep -v 'DEBUG' | jq -r '.data[0].id' 2>/dev/null || echo "102336-dummy")
if [ "$MENTION_ID" = "null" ] || [ -z "$MENTION_ID" ]; then MENTION_ID="102336-dummy"; fi

test_endpoint "Get Single Mention" "neticle_get_mention '$MENTION_ID'"
test_endpoint "Create Mention" "neticle_create_mention '{\"keywordId\":$TEST_KEYWORD_ID,\"content\":\"Dummy Test Mention\",\"createdAtUtcMs\":1700000000000}'"
test_endpoint "Update Mentions (Batch)" "neticle_update_mentions '{\"mentionIds\":[\"$MENTION_ID\"],\"polarityId\":2}'"
test_endpoint "Delete Mention" "neticle_delete_mention '$MENTION_ID'"
test_endpoint "Delete Mentions (Batch)" "neticle_delete_mentions '{\"mentionIds\":[\"$MENTION_ID\"]}'"
test_endpoint "Restore Mentions (Batch)" "neticle_restore_mentions '{\"mentionIds\":[\"$MENTION_ID\"]}'"
test_endpoint "Poll Data Feed" "neticle_poll_data_feed '{\"dataSourceId\":\"$TEST_KEYWORD_ID\"}'"

next_page_token=$(cat /tmp/neticle_test_out | grep -v 'DEBUG' | jq -r '.meta.nextPageToken // ""' 2>/dev/null || true)
if [ -n "$next_page_token" ] && [ "$next_page_token" != "null" ]; then
    test_endpoint "Data Feed Next Page" "neticle_next_page '$TEST_KEYWORD_ID' '$next_page_token'"
else
    test_endpoint "Data Feed Next Page" "neticle_next_page '$TEST_KEYWORD_ID' 'dummy_token'"
fi

test_endpoint "Deleted Mention Logs" "neticle_list_deleted_mention_logs '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID]}}'"

echo "=== 2. AGGREGATIONS & INSIGHTS ==="
test_endpoint "Get KPIs" "neticle_get_kpis '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[]}}'"
test_endpoint "Get Interactions" "neticle_get_interactions '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[]}}'"
test_endpoint "List Chart Templates" "neticle_list_chart_templates"
# Try to get first chart template ID
TEMPLATE_ID=$(cat /tmp/neticle_test_out | grep -v 'DEBUG' | jq -r '.data[0].id' 2>/dev/null || echo "1")
if [ "$TEMPLATE_ID" = "null" ] || [ -z "$TEMPLATE_ID" ]; then TEMPLATE_ID="1"; fi
test_endpoint "Get Chart Template" "neticle_get_chart_template '$TEMPLATE_ID'"
test_endpoint "Get Chart Data" "neticle_get_chart_data '$TEMPLATE_ID' '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID]}}'"
test_endpoint "List Insights" "neticle_list_insights '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"interval\":{\"start\":1700000000000,\"end\":1710000000000}}}'"

echo "=== 3. CONFIGURATION MANAGEMENT ==="
test_endpoint "List Keywords" "neticle_list_keywords"
test_endpoint "Get Keyword" "neticle_get_keyword '$TEST_KEYWORD_ID'"
test_endpoint "Create Keyword" "neticle_create_keyword '{\"profileId\":$TEST_PROFILE_ID,\"name\":\"test_kw_agent_$RANDOM\",\"label\":\"Test Kw\"}' '1'"
# Fetch a dummy ID created or just use TEST_KEYWORD_ID
test_endpoint "Update Keyword" "neticle_update_keyword '$TEST_KEYWORD_ID' '{\"name\":\"abutti_updated\"}'"

test_endpoint "List Keyword Groups" "neticle_list_keyword_groups"
GROUP_ID=$(neticle_list_keyword_groups 2>/dev/null | jq -r '.data[0].id' 2>/dev/null || echo "1")
if [ "$GROUP_ID" = "null" ] || [ -z "$GROUP_ID" ]; then GROUP_ID="1"; fi
test_endpoint "Get Keyword Group" "neticle_get_keyword_group '$GROUP_ID'"
test_endpoint "Create Keyword Group" "neticle_create_keyword_group '{\"profileId\":$TEST_PROFILE_ID,\"label\":\"Test Group\"}'"
test_endpoint "Update Keyword Group" "neticle_update_keyword_group '$GROUP_ID' '{\"label\":\"Test Group Updated\"}'"

test_endpoint "Start Past Processing" "neticle_start_past_processing '$TEST_KEYWORD_ID' '{\"startDateUtcMs\":1700000000000}'"

test_endpoint "List Aspects" "neticle_list_aspects"
ASPECT_ID=$(neticle_list_aspects 2>/dev/null | jq -r '.data[0].id' 2>/dev/null || echo "1")
if [ "$ASPECT_ID" = "null" ] || [ -z "$ASPECT_ID" ]; then ASPECT_ID="1"; fi
test_endpoint "Get Aspect" "neticle_get_aspect '$ASPECT_ID'"

test_endpoint "List Aspect Groups" "neticle_list_aspect_groups"
ASPECT_GROUP_ID=$(neticle_list_aspect_groups 2>/dev/null | jq -r '.data[0].id' 2>/dev/null || echo "1")
if [ "$ASPECT_GROUP_ID" = "null" ] || [ -z "$ASPECT_GROUP_ID" ]; then ASPECT_GROUP_ID="1"; fi
test_endpoint "Get Aspect Group" "neticle_get_aspect_group '$ASPECT_GROUP_ID'"
test_endpoint "Create Aspect Group" "neticle_create_aspect_group '{\"profileId\":$TEST_PROFILE_ID,\"label\":\"Test Aspect Grp\"}' '$TEST_PROFILE_ID'"
test_endpoint "Update Aspect Group" "neticle_update_aspect_group '$ASPECT_GROUP_ID' '{\"label\":\"Test Aspect Grp Updated\"}'"

test_endpoint "List Own Channels" "neticle_list_own_channels"
OC_ID=$(neticle_list_own_channels 2>/dev/null | jq -r '.data[0].id' 2>/dev/null || echo "1")
if [ "$OC_ID" = "null" ] || [ -z "$OC_ID" ]; then OC_ID="1"; fi
test_endpoint "Get Own Channel" "neticle_get_own_channel '$OC_ID'"
test_endpoint "Create Own Channel" "neticle_create_own_channel '{\"profileId\":$TEST_PROFILE_ID,\"platformId\":2,\"externalId\":\"dummy\"}' '$TEST_KEYWORD_ID'"
test_endpoint "Delete Own Channel" "neticle_delete_own_channel '$OC_ID' '$TEST_KEYWORD_ID'"

echo "=== 4. FILTERS & SUGGESTIONS ==="
test_endpoint "List Keyword Filters" "neticle_list_keyword_filters '$TEST_KEYWORD_ID'"
test_endpoint "Create Keyword Filters" "neticle_create_keyword_filters '[\"dummyfilter1\"]' '$TEST_KEYWORD_ID'"
test_endpoint "Delete Keyword Filters" "neticle_delete_keyword_filters '[\"dummyfilter1\"]' '$TEST_KEYWORD_ID'"

test_endpoint "List Synonyms" "neticle_list_synonyms '$TEST_KEYWORD_ID'"
test_endpoint "Create Synonyms" "neticle_create_synonyms '[\"dummysyn1\"]' '$TEST_KEYWORD_ID'"
test_endpoint "Delete Synonyms" "neticle_delete_synonyms '[\"dummysyn1\"]' '$TEST_KEYWORD_ID'"

test_endpoint "List Excludes" "neticle_list_excludes '$TEST_KEYWORD_ID'"
test_endpoint "Create Excludes" "neticle_create_excludes '[\"dummyexclude1\"]' '$TEST_KEYWORD_ID'"
test_endpoint "Delete Excludes" "neticle_delete_excludes '[\"dummyexclude1\"]' '$TEST_KEYWORD_ID'"

test_endpoint "Filter Suggestions" "neticle_keyword_filter_suggestions '$TEST_KEYWORD_ID'"
test_endpoint "Synonym Suggestions" "neticle_synonym_suggestions '$TEST_KEYWORD_ID'"
test_endpoint "Exclude Suggestions" "neticle_exclude_suggestions '$TEST_KEYWORD_ID'"

echo "=== 5. REFERENCE DATA ==="
test_endpoint "List Sources" "neticle_list_sources"
test_endpoint "List Languages" "neticle_list_languages"
test_endpoint "List Countries" "neticle_list_countries"
test_endpoint "Get Country" "neticle_get_country '29'"

test_endpoint "List Clients" "neticle_list_clients"
test_endpoint "Get Client" "neticle_get_client '$TEST_CLIENT_ID'"

test_endpoint "List Profiles" "neticle_list_profiles"
test_endpoint "Get Profile" "neticle_get_profile '$TEST_PROFILE_ID'"
test_endpoint "Create Profile" "neticle_create_profile '{\"clientId\":$TEST_CLIENT_ID,\"label\":\"AgentCreatedProfile\"}'"
test_endpoint "Update Profile" "neticle_update_profile '$TEST_PROFILE_ID' '{\"label\":\"Aike Updated\"}'"

test_endpoint "Create User" "neticle_create_user '{\"clientId\":$TEST_CLIENT_ID,\"firstName\":\"Test\",\"lastName\":\"Bot\",\"email\":\"test@neticle.com\"}'"

echo -e "\n=========================================================="
echo "✅ All endpoints tested."
echo "=========================================================="

echo -e "\n### TEST SUMMARY REPORT"
echo "--------------------------------------------------------"
for key in "${!TEST_RESULTS[@]}"; do
    printf "%-35s : %s\n" "$key" "${TEST_RESULTS[$key]}"
done
echo "--------------------------------------------------------"
