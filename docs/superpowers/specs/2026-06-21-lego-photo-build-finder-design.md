# LEGO 拍照搭建助手 — 设计文档

**日期**：2026-06-21
**状态**：Design (待 writing-plans 转 implementation plan)

## 1. 概要

一个跨端移动 App，让用户拍下自己的乐高（含三方兼容砖）零件堆，自动识别成结构化清单，再
根据清单从作品数据库里找出"用这些件能搭出来的东西"，并把对应的官方/社区搭建说明指引给
用户。MVP 不生成原创搭建步骤、不内嵌他人的说明书，而是以**导购式**体验把用户带到说明书原
出处（Rebrickable / LEGO 官网等）。

### 目标用户

- 主要：中文家庭用户，桌上有一堆混合乐高，不知道还能拼什么
- 次要：英文乐高爱好者，使用 Rebrickable 等社区资源

### 成功标准（MVP）

1. 拍一张混堆照片 → 出零件清单（≥80% 件可正确识别+计数，配合手动校正后达 100%）
2. 清单 → 至少能匹配出一组"完全可搭"或"差几颗能搭"的作品
3. 中文用户能看到作品名、描述、关键技术点的中文译文
4. 不登录即可使用，可手动导出/导入数据备份

## 2. 关键产品决策（已通过 brainstorming 确认）

| # | 维度 | 决策 |
|---|---|---|
| 1 | 生成方式 | 库优先 + LLM 文案补充（**不**真生成新作品） |
| 2 | 识别粒度 | 详细清单（形状 + 颜色 + 数量） |
| 3 | 识别方案 | Brickognize API 为主 + 手动校正 UI 兜底 |
| 4 | 作品库 | Rebrickable API |
| 5 | 落地形态 | Flutter 跨端 |
| 6 | 拍照方式 | 一张混堆 + 渐进式补拍 + 必备手动校正 |
| 7 | 匹配严格度 | 默认 100% 严格 + 一键展开"差 ≤5 种件"；阈值在设置页可调（默认 5，范围 1–10） |
| 8 | 说明书呈现 | 仅跳转外站；LLM 只翻译作品名/描述/技术点 |
| 9 | 空结果兜底 | 合一页：差几颗能搭 + 重识别/补拍/改清单，按总件数软提示 |
| 10 | 账号 | 无账号；本地存储 + 手动导出/导入 JSON 文件 |
| 11 | LLM | DeepSeek（性价比与长文本表现），通义/智谱备选 |
| 12 | 前端框架 | Flutter |
| 13 | 后端 | FastAPI 单体；隐藏 API Key、缓存与限流 |
| 14 | i18n | 中文优先 + 英文，全 UI 国际化 |

## 3. 总体架构

### 3.1 系统视图

```
┌──────────────────────────────────────────────────────────────┐
│                         Flutter App                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │ Camera   │  │ Inventory│  │ Build    │  │ Settings   │  │
│  │ Capture  │  │ Editor   │  │ Browser  │  │ /Backup    │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────┬──────┘  │
│       └────────────┴──────┬───────┴──────────────┘          │
│                ┌──────────▼──────────┐                      │
│                │  Local Repository   │                      │
│                │  (SQLite + Files)   │                      │
│                └──────────┬──────────┘                      │
│                ┌──────────▼──────────┐                      │
│                │   API Client        │                      │
│                └──────────┬──────────┘                      │
└───────────────────────────┼─────────────────────────────────┘
                            │ HTTPS (JSON / multipart)
┌───────────────────────────▼─────────────────────────────────┐
│                  BrickFinder Backend (FastAPI)              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Routes: /recognize  /builds  /translate  /health   │    │
│  └────┬──────────────┬───────────────┬─────────────────┘    │
│       ▼              ▼               ▼                      │
│  ┌─────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │Recognize│  │Build-Matcher│  │ Translator  │              │
│  │ Service │  │   Service   │  │   Service   │              │
│  └────┬────┘  └──────┬──────┘  └──────┬──────┘              │
│       └──────────────┴────────┬───────┘                     │
│                ┌──────────────▼─────────────┐               │
│                │  Cache Layer (Redis)       │               │
│                └──────────────┬─────────────┘               │
│                ┌──────────────▼─────────────┐               │
│                │   Postgres (stats/quota)   │               │
│                └────────────────────────────┘               │
└──────────┬────────────────┬───────────────┬─────────────────┘
           ▼                ▼               ▼
     Brickognize       Rebrickable       DeepSeek
        API              API              API
```

### 3.2 模块清单（一句话职责）

**Flutter 侧**

- **Camera Capture**：调相机/相册、压缩图像（最大 1600px 长边）、上传识别
- **Inventory Editor**：展示零件清单、增删改、补拍、合并
- **Build Browser**：作品列表、严格/宽松切换、跳转外站、查看缺件
- **Settings/Backup**：语言切换、导出导入 JSON、清缓存
- **Local Repository**：唯一数据出入口；上层组件不直接碰 SQLite
- **API Client**：统一封装后端调用、重试、错误归一化

**后端侧**

- **Recognize Service**：把图扔给 Brickognize → 归一化结果 → 缓存
- **Build-Matcher Service**：把零件清单交给 Rebrickable 的 `/parts/lists/build/` → 处理严格/宽松两种模式 → 缓存
- **Translator Service**：调 DeepSeek 做作品名/描述/技术点翻译 → 永久缓存
- **Cache Layer**：图片 hash / 清单 hash / 原文 hash → 结果
- **Quota/Stats**：按 IP + 设备指纹限流、记录调用次数；不存用户业务数据

### 3.3 模块边界原则

- **Local Repository 是 Flutter 侧的"数据库门面"**：上层 UI 不直接写 SQL。换成云备份时只换这一层。
- **后端三个 Service 互不调用**：上层路由层做编排。这样 Recognize 坏了不会带垮 Build-Matcher。
- **API Client 把三方错误归一化成统一错误码**：Brickognize 5xx、Rebrickable 限流、DeepSeek 429 在前端看到的都是统一格式。

## 4. 数据模型

### 4.1 Flutter 本地 SQLite Schema

```sql
-- 一次"识别会话"：一张/多张照片 → 合并出的零件清单
CREATE TABLE inventory_session (
  id              TEXT PRIMARY KEY,          -- UUID v4
  name            TEXT,                       -- 用户自起名，默认 "2026-06-21 收纳盒"
  created_at      INTEGER NOT NULL,           -- unix ms
  updated_at      INTEGER NOT NULL,
  thumbnail_path  TEXT                        -- 首张照片缩略图
);

-- 该 session 下的零件清单（用户改过后保存的最终态）
CREATE TABLE inventory_part (
  session_id      TEXT NOT NULL REFERENCES inventory_session(id) ON DELETE CASCADE,
  part_num        TEXT NOT NULL,              -- Rebrickable 件号，如 "3001"
  color_id        INTEGER NOT NULL,           -- Rebrickable 颜色 ID，-1 表示未知
  quantity        INTEGER NOT NULL,
  source          TEXT NOT NULL,              -- 'recognized' | 'manual' | 'edited'
  confidence      REAL,                       -- 0~1，识别置信度；manual 时为 NULL
  PRIMARY KEY (session_id, part_num, color_id)
);

-- 每张原始照片（用于补拍合并、二次识别）
CREATE TABLE inventory_photo (
  id               TEXT PRIMARY KEY,
  session_id       TEXT NOT NULL REFERENCES inventory_session(id) ON DELETE CASCADE,
  file_path        TEXT NOT NULL,             -- app 沙盒内路径
  uploaded_at      INTEGER NOT NULL,
  recognize_status TEXT NOT NULL              -- 'pending' | 'done' | 'failed'
);

-- 收藏的作品（用户点了"收藏"或"想搭"）
CREATE TABLE favorite_build (
  set_or_moc_id   TEXT PRIMARY KEY,           -- 形如 "set:75300" 或 "moc:178492"
  title_zh        TEXT,                       -- LLM 翻译后的标题
  title_orig      TEXT,
  thumbnail_url   TEXT,
  source_url      TEXT NOT NULL,              -- 跳转外站的 URL
  saved_at        INTEGER NOT NULL,
  session_id      TEXT                        -- 收藏时所属的清单 (可空)
);

-- 设置项
CREATE TABLE app_setting (
  key             TEXT PRIMARY KEY,
  value           TEXT
);
```

### 4.2 后端 Postgres Schema

后端**不存用户业务数据**——只存统计 / 限流 / 缓存兜底。

```sql
-- 限流：按 IP 和设备指纹聚合调用次数
CREATE TABLE rate_quota (
  client_key      TEXT PRIMARY KEY,           -- "ip:1.2.3.4" 或 "dev:<uuid>"
  recognize_count INT NOT NULL DEFAULT 0,
  match_count     INT NOT NULL DEFAULT 0,
  translate_count INT NOT NULL DEFAULT 0,
  window_start    TIMESTAMPTZ NOT NULL        -- 滚动窗口起点
);

-- 调用日志（聚合用于监控，不存 PII）
CREATE TABLE api_call_log (
  id              BIGSERIAL PRIMARY KEY,
  ts              TIMESTAMPTZ NOT NULL DEFAULT now(),
  route           TEXT NOT NULL,              -- 'recognize' | 'builds' | 'translate'
  cache_hit       BOOLEAN NOT NULL,
  upstream_status INT,                        -- 三方 API 的 HTTP 码
  latency_ms      INT
);
```

### 4.3 Redis 缓存键

```
recog:img:<sha256>           → JSON 零件清单     TTL=7d
match:strict:<sha256>        → JSON 作品列表     TTL=30d
match:loose5:<sha256>        → JSON 作品列表     TTL=30d
trans:zh:<sha256>            → 中文译文          永久 (无 TTL)
trans:en:<sha256>            → 英文译文          永久
```

`<sha256>` 是输入 hash（图片字节 / 清单 JSON / 原文文本）。MVP 预估缓存命中率 30–50%：
识别图基本不重复，匹配结果和翻译重复多。

### 4.4 备份导出文件格式（JSON）

```json
{
  "version": 1,
  "exported_at": "2026-06-21T10:00:00Z",
  "sessions": [
    { "...inventory_session + 内嵌 parts + photos元数据(不含图片bytes)..." }
  ],
  "favorites": [ { "..." } ],
  "settings": { "lang": "zh", "loose_threshold": 5 }
}
```

**重要决策**：导出不含照片 bytes（避免文件过大），只含识别后的零件清单。这意味着导入后
照片不在，但清单完整——用户拿来"换机继续看作品"完全够。

### 4.5 数据保留策略

- Flutter 本地：用户手动删，否则不动
- 后端 Redis：靠 TTL 自动清
- 后端 Postgres：`api_call_log` 保留 30 天滚动清理；`rate_quota` 窗口外清零
- **关键：后端不落盘任何用户上传的图片**——FastAPI 用 `UploadFile` 的内存模式，识别完即释放

## 5. 核心数据流

### 5.1 流程一：拍照识别 → 出零件清单

```
[Flutter Camera Capture]
    │ 1. 用户拍照 / 选图
    │ 2. 本地压缩 (longEdge=1600, JPEG q=85)
    │ 3. 创建/打开 inventory_session，写入 inventory_photo (status=pending)
    │
    ├─► POST /v1/recognize  (multipart, image)
    │
[Backend Recognize Service]
    │ 4. 计算图片 SHA256
    │ 5. Redis: GET recog:img:<sha256>
    │    └─ 命中 ──► 直接返回缓存 (cache_hit=true)
    │ 6. 调 Brickognize: POST /predict/parts/
    │    └─ 失败 → 重试 1 次 → 仍失败返回 {code: "RECOGNIZE_UPSTREAM", parts: []}
    │ 7. 归一化: brickognize.item → {part_num, color_id, quantity, confidence}
    │    └─ Brickognize 返回的 part_id 直接是 Rebrickable 件号；颜色名 → 颜色 ID 查表
    │    └─ 同 (part_num, color_id) 合并 quantity
    │ 8. Redis: SET recog:img:<sha256> (TTL=7d)
    │ 9. 写 api_call_log; rate_quota 累加
    │
    ├─◄ 200 {parts: [...], confidence_low_regions: [...]}
    │
[Flutter API Client → Local Repo]
    │ 10. inventory_photo.status = done
    │ 11. 合并到 inventory_part (source=recognized)
    │     ├─ 同 (part_num, color_id) 存在 → quantity 相加
    │     └─ 新件 → 插入
    │
[Inventory Editor]
    │ 12. 展示清单；置信度 < 0.6 的件加 ⚠️ 角标
    │ 13. 顶部 Banner：识别到 X 件 [✓确认] [📷 补拍] [✏️ 手动加]
```

**关键设计点**：

- 客户端压缩到 1600px：Brickognize 对 >2000px 的图准确率反而下降，且省上传流量
- 同件合并发生**两次**：后端一次（同一张图内）、本地一次（多张图合并到同一 session）
- 后端**不落盘**用户图片
- "补拍"不是重做识别，而是**追加**：新照片识别结果直接 merge 进同一 `inventory_part`

### 5.2 流程二：清单 → 可搭作品列表

```
[Build Browser opens for a session]
    │ 1. 从 inventory_part 取该 session 全部件，序列化成清单 JSON
    │    └─ 排序后再 hash，保证同清单 → 同 cache key
    │
    ├─► POST /v1/builds {parts:[...], mode:"strict", loose_threshold:5}
    │
[Backend Build-Matcher]
    │ 2. 算 parts JSON sha256
    │ 3. Redis GET match:strict:<sha256>  (mode=strict 时只查 strict)
    │    └─ 命中 → 直返
    │ 4. 调 Rebrickable: POST /api/v3/lego/parts/lists/build/
    │    └─ 参数: part_list, missing_parts=0
    │ 5. 解析返回的 sets/MOCs 列表，每条提取
    │    {id, type, title, thumb, source_url, designer}
    │ 6. mode == "loose": 第二次调 Rebrickable, missing_parts=5
    │    └─ 在结果上标 missing_count, missing_parts:[...]
    │    └─ 用 setOf(loose) - setOf(strict) 得到纯 loose 列表
    │ 7. Redis SET match:strict... / match:loose5...
    │
    ├─◄ 200 {strict:[...], loose:[...], counts}
    │
[Flutter Build Browser]
    │ 8. 默认展示 strict 列表
    │ 9. 顶部按钮 [还差几颗也能搭的(X个)] → 折叠区展开 loose
    │ 10. strict 为空且 loose 为空 → 零结果合一页:
    │     ├─ 若 inventory.totalQty < 80 → 文案侧重"建议补拍"
    │     └─ 若 inventory.totalQty ≥ 80 → 文案侧重"看差几颗也能搭"
```

**关键设计点**：

- **客户端发送清单时排序**（按 `part_num, color_id` 字典序）——这样 "12 红 + 5 蓝"
  和 "5 蓝 + 12 红" 命中同一个 cache key
- Rebrickable 的 `missing_parts` 参数是"允许总共缺多少种件"，UI 文案上表述为"缺 X 种件"
- 严格和宽松**两次调用**：Rebrickable 没法一次取两套结果；靠 Redis 30 天缓存兜底

### 5.3 流程三：作品详情中文化（按需调用 LLM）

```
[用户点击一个作品卡片]
    │
    ├─► POST /v1/translate {target:"zh", items:[
    │     {id:"moc:178492", title:"Cyberpunk Mecha", desc:"...", techniques:"..."}
    │  ]}
    │
[Backend Translator]
    │ 1. 对每个字段算 sha256 → Redis GET trans:zh:<sha256>
    │ 2. 全部命中 → 直返
    │ 3. 未命中字段批量送 DeepSeek (一次调用最多 20 条)
    │    └─ Prompt: 系统提示"你是 Lego 术语翻译专家", user 消息是 JSON 数组
    │    └─ 强制返回 JSON Schema, 失败重试 1 次
    │ 4. 写回缓存 (永久 TTL); 计入 translate_count
    │
    ├─◄ 200 {translations: {moc:178492: {title_zh, desc_zh, techniques_zh}}}
    │
[Flutter]
    │ 5. 详情页用译文渲染；旁边小字"原文/Original"可切回
```

**关键设计点**：

- **按需调用而非批量预译**：作品页点开才译
- **永久缓存**：同一作品的同一字段全网用户共享同一份译文
- 跳转外站时**只跳转**，不抓取页面内容做二次加工（合规边界）

## 6. 错误处理 & 边界场景

### 6.1 错误归一化

后端把所有异常归到 5 类，前端按类显示不同 UI，不暴露三方 API 细节：

| code | 含义 | HTTP | 前端表现 |
|---|---|---|---|
| `INVALID_INPUT` | 图片格式 / 大小 / 参数错 | 400 | 弹窗"图片有问题，请重选" |
| `UPSTREAM_TIMEOUT` | Brickognize / Rebrickable / DeepSeek 超时 | 504 | Toast"网络慢，再试一次" + 重试按钮 |
| `UPSTREAM_ERROR` | 三方 5xx 或返回异常数据 | 502 | Toast"识别服务暂时不可用" |
| `RATE_LIMITED` | 我们的限流或三方限流 | 429 | Banner"今天用得有点多，过会儿再来" + 重置时间 |
| `INTERNAL` | 后端自己 bug | 500 | Toast"出错了，已记录" |

前端**永远不显示原始堆栈 / HTTP 码**，只显示 code 对应文案。

### 6.2 各场景的具体处理

**识别相关**

| 场景 | 处理 |
|---|---|
| Brickognize 返回空数组 | 200 + `parts:[]`；前端提示"没认出来，光线太暗？换个角度试试"，给"手动添加"入口 |
| Brickognize 单次超时 | 重试 1 次（指数退避 1s） |
| Brickognize 连续失败 | 返回 `UPSTREAM_ERROR`；Toast + 保留 photo 记录 (`status=failed`)，**允许用户重试** |
| 图片 > 10MB | `INVALID_INPUT`（客户端已压缩，正常不会到） |
| Brickognize 返回的 part_num 不在 Rebrickable 件库 | 仍然透传，颜色名转 ID 失败时 `color_id=-1`；清单展示"未知件 ⚠️"，可手动改 |

**匹配相关**

| 场景 | 处理 |
|---|---|
| 清单为空就请求匹配 | 客户端拦截，提示"请先添加件" |
| Rebrickable 限流 (429) | 返回 `RATE_LIMITED`，透传上游 header 的 reset 时间 |
| Rebrickable 返回上千个结果 | 客户端只展示前 50，无限滚动加载更多 |
| 严格 + 宽松都返回 [] | 走"零结果合一页" UX 分支 |

**翻译相关**

| 场景 | 处理 |
|---|---|
| DeepSeek 返回非 JSON | 重试 1 次；仍失败 → **降级为原文** + 在该字段打小标"未译" |
| 用户语言是英文 | 跳过翻译，直接用原文（Rebrickable 本就是英文） |
| 单字段超长 (>2000 字符) | 截断到 2000 + 省略号 |

**离线 / 网络**

| 场景 | 处理 |
|---|---|
| 完全无网 | 前端检测后只读模式：已有 session / 清单可看，识别和匹配按钮置灰；右上 Banner"离线" |
| 弱网 / 慢 | 所有 API 调用有进度 UI；识别超过 15s 显示"还在努力识别…"；30s 硬超时报 `UPSTREAM_TIMEOUT` |
| 上传中切后台 | 取消请求（不做后台续传，MVP 不必要） |

**数据一致性**

| 场景 | 处理 |
|---|---|
| 用户手动改清单后立即点匹配 | 用本地最新清单算 hash，自然命中新 cache（旧的也保留，互不影响） |
| 同件被识别和手动各加一次 | merge 时按 `(part_num,color_id)` 累加 quantity；`source` 字段优先级 `edited > manual > recognized`（仅作展示用） |
| 导入 JSON 冲突 | 新建 session 而非合并，避免覆盖现有数据。文件来源 session 如果 id 已存在，给新 id |
| 删除 session | 级联删 `inventory_part` 和 `inventory_photo`（含磁盘文件） |

### 6.3 后端自保护

- **请求大小限制**：图片上传最大 8MB（客户端压完通常 200–500KB）
- **限流**：每个 client_key 每天 recognize=100 / builds=500 / translate=2000；超出返回 `RATE_LIMITED`
- **超时**：Brickognize 30s / Rebrickable 15s / DeepSeek 20s；整体请求超时 60s
- **断路器**：某个上游连续失败 10 次 → 30 秒内直接返回 `UPSTREAM_ERROR` 不打三方，防止雪崩

### 6.4 Crash & 日志

- Flutter 端：Sentry 收集 crash（不上传图片，只上调用链）
- 后端：结构化日志 → 写 stdout，由部署平台聚合
- **不记录**：用户照片、设备 MAC、精确位置
- **记录**：HTTP 路由、cache_hit、上游 latency、错误 code

## 7. 测试策略

### 7.1 测试金字塔

```
              ┌─────────────┐
              │   手动 QA   │   每个 release 前一次
              │  (设备真机) │
              └──────┬──────┘
           ┌─────────┴─────────┐
           │   E2E (少而精)    │   关键 3 条流程
           │   Flutter         │
           │  integration_test │
           └─────────┬─────────┘
        ┌────────────┴────────────┐
        │    集成测试 (后端 API)  │  每个 endpoint 一组
        │     pytest + httpx     │
        └────────────┬────────────┘
   ┌─────────────────┴─────────────────┐
   │   单元测试 (Service/Repo 层)      │   每个逻辑分支
   │   pytest (后端) + flutter_test    │
   └────────────────────────────────────┘
```

### 7.2 后端测试

**单元（pytest）**——外部 API 用 `respx` mock，不打真三方。

- `test_recognize_service.py`
  - 正常路径：mock Brickognize 返回标准 payload → 验证归一化结果
  - 颜色名 → ID 查表：测 3 种颜色（命中 / 别名 / 未知 → -1）
  - 同件合并：同 part_num 不同 quantity → 合并
  - Brickognize 5xx → `UPSTREAM_ERROR`
  - Brickognize 超时 → 重试 1 次后报错
  - 缓存命中：第二次相同图片 hash → 不调三方
- `test_build_matcher.py`
  - strict 模式 / loose 模式（两次调三方后做差集）/ 全空 / Rebrickable 429
- `test_translator.py`
  - 全部命中缓存 → 不调 LLM
  - 部分命中：未命中字段才发 LLM
  - LLM 返回非 JSON → 重试 → 降级原文（标 `untranslated:true`）
  - 单字段 > 2000 字符 → 截断
- `test_cache.py`：相同输入 hash 一致；不同顺序的 parts 排序后 hash 一致
- `test_quota.py`：滚动窗口边界、超限返回 429

**集成（pytest + TestClient）**——真起 FastAPI，Redis / Postgres 用 testcontainers。

- `POST /v1/recognize` 上传 1MB JPEG → 200，结构符合 schema
- `POST /v1/recognize` 上传 10MB → 400 `INVALID_INPUT`
- `POST /v1/builds` 空 parts → 400
- 限流：同一 client_key 超限 → 429
- 断路器：连续 fail 10 次 → 后续 30 秒直接断
- 健康检查 `/health` → 200

### 7.3 Flutter 测试

**单元（flutter_test）**

- `LocalRepository`：CRUD 每张表、级联删除、merge 逻辑（同件累加、source 优先级）
- `InventoryEditor` VM：增删改、撤销
- 清单序列化排序：不同插入顺序得到相同 bytes
- `ApiClient` 错误归一化：5 种 code 各对应 UI 状态

**Widget**

- 主要 4 个页面的渲染快照（goldens）
- 置信度 < 0.6 时件显示 ⚠️
- 严格列表空、loose 列表空时显示"零结果合一页"
- 中英文切换时 UI 不溢出（关键文案对比）

**Integration（integration_test，跑模拟器）**

只覆盖最核心 3 条路径，每条用 mock 后端（本地起一个 HTTP server 返回固定响应）：

1. **拍照 → 识别 → 进入清单页**
2. **清单 → 匹配 → 看作品**
3. **导出 → 导入恢复**

### 7.4 测试数据

- `fixtures/brickognize_response_normal.json`：典型 12 件混堆识别响应
- `fixtures/brickognize_response_empty.json`：空数组
- `fixtures/rebrickable_build_strict.json`：35 个完全可搭作品
- `fixtures/rebrickable_build_loose.json`：包含部分缺件
- `fixtures/deepseek_translate_response.json`：标准翻译响应
- `fixtures/test_image_*.jpg`：3 张测试图（强光 / 正常 / 暗光）

### 7.5 CI

- **后端**：每次 push → `pytest --cov` 目标覆盖率 80%；同时跑 `ruff check` + `mypy`
- **Flutter**：`flutter analyze` + `flutter test`；integration test 在 GitHub Actions Android emulator 上跑
- **不在 CI 跑**：真 Brickognize / Rebrickable / DeepSeek；真三方仅在 nightly smoke job（如果配了 API key）

### 7.6 手动 QA Checklist

只跑那些**自动测不动**的：

- iOS + Android 各跑一次"拍真砖 → 看清单"
- 不同光照下拍 3 张：晴天窗边、室内日光灯、暗黄灯下
- 弱网下识别（Charles 模拟 3G）
- 整理 500 件大清单，验证滚动和性能
- 中英文切换，确认无文案漏翻
- 导出文件传到另一台设备导入

### 7.7 不做的测试

明确划出 MVP **不测**的：

- 跨平台真机自动化矩阵（只手动测主流 2-3 台设备）
- 性能 benchmark（除非用户反馈卡）
- 安全渗透（MVP 无账号无敏感数据）
- LLM 翻译质量回归（人工抽查即可）

## 8. 开发顺序 & 里程碑

### 8.1 阶段划分

**M1 — 后端骨架 + 识别打通（1.5 周）**
目标：能用 curl 把图片 POST 到后端，收到结构化零件清单。

- 项目骨架：FastAPI + docker-compose（Postgres + Redis）+ 配置管理 + 结构化日志
- `POST /v1/recognize` 端到端：Brickognize 对接、归一化、Redis 缓存、限流、断路器
- `GET /health`
- 单元 + 集成测试到位
- Brickognize 颜色名 → Rebrickable color_id 的对照表脚本（一次性，离线生成）

**M2 — Flutter 骨架 + 拍照识别闭环（1.5 周）**
目标：装上 app → 拍照 → 看到清单。

- Flutter 项目脚手架，路由 / 主题 / i18n 中英文框架
- 本地 SQLite + Drift（或 Sqflite）的 Repository 层
- Camera / Gallery 接入，本地压缩（`image` 库）
- 识别页：上传 → loading → 清单页
- 清单页只读展示（编辑下个阶段做）
- ApiClient 错误归一化、Sentry 接入

**M3 — 清单手动校正 + 多张照片合并（1 周）**
目标：识别错了能改、能补拍。

- 清单页支持增删改、按颜色 / 形状筛选、合并 `(part_num,color_id)` 累加
- 补拍：同一 session 追加照片，识别结果 merge 进现有清单
- 手动加件 UI（搜索 Rebrickable 件库——后端加 `/v1/parts/search` 代理接口）
- 置信度低件的 ⚠️ 角标 + "点这里确认"

**M4 — 后端匹配 + 作品浏览（1.5 周）**
目标：清单 → 看到能搭什么。

- 后端 `POST /v1/builds`：strict + loose 双查、差集、缓存
- Flutter 作品列表页：卡片网格、严格 / 宽松 Tab、无限滚动
- 作品详情页：基本信息 + "去 Rebrickable 看说明书"跳转
- 零结果合一页 UX（按总 qty 软提示）
- 收藏功能

**M5 — LLM 翻译 + i18n 闭合（1 周）**
目标：中文用户看到中文作品名 / 描述。

- 后端 `POST /v1/translate`：DeepSeek 对接、按字段缓存、JSON Schema 强约束
- Flutter 作品详情页接入翻译；中英切换按钮（原文 / 译文）
- 整体 UI 文案中英文检查
- 翻译降级（失败 → 原文 + 小标）

**M6 — 数据备份 + 收尾（1 周）**
目标：导出导入 JSON、Settings 页、QA。

- 设置页：语言、清缓存、宽松阈值滑杆 (1–10，默认 5)、导出、导入、关于
- JSON 导出 / 导入逻辑 + version 字段防呆
- 端到端 integration test 3 条主路径
- 手动 QA 清单走一遍
- README、部署文档

### 8.2 时间线汇总

```
M1 后端识别  ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░  W1-W1.5
M2 前端识别  ░░░░████░░░░░░░░░░░░░░░░░░░░░░░░  W1.5-W3
M3 校正合并  ░░░░░░░░██░░░░░░░░░░░░░░░░░░░░░░  W3-W4
M4 匹配浏览  ░░░░░░░░░░██████░░░░░░░░░░░░░░░░  W4-W5.5
M5 翻译 i18n ░░░░░░░░░░░░░░░░████░░░░░░░░░░░░  W5.5-W6.5
M6 备份收尾  ░░░░░░░░░░░░░░░░░░░░████░░░░░░░░  W6.5-W7.5
```

**总计约 7.5 周**（单人全栈；兼职可乘 1.5–2 倍）

### 8.3 风险提前标出

| 风险 | 缓解 |
|---|---|
| Brickognize 服务挂了或限流改严 | 错误处理已做；v2 考虑准备 fallback 模型 |
| Rebrickable API key 申请被拒 / 商业用途限制 | 申请时如实写"hobby app"；缓存层已能扛限速 |
| DeepSeek 国内 ICP / 合规 | 后端可改用 OpenAI 兼容协议切其他模型供应商 |
| 兼容砖识别率不达预期 | 手动校正 UI 作为兜底是必备，已在 M3 做 |
| Flutter 相机插件在某些华为 / 小米机型出 bug | 留好 `image_picker` 和 `camera` 双方案 |

### 8.4 显式排除项（MVP 不做）

- 用户账号 / 云同步（仅本地 + 导入导出）
- 内嵌说明书（仅跳转）
- 视频 / 3D 搭建动画
- 社区 / 分享 / 评论
- 付费 / 订阅
- 推送通知
- 视频流多帧识别（v2）
- LLM 代用件推荐（v2）
- 自训 CV 模型（v3，等用户数据足够）

## 9. 开放问题

无——所有产品决策已在 brainstorming 期完成确认，详见第 2 节决策表。
若实施中出现新分叉，按各章节"关键设计点"原则回退处理。
