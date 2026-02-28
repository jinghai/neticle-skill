# Neticle Data API — 完整参考手册

> **API Version:** 24.04 (CalVer)  
> **Base URL:** `https://data.neticle.com/24.04/`  
> **认证:** `Authorization: Basic <api-key>`  
> **文档:** https://data.neticle.com/docs/version/latest

## 目录

1. [通用信息](#通用信息)
2. [资源发现](#资源发现)
3. [提及查询与管理](#提及查询与管理)
4. [数据订阅同步](#数据订阅同步)
5. [聚合分析](#聚合分析)
6. [图表数据](#图表数据)
7. [洞察分析](#洞察分析)
8. [关键词管理](#关键词管理)
9. [维度管理](#维度管理)
10. [数据采集配置](#数据采集配置)
11. [建议](#建议)
12. [参考数据](#参考数据)
13. [通用类型定义](#通用类型定义)

---

## 通用信息

### 认证

所有带 🔒 标记的端点需要认证：

```
Authorization: Basic <api-key>
```

### 限速

| 类型 | 限制 |
|------|------|
| API Key 保护端点 | 5,000 次/小时 |
| 公开端点 | 60 次/分钟(同一IP) |

**响应头：**
```
RateLimit-Limit: <max-queries>
RateLimit-Remaining: <remaining>
RateLimit-Reset: <seconds-to-reset>
RateLimit-ResetAt: <reset-timestamp>
```

### 时间戳

- 所有时间戳为 **UTC**
- 支持秒或毫秒格式
- `interval` 过滤器的 `start` 和 `end` 都是 **inclusive** (包含边界)

### 查询字符串序列化

GET 请求的嵌套对象通过 URL query string 传递：

```
原始 JSON:
{"filters":{"keywords":[1,2]}}

序列化:
filters[keywords][0]=1&filters[keywords][1]=2
```

**规则：**
- 只对各个值进行 URL 编码，不对整个字符串编码
- `[`、`]`、`&`、`=` 作为结构分隔符不编码

### 响应格式

```json
{
  "data": { ... },
  "meta": {
    "totalCount": 100,
    "currentPage": 1,
    "nextPageToken": ""
  },
  "error": null
}
```

---

## 资源发现

### 🔒 GET `/resources` — 列出资源

获取你的 API Key 可访问的所有资源，包括 clients、profiles、keyword groups、keywords、aspect groups 等。

**查询参数（均可选，取最具体的一个）：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `clientId` | number | 按客户过滤 |
| `profileId` | number | 按 profile 过滤 |
| `keywordGroupId` | number | 按关键词组过滤 |
| `aspectGroupId` | number | 按维度组过滤 |
| `keywordId` | number | 按关键词过滤 |
| `aspectId` | string | 按维度过滤 |
| `presentation[showInactive]` | boolean | 是否显示非活跃项 |
| `presentation[showRelatedResources]` | boolean | 是否显示关联资源详情 |

**示例：**
```bash
curl -H "Authorization: Basic <key>" \
  "https://data.neticle.com/24.04/resources?profileId=123"
```

---

## 提及查询与管理

### 🔒 GET `/mentions` — 列出提及

适合一次性查询，不适合大规模数据同步（请用 Data Feed）。

**请求参数：**

| 参数 | 必需 | 类型 | 说明 |
|------|------|------|------|
| `filters` | ✅ | ViewFilter | 过滤条件 |
| `presentation` | ❌ | Presentation | 分页/排序 |

**ViewFilter 完整字段：**

| 字段 | 必需 | 类型 | 说明 |
|------|------|------|------|
| `aspects` | ✅ | string[] | 维度 ID 数组, 格式 "keywordId_aspectGroupId" |
| `keywords` | ✅ | number[] | 关键词 ID 数组 |
| `interval` | ❌ | IntervalFilter | 时间范围 `{start, end}` |
| `sources` | ❌ | SourceGroup[] | 内容源过滤 |
| `genders` | ❌ | GenderGroup[] | 性别过滤 |
| `polarities` | ❌ | PolarityGroup[] | 情感极性过滤 |
| `filterLanguages` | ❌ | number[] | 语言 ID |
| `excludeLanguages` | ❌ | number[] | 排除语言 |
| `filterPersons` | ❌ | number[][] | 人物过滤 |
| `excludePersons` | ❌ | number[][] | 排除人物 |
| `filterCities` | ❌ | number[] | 城市过滤 |
| `filterRegions` | ❌ | number[] | 地区过滤 |
| `excludeRegions` | ❌ | number[] | 排除地区 |
| `excludeCities` | ❌ | number[] | 排除城市 |
| `filterOwnChannels` | ❌ | number[] | 自有渠道 |
| `excludeOwnChannels` | ❌ | number[] | 排除自有渠道 |
| `filterTags` | ❌ | number[][] | 标签过滤 |
| `excludeTags` | ❌ | number[][] | 排除标签 |
| `excludeSources` | ❌ | SourceGroup[] | 排除内容源 |
| `filterPhrases` | ❌ | ConditionFilterDetails | 短语过滤 |
| `excludePhrases` | ❌ | ConditionFilterDetails | 排除短语 |
| `filterTitles` | ❌ | ConditionFilterDetails | 标题过滤 |
| `excludeTitles` | ❌ | ConditionFilterDetails | 排除标题 |

**Presentation 字段：**

| 字段 | 默认值 | 类型 | 说明 |
|------|--------|------|------|
| `currentPage` | 1 | number | 当前页码 |
| `numberOfValues` | 100 | number | 每页数量 |
| `includeResourceMap` | false | boolean | 包含资源映射标签 |
| `order` | `[{"by":1,"direction":"desc"}]` | Order[] | 排序规则 |

**示例：**
```bash
curl -H "Authorization: Basic <key>" \
  "https://data.neticle.com/24.04/mentions?filters[keywords][0]=10001&filters[aspects][0]=10001_20002"
```

### 🔒 GET `/mentions/:id` — 获取单条提及

### 🔒 POST `/mentions` — 创建提及

**请求体：**

| 字段 | 必需 | 类型 | 说明 |
|------|------|------|------|
| `createdAtUtcMs` | ✅ | number | 创建时间(UTC毫秒) |
| `keywordId` | ✅ | number | 关键词ID |
| `sourceId` | ✅ | Source | 来源ID |
| `text` | ✅ | string | 提及内容 |
| `subSourceId` | ✅ | SubSource | 子来源ID |
| `url` | ❌ | string | 原始URL |
| `author` | ❌ | string | 作者 |
| `title` | ❌ | string | 标题 |
| `reach` | ❌ | number | 触达人数 |
| `likes` | ❌ | number | 点赞数 |
| `comments` | ❌ | number | 评论数 |
| `shares` | ❌ | number | 分享数 |

### 🔒 PATCH `/mentions/update-many` — 更新情感

```json
{
  "fields": {"polarity": 0},
  "mentionIds": ["mention-id-1", "mention-id-2"]
}
```

### 🔒 DELETE `/mentions/delete-many` — 批量删除

### 🔒 DELETE `/mentions/:id` — 单条删除

### 🔒 POST `/mentions/restore` — 恢复删除

---

## 数据订阅同步

### 🔒 GET `/mentions/data-feed/changes` — 轮询变更

用于批量同步的首选端点。每次请求返回最多 1,000 条。**每个数据源每分钟只能调用一次**。

| 参数 | 必需 | 类型 | 说明 |
|------|------|------|------|
| `dataSourceId` | ✅ | string/number | 数据源(关键词/维度ID) |
| `lastMentionId` | ❌ | string | 上次同步的最后一条提及ID |
| `fromTimestamp` | ❌ | number | 只返回此时间之后创建的提及 |
| `withRelatedResources` | ❌ | boolean | 是否包含资源标签 |

### 🔒 GET `/mentions/data-feed/next-page` — 加载下一页

| 参数 | 必需 | 类型 | 说明 |
|------|------|------|------|
| `nextPageToken` | ✅ | string | 上一响应中的 nextPageToken |

**同步流程：**
1. 调用 `/changes`（不带 `lastMentionId` = 从头开始）
2. 如果 `meta.nextPageToken` 非空，调用 `/next-page`
3. 循环直到 `nextPageToken` 为空
4. 保存最后一条提及 ID，下次从此处继续

---

## 聚合分析

### 🔒 GET `/mentions/aggregation/kpis` — KPI 聚合

返回声量、情感极性评分、触达等核心 KPI。

| 参数 | 必需 | 类型 |
|------|------|------|
| `filters` | ✅ | ViewFilter |

### 🔒 GET `/mentions/aggregation/interactions` — 互动聚合

返回点赞、评论、分享等互动指标。

| 参数 | 必需 | 类型 |
|------|------|------|
| `filters` | ✅ | ViewFilter |

---

## 图表数据

### 🔒 GET `/chart-templates` — 列出图表模板

返回预配置的图表模板列表（如"负面作者"、"正面作者"等）。

### 🔒 GET `/chart-templates/:id` — 获取模板详情

### 🔒 GET `/chart-template-data/:id` — 获取图表数据

| 参数 | 必需 | 类型 | 说明 |
|------|------|------|------|
| `filters` | ✅ | ViewFilter | 必须覆盖 keywords 或 aspects |
| `presentation` | ❌ | ChartPresentation | 图表展示选项 |

返回 **Highcharts** 格式的数据。

---

## 洞察分析

### 🔒 GET `/insights` — 列出洞察

| 参数 | 必需 | 类型 |
|------|------|------|
| `filters` | ✅ | InsightViewFilter (keywords + aspects + **require interval**) |
| `presentation` | ❌ | InsightPresentation |

**注意：** Insights 的 `interval` 是 **必需** 的。

---

## 关键词管理

| 端点 | 方法 | 说明 |
|------|------|------|
| `/keywords` | GET | 列出关键词 |
| `/keywords/:id` | GET | 获取单个关键词 |
| `/keywords` | POST | 创建关键词 (需 `keywordGroupId` 查询参数) |
| `/keywords/:id` | PUT | 更新关键词 |
| `/keyword-groups` | GET | 列出关键词组 |
| `/keyword-groups/:id` | GET | 获取单个关键词组 |
| `/keyword-groups` | POST | 创建关键词组 |
| `/keyword-groups/:id` | PATCH | 更新关键词组 |
| `/keyword-past-processings` | POST | 启动历史数据补采 (最大31天) |

---

## 维度管理

| 端点 | 方法 | 说明 |
|------|------|------|
| `/aspects` | GET | 列出维度 |
| `/aspects/:id` | GET | 获取单个维度 |
| `/aspect-groups` | GET | 列出维度组 |
| `/aspect-groups/:id` | GET | 获取单个维度组 |
| `/aspect-groups` | POST | 创建维度组 (需 `profileId`) |
| `/aspect-groups/:id` | PATCH | 更新维度组 |

---

## 数据采集配置

### 自有渠道

| 端点 | 方法 | 说明 |
|------|------|------|
| `/own-channels` | GET | 列出渠道 |
| `/own-channels/:id` | GET | 获取单个渠道 |
| `/own-channels` | POST | 创建渠道 (需 `keywordId`, body: `{type, channelId}`) |
| `/own-channels/:id` | DELETE | 删除渠道 |

**渠道类型 (type):** `fb_page`, `google_location`, `yt_channel` 等。

### 关键词过滤器

| 端点 | 方法 | 说明 |
|------|------|------|
| `/keyword-filters` | GET | 列出 (需 `keywordId`) |
| `/keyword-filters` | POST | 创建: `{"filters":["word1","word2"]}` |
| `/keyword-filters/delete-many` | DELETE | 删除: `{"ids":[1,2]}` |

### 同义词 & 排除词

结构与关键词过滤器相同，支持 `keywordId` 或 `aspectGroupId`。

| 端点 | 方法 |
|------|------|
| `/synonyms` | GET/POST/DELETE |
| `/synonyms/delete-many` | DELETE |
| `/excludes` | GET/POST/DELETE |
| `/excludes/delete-many` | DELETE |

---

## 建议

| 端点 | 方法 | 说明 |
|------|------|------|
| `/keyword-filters-suggestions` | GET | 过滤词建议 (需 `keywordId`) |
| `/synonym-suggestions` | GET | 同义词建议 (keywordId 或 aspectGroupId) |
| `/exclude-suggestions` | GET | 排除词建议 (keywordId 或 aspectGroupId) |

---

## 参考数据

| 端点 | 方法 | 说明 |
|------|------|------|
| `/sources` | GET | 内容源类型列表 |
| `/languages` | GET | 语言列表 |
| `/countries` | GET | 国家列表 |
| `/countries/:id` | GET | 单个国家 |
| `/clients` | GET | 客户列表 |
| `/clients/:id` | GET | 单个客户 |
| `/profiles` | GET/POST | 列出/创建 profile |
| `/profiles/:id` | GET/PATCH | 获取/更新 profile |
| `/users` | POST | 创建用户 |
| `/deleted-mention-logs` | GET | 删除提及审计日志 |

---

## 通用类型定义

### IntervalFilter

```json
{
  "start": 1760313600000,  // UTC 毫秒 (inclusive)
  "end": 1760399999999     // UTC 毫秒 (inclusive)
}
```

### SourceGroup

数字 ID, 通过 `/sources` 端点获取可用值。

### GenderGroup

数字 ID, 用于按性别过滤。

### PolarityGroup

数字 ID, 用于按情感极性过滤。

### ConditionFilterDetails

```json
{
  "values": ["word1", "word2"],
  "matchingType": "contains"  // 或 "exact" 等
}
```

### ApiPayload (响应)

```json
{
  "data": { ... },
  "meta": {
    "totalCount": 100,
    "currentPage": 1,
    "nextPageToken": "",
    "relatedResources": { ... }
  },
  "error": null
}
```
