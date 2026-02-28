# Neticle Skill

> [!NOTE]
> **English Documentation** | [中文文档](README_zh.md)

> AI Agent Skill for the [Neticle Data API](https://data.neticle.com/docs/version/latest) (v24.04) — social media monitoring, sentiment analysis, and media intelligence.

## Overview

This skill enables AI coding agents to interact with the Neticle Data API for:

- 📊 **Social Media Monitoring** — Query and manage mentions across social platforms
- 📈 **Sentiment Analysis** — Get KPI aggregations with polarity scores
- 🔄 **Data Synchronization** — Efficient bulk data feed for system integration
- 📉 **Chart Data** — Retrieve visualization-ready data in Highcharts format
- 💡 **Insights** — AI-generated analytics findings
- ⚙️ **Configuration** — Manage keywords, aspects, channels, filters

## Quick Start

### 1. Set your API Key

```bash
export NETICLE_API_KEY="your-api-key-here"
```

### 2. Test Connection

```bash
bash scripts/neticle-api.sh test_connection
```

### 3. Discover Resources

```bash
bash scripts/neticle-api.sh list_resources
```

### 4. Query Mentions

```bash
bash scripts/neticle-api.sh list_mentions '{"filters":{"keywords":[10001],"aspects":[]}}'
```

## Installation

### Via skills.sh (npx)

```bash
npx skills add <owner>/neticle-skill
```

### Manual

Clone this repository into your agent's skills directory:

```bash
git clone <repo-url> ~/.gemini/skills/neticle-skill
```

## File Structure

```
neticle-skill/
├── SKILL.md                    # Skill instructions for AI agents
├── README.md                   # This file
├── scripts/
│   └── neticle-api.sh          # API wrapper script (40+ functions)
└── references/
    └── api-reference.md        # Complete API reference
```

## Requirements

- `curl` — HTTP requests
- `jq` — JSON processing
- `python3` — Query string serialization
- A valid Neticle API key

## API Coverage

| Category | Endpoints |
|----------|-----------|
| Resources | 1 |
| Mentions | 7 (CRUD + restore) |
| Data Feed | 2 (poll + next page) + sync helper |
| Aggregations | 2 (KPIs + interactions) |
| Charts | 3 (templates + data) |
| Insights | 1 |
| Keywords | 6 (CRUD + groups + past processing) |
| Aspects | 4 (read + groups CRUD) |
| Own Channels | 4 (CRUD) |
| Filters/Synonyms/Excludes | 9 |
| Suggestions | 3 |
| Reference Data | 8 (sources, languages, countries, clients, profiles, users) |
| **Total** | **50+** |

## License

MIT
