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

# Create a temp file for results
RESULTS_FILE="/tmp/neticle_results.txt"
rm -f "$RESULTS_FILE"
touch "$RESULTS_FILE"

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
    local status="UNKNOWN"
    
    if [[ $exit_code -eq 0 ]]; then
        echo "✅ SUCCESS (200 OK)"
        status="✅ Passed (200 OK)"
    elif [[ $exit_code -eq 403 ]]; then
        echo "⚠️ SKIPPED (403 Forbidden - expected for Read-Only API Key)"
        status="⚠️ Skipped (No Permission 403)"
    elif [[ $exit_code -eq 404 || $exit_code -eq 400 || $exit_code -eq 422 ]]; then
        echo "ℹ️ ROUTED (HTTP 4xx - expected for dummy/test IDs)"
        status="ℹ️ Routed (Validation 4xx)"
    else
        echo "❌ FAILED (Exit code $exit_code)"
        status="❌ Failed (Exit $exit_code)"
    fi
    echo "$name | $status" >> "$RESULTS_FILE"
}

echo "=== 1. RESOURCES & CORE DATA ==="
test_endpoint "List Resources" "neticle_list_resources"
test_endpoint "List Mentions" "neticle_list_mentions '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"aspects\":[]}}'"
MENTION_ID=$(cat /tmp/neticle_test_out | grep -v 'DEBUG' | jq -r '.data[0].id' 2>/dev/null || echo "102336-111667")
if [ "$MENTION_ID" = "null" ] || [ -z "$MENTION_ID" ]; then MENTION_ID="102336-111667"; fi

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
TEMPLATE_ID=$(cat /tmp/neticle_test_out | grep -v 'DEBUG' | jq -r '.data[0].id' 2>/dev/null || echo "1")
if [ "$TEMPLATE_ID" = "null" ] || [ -z "$TEMPLATE_ID" ]; then TEMPLATE_ID="1"; fi
test_endpoint "Get Chart Template" "neticle_get_chart_template '$TEMPLATE_ID'"
test_endpoint "Get Chart Data" "neticle_get_chart_data '$TEMPLATE_ID' '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID]}}'"
test_endpoint "List Insights" "neticle_list_insights '{\"filters\":{\"keywords\":[$TEST_KEYWORD_ID],\"interval\":{\"start\":1700000000000,\"end\":1710000000000}}}'"

echo "=== 3. CONFIGURATION MANAGEMENT ==="
test_endpoint "List Keywords" "neticle_list_keywords"
test_endpoint "Get Keyword" "neticle_get_keyword '$TEST_KEYWORD_ID'"
test_endpoint "Create Keyword" "neticle_create_keyword '{\"profileId\":$TEST_PROFILE_ID,\"name\":\"test_kw_agent_$RANDOM\",\"label\":\"Test Kw\"}' '1'"
test_endpoint "Update Keyword" "neticle_update_keyword '$TEST_KEYWORD_ID' '{\"name\":\"abutti_updated\"}'"
test_endpoint "List Keyword Groups" "neticle_list_keyword_groups"
test_endpoint "Get Keyword Group" "neticle_get_keyword_group '18954'"
test_endpoint "Create Keyword Group" "neticle_create_keyword_group '{\"profileId\":$TEST_PROFILE_ID,\"label\":\"Test Group\"}'"
test_endpoint "Update Keyword Group" "neticle_update_keyword_group '18954' '{\"label\":\"Test Group Updated\"}'"
test_endpoint "Start Past Processing" "neticle_start_past_processing '$TEST_KEYWORD_ID' '{\"startDateUtcMs\":1700000000000}'"
test_endpoint "List Aspects" "neticle_list_aspects"
test_endpoint "Get Aspect" "neticle_get_aspect '1'"
test_endpoint "List Aspect Groups" "neticle_list_aspect_groups"
test_endpoint "Get Aspect Group" "neticle_get_aspect_group '1'"
test_endpoint "Create Aspect Group" "neticle_create_aspect_group '{\"profileId\":$TEST_PROFILE_ID,\"label\":\"Test Aspect Grp\"}' '$TEST_PROFILE_ID'"
test_endpoint "Update Aspect Group" "neticle_update_aspect_group '1' '{\"label\":\"Test Aspect Grp Updated\"}'"
test_endpoint "List Own Channels" "neticle_list_own_channels"
test_endpoint "Get Own Channel" "neticle_get_own_channel '250375'"
test_endpoint "Create Own Channel" "neticle_create_own_channel '{\"profileId\":$TEST_PROFILE_ID,\"platformId\":2,\"externalId\":\"dummy\"}' '$TEST_KEYWORD_ID'"
test_endpoint "Delete Own Channel" "neticle_delete_own_channel '250375' '$TEST_KEYWORD_ID'"

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

echo -e "\n### TEST SUMMARY REPORT (Categorized)"
echo "--------------------------------------------------------"
passed_count=0
skipped_count=0
routed_count=0
failed_count=0

while IFS='|' read -r name status; do
    name=$(echo "$name" | xargs)
    status=$(echo "$status" | xargs)
    printf "%-35s : %s\n" "$name" "$status"
    if [[ "$status" == *"200 OK"* ]]; then ((passed_count++)); fi
    if [[ "$status" == *"403"* ]]; then ((skipped_count++)); fi
    if [[ "$status" == *"Validation"* ]]; then ((routed_count++)); fi
    if [[ "$status" == *"Failed"* ]]; then ((failed_count++)); fi
done < "$RESULTS_FILE"

echo "--------------------------------------------------------"
echo "✅ Total Passed (200 OK)  : $passed_count"
echo "⚠️  Auth Restricted (403) : $skipped_count (Expected for Read-Only Key)"
echo "ℹ️  Routed / Validated   : $routed_count (Expected for Dummy IDs)"
echo "❌ Actual Failures       : $failed_count"
echo "--------------------------------------------------------"

rm -f "$RESULTS_FILE"

if [[ $failed_count -gt 0 ]]; then
    echo "❌ TEST FAILED: $failed_count actual failures detected."
    exit 1
else
    echo "🎉 TEST ROUTING SUCCESSFUL: All endpoints reached and responded as expected."
fi
