#!/usr/bin/env bash
# =============================================================================
# Neticle Data API - Shell Script Wrapper
# =============================================================================
# Complete CLI/library for interacting with the Neticle Data API.
#
# Usage:
#   source scripts/neticle-api.sh   # Use as library (source functions)
#   bash scripts/neticle-api.sh <command> [args...]  # Use as CLI
#
# Environment Variables:
#   NETICLE_API_KEY      (required) Your Neticle API key
#   NETICLE_API_VERSION  (optional) API version, default: 24.04
#   NETICLE_DEBUG        (optional) Set to "1" for verbose output
# =============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------

NETICLE_BASE_URL="https://data.neticle.com"
NETICLE_API_VERSION="${NETICLE_API_VERSION:-24.04}"
NETICLE_DEBUG="${NETICLE_DEBUG:-0}"

# --- Helpers -----------------------------------------------------------------

_neticle_check_deps() {
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "❌ Error: '$cmd' is required but not installed." >&2
      return 1
    fi
  done
}

_neticle_check_api_key() {
  if [[ -z "${NETICLE_API_KEY:-}" ]]; then
    echo "❌ Error: NETICLE_API_KEY environment variable is not set." >&2
    echo "   Set it with: export NETICLE_API_KEY=\"your-api-key\"" >&2
    return 1
  fi
}

_neticle_url() {
  local path="$1"
  echo "${NETICLE_BASE_URL}/${NETICLE_API_VERSION}${path}"
}

_neticle_auth_header() {
  echo "Authorization: Basic ${NETICLE_API_KEY}"
}

# Core HTTP request function with rate limit handling
# Compatible with macOS (BSD curl/head/tail)
_neticle_request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local query_string="${4:-}"

  _neticle_check_deps || return 1
  _neticle_check_api_key || return 1

  local url
  url="$(_neticle_url "$path")"
  if [[ -n "$query_string" ]]; then
    url="${url}?${query_string}"
  fi

  # Use temp file for response headers (cross-platform compatible)
  local header_file="/tmp/.neticle_headers_$$"

  local curl_args=(
    -g -s -w "\n%{http_code}"
    -D "$header_file"
    -X "$method"
    -H "$(_neticle_auth_header)"
    -H "X-Requested-With: XMLHttpRequest"
    -H "Content-Type: application/json"
  )

  if [[ -n "$data" && "$method" != "GET" ]]; then
    curl_args+=(-d "$data")
  fi

  if [[ "$NETICLE_DEBUG" == "1" ]]; then
    echo "🔍 DEBUG: $method $url" >&2
    if [[ -n "$data" ]]; then
      echo "🔍 DEBUG: Body: $data" >&2
    fi
  fi

  local response
  response=$(curl "${curl_args[@]}" "$url" 2>&1)

  # Parse response: last line is http_code, everything before is body
  local body http_code
  http_code=$(echo "$response" | tail -n 1)
  body=$(echo "$response" | sed '$d')

  # Extract rate limit info from response headers
  local rate_remaining rate_reset rate_limit
  rate_remaining=$(grep -i '^RateLimit-Remaining:' "$header_file" 2>/dev/null | awk '{print $2}' | tr -d '\r' || echo "")
  rate_reset=$(grep -i '^RateLimit-Reset:' "$header_file" 2>/dev/null | awk '{print $2}' | tr -d '\r' || echo "")
  rate_limit=$(grep -i '^RateLimit-Limit:' "$header_file" 2>/dev/null | awk '{print $2}' | tr -d '\r' || echo "")

  # Always show rate limit info in debug mode
  if [[ "$NETICLE_DEBUG" == "1" && -n "$rate_remaining" ]]; then
    echo "🔍 DEBUG: RateLimit — Remaining: $rate_remaining / $rate_limit, Reset in: ${rate_reset}s" >&2
  fi

  # Rate limit warning (output to stderr for visibility)
  if [[ -n "$rate_remaining" && "$rate_remaining" =~ ^[0-9]+$ ]]; then
    if (( rate_remaining < 100 )); then
      echo "⚠️  Rate limit warning: $rate_remaining/$rate_limit remaining. Resets in ${rate_reset}s." >&2
    fi
    if (( rate_remaining < 10 )); then
      echo "🛑 Rate limit critical! Only $rate_remaining left. Waiting ${rate_reset}s for reset..." >&2
      sleep "$rate_reset"
    fi
  fi

  # Clean up header file
  rm -f "$header_file"

  # Handle HTTP status codes
  case "$http_code" in
    2[0-9][0-9])
      if command -v jq &>/dev/null && echo "$body" | jq . &>/dev/null 2>&1; then
        echo "$body" | jq .
      else
        echo "$body"
      fi
      ;;
    401)
      echo "❌ Error 401: Unauthorized. Check your NETICLE_API_KEY." >&2
      echo "$body" | jq . 2>/dev/null || echo "$body" >&2
      return 1
      ;;
    429)
      local wait_time="${rate_reset:-60}"
      echo "❌ Error 429: Rate limit exceeded. Retry after ${wait_time}s." >&2
      return 1
      ;;
    *)
      echo "❌ Error $http_code:" >&2
      echo "$body" | jq . 2>/dev/null || echo "$body" >&2
      return 1
      ;;
  esac
}

_neticle_get() {
  local path="$1"
  local query_string="${2:-}"
  _neticle_request "GET" "$path" "" "$query_string"
}

_neticle_post() {
  local path="$1"
  local data="${2:-"{}"}"
  local query_string="${3:-}"
  _neticle_request "POST" "$path" "$data" "$query_string"
}

_neticle_patch() {
  local path="$1"
  local data="${2:-"{}"}"
  local query_string="${3:-}"
  _neticle_request "PATCH" "$path" "$data" "$query_string"
}

_neticle_put() {
  local path="$1"
  local data="${2:-"{}"}"
  local query_string="${3:-}"
  _neticle_request "PUT" "$path" "$data" "$query_string"
}

_neticle_delete() {
  local path="$1"
  local data="${2:-}"
  local query_string="${3:-}"
  _neticle_request "DELETE" "$path" "$data" "$query_string"
}

# JSON to query string serializer (for nested objects)
_json_to_query_string() {
  local json="$1"
  python3 -c "
import json, sys, urllib.parse

def flatten(obj, prefix=''):
    params = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            new_key = f'{prefix}[{k}]' if prefix else k
            params.extend(flatten(v, new_key))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            new_key = f'{prefix}[{i}]'
            params.extend(flatten(v, new_key))
    else:
        val = str(obj)
        if isinstance(obj, bool):
            val = 'true' if obj else 'false'
        params.append((prefix, val))
    return params

data = json.loads(sys.argv[1])
pairs = flatten(data)
print('&'.join(f'{k}={urllib.parse.quote(str(v), safe=\"\")}' for k, v in pairs))
" "$json"
}

# =============================================================================
# API FUNCTIONS
# =============================================================================

# --- Connection Test ---------------------------------------------------------

neticle_test_connection() {
  echo "🔗 Testing connection to Neticle API..."
  local result
  if result=$(neticle_list_resources 2>&1); then
    echo "✅ Connection successful!"
    echo "$result" | jq -r '.data | keys[]' 2>/dev/null | head -5 | while read -r key; do
      echo "   📂 Found resource type: $key"
    done
    return 0
  else
    echo "❌ Connection failed!"
    echo "$result" >&2
    return 1
  fi
}

# --- Resources ---------------------------------------------------------------

neticle_list_resources() {
  local filter_json="${1:-"{}"}"
  local qs=""
  if [[ "$filter_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$filter_json")
  fi
  _neticle_get "/resources" "$qs"
}

# --- Mentions ----------------------------------------------------------------

neticle_list_mentions() {
  local params_json="$1"
  local qs
  qs=$(_json_to_query_string "$params_json")
  _neticle_get "/mentions" "$qs"
}

neticle_get_mention() {
  local mention_id="$1"
  local params_json="${2:-"{}"}"
  local qs=""
  if [[ "$params_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$params_json")
  fi
  _neticle_get "/mentions/${mention_id}" "$qs"
}

neticle_create_mention() {
  local body_json="$1"
  _neticle_post "/mentions" "$body_json"
}

neticle_update_mentions() {
  local body_json="$1"
  _neticle_patch "/mentions/update-many" "$body_json"
}

neticle_delete_mentions() {
  local body_json="$1"
  _neticle_delete "/mentions/delete-many" "$body_json"
}

neticle_delete_mention() {
  local mention_id="$1"
  _neticle_delete "/mentions/${mention_id}"
}

neticle_restore_mentions() {
  local body_json="$1"
  _neticle_post "/mentions/restore" "$body_json"
}

# --- Data Feed ---------------------------------------------------------------

neticle_poll_data_feed() {
  local params_json="$1"
  local qs
  qs=$(_json_to_query_string "$params_json")
  _neticle_get "/mentions/data-feed/changes" "$qs"
}

neticle_next_page() {
  local params_json="$1"
  local qs
  qs=$(_json_to_query_string "$params_json")
  _neticle_get "/mentions/data-feed/next-page" "$qs"
}

# Full sync helper: iterates through all pages
neticle_sync_all() {
  local data_source_id="$1"
  local last_mention_id="${2:-}"
  local output_file="${3:-/dev/stdout}"

  local params="{\"dataSourceId\":\"${data_source_id}\""
  if [[ -n "$last_mention_id" ]]; then
    params="${params},\"lastMentionId\":\"${last_mention_id}\""
  fi
  params="${params}}"

  echo "🔄 Starting data feed sync for source: $data_source_id" >&2
  local page=1
  local response next_token

  response=$(neticle_poll_data_feed "$params")
  echo "$response" >> "$output_file"
  next_token=$(echo "$response" | jq -r '.meta.nextPageToken // ""')

  while [[ -n "$next_token" ]]; do
    page=$((page + 1))
    echo "📄 Loading page $page..." >&2
    response=$(neticle_next_page "{\"nextPageToken\":\"${next_token}\"}")
    echo "$response" >> "$output_file"
    next_token=$(echo "$response" | jq -r '.meta.nextPageToken // ""')
  done

  echo "✅ Sync complete. Total pages: $page" >&2
}

# --- Aggregations ------------------------------------------------------------

neticle_get_kpis() {
  local params_json="$1"
  local qs
  qs=$(_json_to_query_string "$params_json")
  _neticle_get "/mentions/aggregation/kpis" "$qs"
}

neticle_get_interactions() {
  local params_json="$1"
  local qs
  qs=$(_json_to_query_string "$params_json")
  _neticle_get "/mentions/aggregation/interactions" "$qs"
}

# --- Charts ------------------------------------------------------------------

neticle_list_chart_templates() {
  local params_json="${1:-"{}"}"
  local qs=""
  if [[ "$params_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$params_json")
  fi
  _neticle_get "/chart-templates" "$qs"
}

neticle_get_chart_template() {
  local template_id="$1"
  _neticle_get "/chart-templates/${template_id}"
}

neticle_get_chart_data() {
  local template_id="$1"
  local params_json="$2"
  local qs
  qs=$(_json_to_query_string "$params_json")
  _neticle_get "/chart-template-data/${template_id}" "$qs"
}

# --- Insights ----------------------------------------------------------------

neticle_list_insights() {
  local params_json="$1"
  local qs
  qs=$(_json_to_query_string "$params_json")
  _neticle_get "/insights" "$qs"
}

# --- Keywords ----------------------------------------------------------------

neticle_list_keywords() {
  local filter_json="${1:-"{}"}"
  local qs=""
  if [[ "$filter_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$filter_json")
  fi
  _neticle_get "/keywords" "$qs"
}

neticle_get_keyword() {
  local keyword_id="$1"
  _neticle_get "/keywords/${keyword_id}"
}

neticle_create_keyword() {
  local body_json="$1"
  local keyword_group_id="$2"
  _neticle_post "/keywords" "$body_json" "keywordGroupId=${keyword_group_id}"
}

neticle_update_keyword() {
  local keyword_id="$1"
  local body_json="$2"
  _neticle_put "/keywords/${keyword_id}" "$body_json"
}

# --- Keyword Groups ----------------------------------------------------------

neticle_list_keyword_groups() {
  local filter_json="${1:-"{}"}"
  local qs=""
  if [[ "$filter_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$filter_json")
  fi
  _neticle_get "/keyword-groups" "$qs"
}

neticle_get_keyword_group() {
  local group_id="$1"
  _neticle_get "/keyword-groups/${group_id}"
}

neticle_create_keyword_group() {
  local body_json="$1"
  _neticle_post "/keyword-groups" "$body_json"
}

neticle_update_keyword_group() {
  local group_id="$1"
  local body_json="$2"
  _neticle_patch "/keyword-groups/${group_id}" "$body_json"
}

# --- Keyword Past Processings ------------------------------------------------

neticle_start_past_processing() {
  local body_json="$1"
  _neticle_post "/keyword-past-processings" "$body_json"
}

# --- Aspects -----------------------------------------------------------------

neticle_list_aspects() {
  local filter_json="${1:-"{}"}"
  local qs=""
  if [[ "$filter_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$filter_json")
  fi
  _neticle_get "/aspects" "$qs"
}

neticle_get_aspect() {
  local aspect_id="$1"
  _neticle_get "/aspects/${aspect_id}"
}

# --- Aspect Groups -----------------------------------------------------------

neticle_list_aspect_groups() {
  local filter_json="${1:-"{}"}"
  local qs=""
  if [[ "$filter_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$filter_json")
  fi
  _neticle_get "/aspect-groups" "$qs"
}

neticle_get_aspect_group() {
  local group_id="$1"
  _neticle_get "/aspect-groups/${group_id}"
}

neticle_create_aspect_group() {
  local body_json="$1"
  local profile_id="$2"
  _neticle_post "/aspect-groups" "$body_json" "profileId=${profile_id}"
}

neticle_update_aspect_group() {
  local group_id="$1"
  local body_json="$2"
  _neticle_patch "/aspect-groups/${group_id}" "$body_json"
}

# --- Own Channels ------------------------------------------------------------

neticle_list_own_channels() {
  local filter_json="${1:-"{}"}"
  local qs=""
  if [[ "$filter_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$filter_json")
  fi
  _neticle_get "/own-channels" "$qs"
}

neticle_get_own_channel() {
  local channel_id="$1"
  _neticle_get "/own-channels/${channel_id}"
}

neticle_create_own_channel() {
  local body_json="$1"
  local keyword_id="$2"
  _neticle_post "/own-channels" "$body_json" "keywordId=${keyword_id}"
}

neticle_delete_own_channel() {
  local channel_id="$1"
  local keyword_id="$2"
  _neticle_delete "/own-channels/${channel_id}" "" "keywordId=${keyword_id}"
}

# --- Keyword Filters ---------------------------------------------------------

neticle_list_keyword_filters() {
  local keyword_id="$1"
  _neticle_get "/keyword-filters" "keywordId=${keyword_id}"
}

neticle_create_keyword_filters() {
  local body_json="$1"
  local keyword_id="$2"
  _neticle_post "/keyword-filters" "$body_json" "keywordId=${keyword_id}"
}

neticle_delete_keyword_filters() {
  local body_json="$1"
  local keyword_id="$2"
  _neticle_delete "/keyword-filters/delete-many" "$body_json" "keywordId=${keyword_id}"
}

# --- Synonyms ----------------------------------------------------------------

neticle_list_synonyms() {
  local keyword_id="${1:-}"
  local aspect_group_id="${2:-}"
  local qs=""
  if [[ -n "$keyword_id" ]]; then
    qs="keywordId=${keyword_id}"
  elif [[ -n "$aspect_group_id" ]]; then
    qs="aspectGroupId=${aspect_group_id}"
  fi
  _neticle_get "/synonyms" "$qs"
}

neticle_create_synonyms() {
  local body_json="$1"
  local keyword_id="${2:-}"
  local aspect_group_id="${3:-}"
  local qs=""
  if [[ -n "$keyword_id" ]]; then
    qs="keywordId=${keyword_id}"
  elif [[ -n "$aspect_group_id" ]]; then
    qs="aspectGroupId=${aspect_group_id}"
  fi
  _neticle_post "/synonyms" "$body_json" "$qs"
}

neticle_delete_synonyms() {
  local body_json="$1"
  local keyword_id="${2:-}"
  local aspect_group_id="${3:-}"
  local qs=""
  if [[ -n "$keyword_id" ]]; then
    qs="keywordId=${keyword_id}"
  elif [[ -n "$aspect_group_id" ]]; then
    qs="aspectGroupId=${aspect_group_id}"
  fi
  _neticle_delete "/synonyms/delete-many" "$body_json" "$qs"
}

# --- Excludes ----------------------------------------------------------------

neticle_list_excludes() {
  local keyword_id="${1:-}"
  local aspect_group_id="${2:-}"
  local qs=""
  if [[ -n "$keyword_id" ]]; then
    qs="keywordId=${keyword_id}"
  elif [[ -n "$aspect_group_id" ]]; then
    qs="aspectGroupId=${aspect_group_id}"
  fi
  _neticle_get "/excludes" "$qs"
}

neticle_create_excludes() {
  local body_json="$1"
  local keyword_id="${2:-}"
  local aspect_group_id="${3:-}"
  local qs=""
  if [[ -n "$keyword_id" ]]; then
    qs="keywordId=${keyword_id}"
  elif [[ -n "$aspect_group_id" ]]; then
    qs="aspectGroupId=${aspect_group_id}"
  fi
  _neticle_post "/excludes" "$body_json" "$qs"
}

neticle_delete_excludes() {
  local body_json="$1"
  local keyword_id="${2:-}"
  local aspect_group_id="${3:-}"
  local qs=""
  if [[ -n "$keyword_id" ]]; then
    qs="keywordId=${keyword_id}"
  elif [[ -n "$aspect_group_id" ]]; then
    qs="aspectGroupId=${aspect_group_id}"
  fi
  _neticle_delete "/excludes/delete-many" "$body_json" "$qs"
}

# --- Suggestions -------------------------------------------------------------

neticle_keyword_filter_suggestions() {
  local keyword_id="$1"
  _neticle_get "/keyword-filters-suggestions" "keywordId=${keyword_id}"
}

neticle_synonym_suggestions() {
  local keyword_id="${1:-}"
  local aspect_group_id="${2:-}"
  local qs=""
  if [[ -n "$keyword_id" ]]; then
    qs="keywordId=${keyword_id}"
  elif [[ -n "$aspect_group_id" ]]; then
    qs="aspectGroupId=${aspect_group_id}"
  fi
  _neticle_get "/synonym-suggestions" "$qs"
}

neticle_exclude_suggestions() {
  local keyword_id="${1:-}"
  local aspect_group_id="${2:-}"
  local qs=""
  if [[ -n "$keyword_id" ]]; then
    qs="keywordId=${keyword_id}"
  elif [[ -n "$aspect_group_id" ]]; then
    qs="aspectGroupId=${aspect_group_id}"
  fi
  _neticle_get "/exclude-suggestions" "$qs"
}

# --- Reference Data ----------------------------------------------------------

neticle_list_sources() {
  _neticle_get "/sources"
}

neticle_list_languages() {
  _neticle_get "/languages"
}

neticle_list_countries() {
  _neticle_get "/countries"
}

neticle_get_country() {
  local country_id="$1"
  _neticle_get "/countries/${country_id}"
}

# --- Clients -----------------------------------------------------------------

neticle_list_clients() {
  _neticle_get "/clients"
}

neticle_get_client() {
  local client_id="$1"
  _neticle_get "/clients/${client_id}"
}

# --- Profiles ----------------------------------------------------------------

neticle_list_profiles() {
  local filter_json="${1:-"{}"}"
  local qs=""
  if [[ "$filter_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$filter_json")
  fi
  _neticle_get "/profiles" "$qs"
}

neticle_get_profile() {
  local profile_id="$1"
  _neticle_get "/profiles/${profile_id}"
}

neticle_create_profile() {
  local body_json="$1"
  _neticle_post "/profiles" "$body_json"
}

neticle_update_profile() {
  local profile_id="$1"
  local body_json="$2"
  _neticle_patch "/profiles/${profile_id}" "$body_json"
}

# --- Users -------------------------------------------------------------------

neticle_create_user() {
  local body_json="$1"
  _neticle_post "/users" "$body_json"
}

# --- Deleted Mention Logs ----------------------------------------------------

neticle_list_deleted_mention_logs() {
  local params_json="${1:-"{}"}"
  local qs=""
  if [[ "$params_json" != "{}" ]]; then
    qs=$(_json_to_query_string "$params_json")
  fi
  _neticle_get "/deleted-mention-logs" "$qs"
}

# =============================================================================
# CLI INTERFACE
# =============================================================================

_neticle_usage() {
  cat <<EOF
Neticle Data API CLI

Usage: $(basename "$0") <command> [args...]

Environment:
  NETICLE_API_KEY       (required) Your API key
  NETICLE_API_VERSION   (optional) API version (default: 24.04)
  NETICLE_DEBUG         (optional) Set to "1" for debug output

Commands:
  test_connection                         Test API connectivity
  list_resources [filter_json]            List all available resources
  list_mentions <params_json>             List mentions with filters
  get_mention <id> [params_json]          Get a single mention
  create_mention <body_json>              Create a mention
  update_mentions <body_json>             Update mention sentiment
  delete_mentions <body_json>             Delete mentions
  delete_mention <id>                     Delete a single mention
  restore_mentions <body_json>            Restore deleted mentions
  poll_data_feed <params_json>            Poll for data feed changes
  next_page <params_json>                 Load next page of data feed
  sync_all <source_id> [last_id] [file]   Full data feed sync
  get_kpis <params_json>                  Get KPI aggregations
  get_interactions <params_json>          Get interaction aggregations
  list_chart_templates [params_json]      List chart templates
  get_chart_template <id>                 Get a chart template
  get_chart_data <id> <params_json>       Get chart data
  list_insights <params_json>             List insights
  list_keywords [filter_json]             List keywords
  get_keyword <id>                        Get a keyword
  create_keyword <body_json> <group_id>   Create a keyword
  update_keyword <id> <body_json>         Update a keyword
  list_keyword_groups [filter_json]       List keyword groups
  get_keyword_group <id>                  Get a keyword group
  create_keyword_group <body_json>        Create a keyword group
  update_keyword_group <id> <body_json>   Update a keyword group
  start_past_processing <body_json>       Start historical processing
  list_aspects [filter_json]              List aspects
  get_aspect <id>                         Get an aspect
  list_aspect_groups [filter_json]        List aspect groups
  get_aspect_group <id>                   Get an aspect group
  create_aspect_group <body> <profile_id> Create an aspect group
  update_aspect_group <id> <body_json>    Update an aspect group
  list_own_channels [filter_json]         List own channels
  get_own_channel <id>                    Get an own channel
  create_own_channel <body> <keyword_id>  Create an own channel
  delete_own_channel <id> <keyword_id>    Delete an own channel
  list_keyword_filters <keyword_id>       List keyword filters
  create_keyword_filters <body> <kw_id>   Create keyword filters
  delete_keyword_filters <body> <kw_id>   Delete keyword filters
  list_synonyms [keyword_id] [ag_id]      List synonyms
  create_synonyms <body> [kw_id] [ag_id]  Create synonyms
  delete_synonyms <body> [kw_id] [ag_id]  Delete synonyms
  list_excludes [keyword_id] [ag_id]      List excludes
  create_excludes <body> [kw_id] [ag_id]  Create excludes
  delete_excludes <body> [kw_id] [ag_id]  Delete excludes
  filter_suggestions <keyword_id>         Get filter suggestions
  synonym_suggestions [kw_id] [ag_id]     Get synonym suggestions
  exclude_suggestions [kw_id] [ag_id]     Get exclude suggestions
  list_sources                            List content sources
  list_languages                          List languages
  list_countries                          List countries
  get_country <id>                        Get a country
  list_clients                            List clients
  get_client <id>                         Get a client
  list_profiles [filter_json]             List profiles
  get_profile <id>                        Get a profile
  create_profile <body_json>              Create a profile
  update_profile <id> <body_json>         Update a profile
  create_user <body_json>                 Create a user
  list_deleted_logs [params_json]         List deleted mention logs

Examples:
  # Test connection
  $(basename "$0") test_connection

  # List all resources
  $(basename "$0") list_resources

  # Query mentions for keyword 10001
  $(basename "$0") list_mentions '{"filters":{"keywords":[10001],"aspects":[]}}'

  # Get KPIs with time interval
  $(basename "$0") get_kpis '{"filters":{"keywords":[10001],"aspects":[],"interval":{"start":1700000000000,"end":1700100000000}}}'

  # Sync all data for a data source
  $(basename "$0") sync_all 10001
EOF
}

# CLI dispatcher
_neticle_main() {
  local cmd="${1:-help}"
  shift 2>/dev/null || true

  case "$cmd" in
    test_connection)         neticle_test_connection ;;
    list_resources)          neticle_list_resources "${1:-"{}"}" ;;
    list_mentions)           neticle_list_mentions "$1" ;;
    get_mention)             neticle_get_mention "$1" "${2:-"{}"}" ;;
    create_mention)          neticle_create_mention "$1" ;;
    update_mentions)         neticle_update_mentions "$1" ;;
    delete_mentions)         neticle_delete_mentions "$1" ;;
    delete_mention)          neticle_delete_mention "$1" ;;
    restore_mentions)        neticle_restore_mentions "$1" ;;
    poll_data_feed)          neticle_poll_data_feed "$1" ;;
    next_page)               neticle_next_page "$1" ;;
    sync_all)                neticle_sync_all "$1" "${2:-}" "${3:-/dev/stdout}" ;;
    get_kpis)                neticle_get_kpis "$1" ;;
    get_interactions)        neticle_get_interactions "$1" ;;
    list_chart_templates)    neticle_list_chart_templates "${1:-"{}"}" ;;
    get_chart_template)      neticle_get_chart_template "$1" ;;
    get_chart_data)          neticle_get_chart_data "$1" "$2" ;;
    list_insights)           neticle_list_insights "$1" ;;
    list_keywords)           neticle_list_keywords "${1:-"{}"}" ;;
    get_keyword)             neticle_get_keyword "$1" ;;
    create_keyword)          neticle_create_keyword "$1" "$2" ;;
    update_keyword)          neticle_update_keyword "$1" "$2" ;;
    list_keyword_groups)     neticle_list_keyword_groups "${1:-"{}"}" ;;
    get_keyword_group)       neticle_get_keyword_group "$1" ;;
    create_keyword_group)    neticle_create_keyword_group "$1" ;;
    update_keyword_group)    neticle_update_keyword_group "$1" "$2" ;;
    start_past_processing)   neticle_start_past_processing "$1" ;;
    list_aspects)            neticle_list_aspects "${1:-"{}"}" ;;
    get_aspect)              neticle_get_aspect "$1" ;;
    list_aspect_groups)      neticle_list_aspect_groups "${1:-"{}"}" ;;
    get_aspect_group)        neticle_get_aspect_group "$1" ;;
    create_aspect_group)     neticle_create_aspect_group "$1" "$2" ;;
    update_aspect_group)     neticle_update_aspect_group "$1" "$2" ;;
    list_own_channels)       neticle_list_own_channels "${1:-"{}"}" ;;
    get_own_channel)         neticle_get_own_channel "$1" ;;
    create_own_channel)      neticle_create_own_channel "$1" "$2" ;;
    delete_own_channel)      neticle_delete_own_channel "$1" "$2" ;;
    list_keyword_filters)    neticle_list_keyword_filters "$1" ;;
    create_keyword_filters)  neticle_create_keyword_filters "$1" "$2" ;;
    delete_keyword_filters)  neticle_delete_keyword_filters "$1" "$2" ;;
    list_synonyms)           neticle_list_synonyms "${1:-}" "${2:-}" ;;
    create_synonyms)         neticle_create_synonyms "$1" "${2:-}" "${3:-}" ;;
    delete_synonyms)         neticle_delete_synonyms "$1" "${2:-}" "${3:-}" ;;
    list_excludes)           neticle_list_excludes "${1:-}" "${2:-}" ;;
    create_excludes)         neticle_create_excludes "$1" "${2:-}" "${3:-}" ;;
    delete_excludes)         neticle_delete_excludes "$1" "${2:-}" "${3:-}" ;;
    filter_suggestions)      neticle_keyword_filter_suggestions "$1" ;;
    synonym_suggestions)     neticle_synonym_suggestions "${1:-}" "${2:-}" ;;
    exclude_suggestions)     neticle_exclude_suggestions "${1:-}" "${2:-}" ;;
    list_sources)            neticle_list_sources ;;
    list_languages)          neticle_list_languages ;;
    list_countries)          neticle_list_countries ;;
    get_country)             neticle_get_country "$1" ;;
    list_clients)            neticle_list_clients ;;
    get_client)              neticle_get_client "$1" ;;
    list_profiles)           neticle_list_profiles "${1:-"{}"}" ;;
    get_profile)             neticle_get_profile "$1" ;;
    create_profile)          neticle_create_profile "$1" ;;
    update_profile)          neticle_update_profile "$1" "$2" ;;
    create_user)             neticle_create_user "$1" ;;
    list_deleted_logs)       neticle_list_deleted_mention_logs "${1:-"{}"}" ;;
    help|--help|-h)          _neticle_usage ;;
    *)
      echo "❌ Unknown command: $cmd" >&2
      echo "Run '$(basename "$0") help' for usage." >&2
      return 1
      ;;
  esac
}

# Run as CLI if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _neticle_main "$@"
fi
