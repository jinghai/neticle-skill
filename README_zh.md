# Neticle Media Intelligence

> [!NOTE]
> 📖 [English Documentation](README.md) | **中文文档**

> 基于 [Neticle Data API](https://data.neticle.com/docs/version/latest) (v24.04) 构建的 AI Agent 技能 — 社交媒体监听、情感分析和媒体情报。

## 简介

此技能使 AI Agent 能够与 Neticle Data API 深度交互，实现：

- 📊 **社交媒体监听** — 跨平台查询与管理提及（Mentions）
- 📈 **情感分析** — 获取带有情感极性得分的 KPI 聚合数据
- 🔄 **数据订阅与同步** — 高效的批量数据流拉取，用于系统集成
- 📉 **图表数据** — 直接获取可采用 Highcharts 渲染的可视化数据
- 💡 **主动洞察** — 获取 AI 生成的分析结论
- ⚙️ **配置管理** — 全面管理关键词、维度、渠道、及各类过滤器

## 快速入门

### 1. 设置您的 API Key

```bash
export NETICLE_API_KEY="您的-api-key"
```

### 2. 测试连通性

```bash
bash scripts/neticle-api.sh test_connection
```

### 3. 发现可用资源

```bash
bash scripts/neticle-api.sh list_resources
```

### 4. 查询提及数据

```bash
bash scripts/neticle-api.sh list_mentions '{"filters":{"keywords":[10001],"aspects":[]}}'
```

## 安装

### 通过 skills.sh (npx) 安装全局技能

如果您正在使用 [skills.sh](https://github.com/qufei1993/skills.sh) 工具集，运行以下命令即可全局安装：

```bash
npx skills add jinghai/neticle-skill
```

### 手动安装给代理

将此仓库克隆到您的 Agent 的技能目录中：

```bash
git clone https://github.com/jinghai/neticle-skill.git ~/.gemini/skills/neticle-skill
```

## 文件结构

```
neticle-skill/
├── SKILL.md                    # 供 AI Agent 阅读的核心指令文件
├── README.md                   # 英文说明
├── README_zh.md                # 中文说明 (本文档)
├── scripts/
│   └── neticle-api.sh          # 核心 API 封装脚本 (包含 40+ 个函数)
├── tests/
│   └── run_tests.sh            # 自动化测试用例
└── references/
    └── api-reference.md        # 结构完整的中文 API 参考手册
```

## 前置依赖

- `curl` — 用于发起 HTTP 请求
- `jq` — JSON 解析与格式化
- `python3` — 用户处理深层嵌套 JSON 到 URL 查询字符串的序列化
- 一个有效的 Neticle API Key

## 版本兼容性与 API 覆盖

**支持的 API 版本：** `24.04` (通过 `NETICLE_API_VERSION` 环境变量可覆盖，默认最新)。

此技能完全实现了对核心业务逻辑的 50+ 个端点覆盖：

| 模块类别 | 端点数量 | 说明 |
|----------|-----------|----|
| 资源发现 (Resources) | 1 | 自动探测可用的各类账号资源 |
| 提及与记录 (Mentions) | 7 | 提供完整的增删改查 (CRUD) 及回收站恢复 |
| 数据同步流 (Data Feed) | 2 | 支持大量流数据的增量分页拉取 (`poll` + `next_page`)及内建同步助手 |
| 聚合指标 (Aggregations) | 2 | KPI 指标及互动量聚合查询 |
| 图表 (Charts) | 3 | 图表模板与源数据抓取 |
| 洞察 (Insights) | 1 | |
| 关键词 (Keywords) | 6 | 包含实体及 Keyword Groups 的完整管理与历史补录 |
| 维度 (Aspects) | 4 | |
| 自有渠道 (Own Channels)| 4 | 支持品牌自营各类内容渠道追踪 |
| 过滤器/同义词/排除 | 9 | 配置数据抓取高精度的各类文本级过滤 |
| 智能辅助 (Suggestions) | 3 | 辅助配置数据抓取的智能词汇建议 |
| 参考数据 (Reference) | 8 | 包含国家、语言、内容源(`sources`)及 Client 结构信息 |
| **总计** | **50+** | 提供极高的自动化数据整合可能 |

## License

MIT 许可证
