# M2 — Flutter 骨架 + 拍照识别闭环 设计文档

**日期**：2026-06-23
**状态**：Design (待 writing-plans 转 implementation plan)
**基于**：`2026-06-21-lego-photo-build-finder-design.md` 总体设计

## 1. 范围

M2 目标：装上 app → 拍照 → 看到零件清单。

### 包含

- Flutter 项目脚手架（路由、主题、i18n 中英文框架）
- 本地 SQLite 存储层（LocalRepository）
- 选图/拍照页 + 确认预览页 + 识别加载页 + 零件清单结果页
- 首页（历史 session 列表）
- 后端 API Client 封装（调用 `/v1/recognize` + 错误归一化）
- 单元测试 + widget 测试

### 不包含（后续里程碑做）

- 清单编辑/增删改（M3）
- 补拍（M3）
- 作品匹配（M4）
- 翻译（M5）
- 导出导入（M6）

## 2. UI 设计（已通过 brainstorming 确认）

### 2.1 页面导航

```
App 启动
  │
  ▼
首页（Session 列表）
  │
  ├─ 点击拍照按钮 ──► 拍照/选图引导页
  │                      │
  │                      ▼
  │                   确认预览页
  │                      │
  │                      ▼
  │                   识别加载页
  │                      │
  │                      ▼
  │                   零件清单页 ◄── 识别完成
  │
  └─ 点击历史 session ──► 零件清单页（已有数据）
```

### 2.2 首页（Session 列表）

- **布局**：顶部大按钮"拍照识别" + 按时间倒序排列 session 卡片列表
- **每条 session 卡片**：日期、件数、缩略图
- **空状态**：中间显示引导文案"点击上方按钮，拍照识别你的乐高砖块"
- **风格**：极简列表，无统计卡片

### 2.3 拍照/选图引导页

- 两个大按钮："📷 拍照" 和 "🖼️ 从相册选择"
- 中间有拍摄示意图和提示："把砖平铺在浅色背景上效果更好"
- 选完/拍完 → 进入确认预览页

### 2.4 确认预览页

- 照片全屏预览
- 底部信息："已选 1 张照片" + 引导文字
- 两个按钮：「重新拍/选」「开始识别」

### 2.5 识别加载页

- 独立页面
- 中间进度动画（脉冲/圆圈）
- 文案："正在识别砖块…"
- 下方："大约需要 5-15 秒"
- 右上角「取消」按钮
- 超过 15 秒提示："还在努力识别…"

### 2.6 零件清单页（只读）

- **顶部栏**：标题"零件清单"
- **统计条**："共识别 X 种零件，Y 件"
- **卡片列表**：每张卡片显示：
  - 左侧颜色色块（按 color_id 渲染对应颜色）
  - 件号 + 名称（如 "3001 — Brick 2x4"）
  - 颜色名
  - 右侧数量大数字
  - 低置信度（<0.6）卡片加 ⚠️ 角标
- **底部**：[📷 补拍] 和 [✏️ 手动编辑] 按钮（M2 阶段置灰/不可用，仅占位）
- **空结果**：提示"未识别出零件，试试换个角度或光线"

## 3. 技术架构

### 3.1 项目结构

```
app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                  # App 入口，MaterialApp + 路由
│   ├── app_router.dart            # 路由定义
│   ├── l10n/                      # 国际化
│   │   ├── app_zh.arb             # 中文文案
│   │   └── app_en.arb             # 英文文案
│   ├── theme/
│   │   └── app_theme.dart         # 主题、颜色、字体
│   ├── models/                    # 数据模型
│   │   ├── inventory_session.dart
│   │   ├── inventory_part.dart
│   │   └── recognize_response.dart
│   ├── repository/                # 数据层
│   │   ├── local_repository.dart  # SQLite 操作统一入口
│   │   └── database_helper.dart   # 数据库初始化 + migration
│   ├── api/
│   │   ├── api_client.dart        # HTTP 客户端封装
│   │   └── api_exceptions.dart    # 错误码定义
│   ├── pages/
│   │   ├── home/
│   │   │   ├── home_page.dart
│   │   │   └── home_page_vm.dart
│   │   ├── capture/
│   │   │   ├── capture_page.dart
│   │   │   └── capture_page_vm.dart
│   │   ├── confirm/
│   │   │   ├── confirm_page.dart
│   │   │   └── confirm_page_vm.dart
│   │   ├── loading/
│   │   │   ├── loading_page.dart
│   │   │   └── loading_page_vm.dart
│   │   └── result/
│   │       ├── result_page.dart
│   │       └── result_page_vm.dart
│   └── widgets/                   # 可复用组件
│       ├── part_card.dart         # 零件卡片
│       └── empty_state.dart       # 空状态组件
├── test/
│   ├── unit/
│   │   ├── repository_test.dart
│   │   ├── api_client_test.dart
│   │   └── models_test.dart
│   └── widget/
│       ├── home_page_test.dart
│       └── result_page_test.dart
└── assets/
    └── images/
        └── capture_guide.png      # 拍摄引导图
```

### 3.2 路由设计

```dart
// GoRouter 或 Navigator 2.0
// 路径：
/                        → HomePage
/capture                 → CapturePage (选图/拍照)
/confirm                 → ConfirmPage (确认预览)
/loading                 → LoadingPage (识别加载)
/result/:sessionId       → ResultPage (零件清单)
```

### 3.3 状态管理

- 使用 `ChangeNotifier` + `Provider`（Flutter 内置方案，无需第三方状态管理库）
- 每个页面一个 ViewModel（`*_vm.dart`），持有页面状态
- ViewModel 职责：
  - 调用 Repository / API Client
  - 管理 loading / error / data 三态
  - 暴露给 Widget 渲染

### 3.4 数据模型（Dart）

```dart
class InventorySession {
  final String id;          // UUID v4
  final String name;        // 默认 "2026-06-23 识别"
  final DateTime createdAt;
  final int partCount;      // 件数汇总，展示用
  final String? thumbnail;  // 首张照片本地路径
}

class InventoryPart {
  final String partNum;     // Rebrickable 件号
  final int colorId;        // -1 表示未知
  final int quantity;
  final String source;      // 'recognized'
  final double? confidence; // 0~1
  // 展示用，从 ColorTable 映射
  final String? colorName;
}

class RecognizeResponse {
  final List<PartItem> parts;
  final bool cacheHit;
  final int lowConfidenceCount;
}
```

### 3.5 本地 SQLite

- 使用 `sqflite`（最成熟稳定）
- 表结构与总体设计文档一致（`inventory_session`、`inventory_part`、`inventory_photo`）
- M2 只实现 `inventory_session` + `inventory_part` 两张表
- 封装在 `LocalRepository` 中，上层不直接操作数据库

### 3.6 API Client

```dart
class ApiClient {
  // 配置：后端 baseUrl（开发期可配置）
  // 方法：
  Future<RecognizeResponse> recognize({
    required String imagePath,  // 本地文件路径
  });
  
  // 错误归一化：
  // HTTP 400 → ApiException(ApiError.invalidInput)
  // HTTP 502/504 → ApiException(ApiError.upstreamError)
  // HTTP 429 → ApiException(ApiError.rateLimited)
  // 网络异常 → ApiException(ApiError.networkError)
  // 其他 → ApiException(ApiError.internal)
}
```

### 3.7 图片压缩

- 用户选图/拍照后，先本地压缩再上传
- 参数：长边 1600px，JPEG quality 85
- 使用 `image` 库或 Flutter 内置 `ui` 库

## 4. 测试

### 4.1 单元测试

- `LocalRepository`：CRUD session、CRUD parts、空数据库、重复插入
- `ApiClient`：各错误码对应正确异常
- Model 序列化/反序列化

### 4.2 Widget 测试

- 首页：有数据/空状态/标题文案
- 零件卡片：正常/低置信度/颜色色块
- 拍照引导页：两个按钮存在

## 5. 开发顺序

1. Flutter 项目脚手架（pubspec.yaml、路由、主题、i18n）
2. 数据模型 + 本地 SQLite（LocalRepository）
3. API Client + 图片压缩
4. 首页（Session 列表，空状态）
5. 拍照/选图引导页
6. 确认预览页
7. 识别加载页
8. 零件清单结果页
9. 端到端流程打通
10. 测试
