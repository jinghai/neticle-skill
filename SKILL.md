---
name: neticle-skill
description: Complete Neticle Data API integration for social media monitoring, sentiment analysis, mention tracking, KPI aggregation, chart data, and insights. Use this skill when the user needs to interact with Neticle's media intelligence platform.
---

# Neticle Media Intelligence Skill

This skill provides complete integration with the **Neticle Data API** — a social media monitoring and data analytics platform. It enables querying mentions, aggregated KPIs, chart data, insights, and managing data collection configurations.

## When to Use This Skill

Use this skill when the user:

- Needs to query social media mentions or sentiment data from Neticle
- Wants to get aggregated KPIs (volume, polarity, reach) for keywords or aspects
- Needs to synchronize mention data between Neticle and another system
- Wants to retrieve chart data or insights from Neticle
- Needs to manage Neticle keywords, aspects, own channels, or filters
- Mentions "Neticle", "media intelligence", "social listening", or "mention monitoring"
- Wants to analyze brand sentiment, social media performance, or online reputation

## Prerequisites

- **API Key**: The user must have a Neticle API key. Set it as:
  ```bash
  export NETICLE_API_KEY="<your-api-key>"
  ```
- **curl** and **jq** must be installed (standard on most systems)

## API Overview

| Item | Value |
|------|-------|
| **Base URL** | `https://data.neticle.com/24.04/` |
| **Auth** | `Authorization: Basic <api-key>` |
| **Rate Limit** | 5,000 requests/hour (API Key protected) |
| **Rate Limit (public)** | 60 requests/minute (same IP) |
| **Timestamps** | UTC, seconds or milliseconds since epoch |
| **Version** | CalVer `24.04` (latest) |

### Rate Limit Headers

Every response includes these headers:
- `RateLimit-Limit` — max allowed queries in the timeframe
- `RateLimit-Remaining` — remaining quota
- `RateLimit-Reset` — seconds until quota resets
- `RateLimit-ResetAt` — timestamp when quota resets

## Resource Hierarchy

Understanding Neticle's hierarchy is essential:

```
Client
└── Profile
    ├── Keyword Group
    │   └── Keyword (data source)
    │       ├── Excludes
    │       ├── Synonyms
    │       ├── Own Channels
    │       └── Keyword Filters
    └── Aspect Group (data source)
        ├── Excludes
        └── Synonyms
```

**Data sources** are Keywords and Aspects (composite of Keyword + Aspect Group). You must specify at least one to query mentions, aggregations, or charts.

## Using the API Script

This skill includes a bash script at `scripts/neticle-api.sh` that wraps all API endpoints.

### Quick Start

```bash
# Set your API key
export NETICLE_API_KEY="your-api-key-here"

# Source the script to use functions directly
source scripts/neticle-api.sh

# Test connection
neticle_test_connection

# List all available resources
neticle_list_resources

# List mentions for a keyword
neticle_list_mentions '{"filters":{"keywords":[10001],"aspects":[]}}'

# Get KPIs
neticle_get_kpis '{"filters":{"keywords":[10001],"aspects":[]}}'
```

### Or run as a CLI

```bash
bash scripts/neticle-api.sh test_connection
bash scripts/neticle-api.sh list_resources
bash scripts/neticle-api.sh list_mentions '{"filters":{"keywords":[10001],"aspects":[]}}'
```

## Complete Endpoint Reference

### 1. Resource Discovery

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/resources` | GET | List all resources (clients, profiles, keywords, aspects, etc.) your API key can access. Supports filtering by `clientId`, `profileId`, `keywordGroupId`, `keywordId`, `aspectGroupId`, `aspectId`. |

**Always start here** to discover available data source IDs for subsequent queries.

### 2. Mentions (Core Data)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/mentions` | GET | List mentions with filters (keywords, aspects, interval, sources, polarities, etc.). Paginated. Designed for one-off queries. |
| `/mentions/:id` | GET | Get a single mention by ID. |
| `/mentions` | POST | Create a mention. Requires `createdAtUtcMs`, `keywordId`, `sourceId`, `text`, `subSourceId`. |
| `/mentions/update-many` | PATCH | Update sentiment (polarity) for multiple mentions. Body: `{"fields":{"polarity":0},"mentionIds":["id1"]}` |
| `/mentions/delete-many` | DELETE | Soft-delete multiple mentions. |
| `/mentions/:id` | DELETE | Delete a single mention. |
| `/mentions/restore` | POST | Restore soft-deleted mentions. |

#### ViewFilter Structure (used by Mentions, Aggregations, Charts, Insights)

```json
{
  "aspects": ["10001_20002"],       // required: string[] (keywordId_aspectGroupId)
  "keywords": [10001, 10002],       // required: number[]
  "interval": {                     // optional
    "start": 1760313600000,         // UTC timestamp (ms or s)
    "end": 1760399999999
  },
  "sources": [1],                   // optional: SourceGroup IDs
  "genders": [1],                   // optional: GenderGroup IDs
  "polarities": [1],                // optional: PolarityGroup IDs
  "filterLanguages": [],            // optional: language IDs
  "excludeLanguages": [],
  "filterCities": [],
  "filterRegions": [],
  "filterOwnChannels": [],
  "filterTags": [],
  "filterPhrases": {"values":[],"matchingType":"contains"},
  "excludePhrases": {"values":[],"matchingType":"contains"}
}
```

#### Mention Presentation (pagination & sorting)

```json
{
  "currentPage": 1,
  "numberOfValues": 100,
  "includeResourceMap": false,
  "order": [{"by": 1, "direction": "desc"}]
}
```

Set `includeResourceMap: true` (or `showRelatedResources: true`) to get human-readable labels for source types, languages, cities, etc. in `meta.relatedResources`.

### 3. Data Feed (Bulk Synchronization)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/mentions/data-feed/changes` | GET | Poll for new mentions in a single data source. Max 1,000 per page. Can only be called once per minute per data source. |
| `/mentions/data-feed/next-page` | GET | Load next page of changes using `nextPageToken`. |

**Sync workflow:**
1. Call `/changes` with `dataSourceId` (keyword or aspect ID), optionally with `lastMentionId`
2. If `meta.nextPageToken` is non-empty, call `/next-page` with that token
3. Repeat until `nextPageToken` is empty
4. Store the last mention's ID for incremental polling

Parameters for `/changes`:
- `dataSourceId` (required): keyword ID (number) or aspect ID (string)
- `lastMentionId` (optional): resume from this point
- `fromTimestamp` (optional): only mentions created after this UTC timestamp
- `withRelatedResources` (optional): include resource labels

### 4. Aggregations

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/mentions/aggregation/kpis` | GET | Get KPIs (volume, polarity scores, reach, etc.) for specified data sources and filters. |
| `/mentions/aggregation/interactions` | GET | Get interaction metrics (likes, comments, shares, etc.) for specified data sources and filters. |

Both endpoints use the same `ViewFilter` structure (see above).

### 5. Charts

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/chart-templates` | GET | List available chart templates (pre-configured visualizations). |
| `/chart-templates/:id` | GET | Get a single chart template. |
| `/chart-template-data/:id` | GET | Get chart data for a template. Override `filters.keywords` or `filters.aspects` to specify data sources. Returns data in Highcharts format. |

### 6. Insights

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/insights` | GET | List insights — automatically generated findings about your data. Requires `filters` with keywords/aspects and a **required** `interval`. |

### 7. Keyword Management

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/keywords` | GET | List keywords. Filter by `clientId`, `profileId`, `keywordGroupId`. |
| `/keywords/:id` | GET | Get a single keyword. |
| `/keywords` | POST | Create a keyword (requires `keywordGroupId`). Body: `{"name":"...","profileId":...}` |
| `/keywords/:id` | PUT | Update a keyword. |
| `/keyword-groups` | GET | List keyword groups. |
| `/keyword-groups/:id` | GET | Get a single keyword group. |
| `/keyword-groups` | POST | Create a keyword group. |
| `/keyword-groups/:id` | PATCH | Update a keyword group. |
| `/keyword-past-processings` | POST | Start historical data processing. Body: `{"keywordIds":[1],"pastProcessingStart":"yyyy-mm-dd","pastProcessingEnd":"yyyy-mm-dd"}`. Max 31-day span. |

### 8. Aspect Management

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/aspects` | GET | List aspects. Aspects = composites of keyword + aspect group. |
| `/aspects/:id` | GET | Get a single aspect. |
| `/aspect-groups` | GET | List aspect groups. |
| `/aspect-groups/:id` | GET | Get a single aspect group. |
| `/aspect-groups` | POST | Create an aspect group (requires `profileId`). |
| `/aspect-groups/:id` | PATCH | Update an aspect group name. |

### 9. Data Collection Configuration

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/own-channels` | GET | List own channels (FB pages, YT channels, etc.). |
| `/own-channels/:id` | GET | Get a single own channel. |
| `/own-channels` | POST | Create an own channel. Requires `keywordId`, body: `{"type":"fb_page","channelId":"..."}` |
| `/own-channels/:id` | DELETE | Delete an own channel. |
| `/keyword-filters` | GET | List keyword filters (required `keywordId`). |
| `/keyword-filters` | POST | Create keyword filters. Body: `{"filters":["word1","word2"]}` |
| `/keyword-filters/delete-many` | DELETE | Delete keyword filters. Body: `{"ids":[1,2]}` |
| `/synonyms` | GET/POST/DELETE | Manage synonyms (same structure as keyword filters). |
| `/excludes` | GET/POST/DELETE | Manage exclude words (same structure as keyword filters). |

### 10. Suggestions

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/keyword-filters-suggestions` | GET | Get filter suggestions for a keyword. |
| `/synonym-suggestions` | GET | Get synonym suggestions. |
| `/exclude-suggestions` | GET | Get exclude word suggestions. |

### 11. Reference Data

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/sources` | GET | List content source types (Facebook, Twitter, blogs, etc.). |
| `/languages` | GET | List available languages. |
| `/countries` | GET | List countries. |
| `/countries/:id` | GET | Get a single country. |
| `/clients` | GET | List clients. |
| `/clients/:id` | GET | Get a single client. |
| `/profiles` | GET | List profiles. |
| `/profiles/:id` | GET | Get a single profile. |
| `/profiles` | POST | Create a profile. |
| `/profiles/:id` | PATCH | Update a profile. |
| `/users` | POST | Create a user. |

### 12. Deleted Mention Logs

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/deleted-mention-logs` | GET | List logs of deleted mentions for audit purposes. |

## Query String Serialization

GET endpoints expect nested objects as URL query strings:

```json
{"filters":{"keywords":[1,2],"interval":{"start":1760313600000,"end":1760399999999}}}
```

Serializes to:
```
filters[keywords][0]=1&filters[keywords][1]=2&filters[interval][start]=1760313600000&filters[interval][end]=1760399999999
```

**Rules:**
- URL-encode individual values only (not the whole string)
- Bracket characters `[` `]` must remain unencoded
- `&` and `=` are structural separators

## Response Format

All endpoints return an `ApiPayload` structure:

```json
{
  "data": { ... },       // The response data
  "meta": {
    "totalCount": 100,
    "currentPage": 1,
    "nextPageToken": "...",
    "relatedResources": { ... }
  },
  "error": null          // Error details if request failed
}
```

## Best Practices

1. **Always start with `/resources`** to discover available keyword and aspect IDs
2. **Use Data Feed for bulk sync**, Mentions endpoint for ad-hoc queries
3. **Handle rate limits gracefully** — check `RateLimit-Remaining` header
4. **Data Feed polling** — call at most once per minute per data source; 5-15 minutes recommended
5. **Interval timestamps** — both start and end are **inclusive**; use milliseconds for precision
6. **Time zones** — all timestamps are UTC; convert local times before querying
7. **Pagination** — default 100 items per page; Data Feed maxes at 1,000
