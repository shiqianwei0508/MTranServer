# MTranServer 项目设计文档

> 版本：4.0.35 | 许可证：Apache-2.0 | 运行时：Bun / Node.js

---

## 目录

1. [项目概述](#1-项目概述)
2. [技术栈](#2-技术栈)
3. [项目结构](#3-项目结构)
4. [配置系统](#4-配置系统)
5. [启动流程](#5-启动流程)
6. [翻译引擎层](#6-翻译引擎层)
7. [语言检测](#7-语言检测)
8. [控制器层 (API)](#8-控制器层)
9. [中间件层](#9-中间件层)
10. [工具函数层](#10-工具函数层)
11. [WASM 原生模块](#11-wasm-原生模块)
12. [完整请求处理流程](#12-完整请求处理流程)
13. [构建与部署](#13-构建与部署)
14. [API 接口一览](#14-api-接口一览)

---

## 1. 项目概述

MTranServer 是一个机器翻译服务器，使用 **Mozilla Bergamot Translator** 引擎通过 **WebAssembly** 运行。它提供 RESTful API，兼容多种翻译服务协议（DeepL、Google Translate、划词翻译等），同时内置 Web UI。

**核心能力：**
- 支持 54 种语言，104 个翻译方向
- 长文本自动分割翻译
- 枢轴翻译（间接语言对通过英语中转）
- 翻译结果 LRU 缓存
- 多翻译面板 Web UI（React + shadcn/ui）
- Docker 一键部署

---

## 2. 技术栈

| 层级 | 技术 |
|------|------|
| 运行时 | Bun (开发) / Node.js 22 (生产) |
| Web 框架 | Express 5 |
| 类型系统 | TypeScript 5.9 |
| API 文档 | tsoa (自动生成 Swagger/OpenAPI) |
| 翻译引擎 | Bergamot Translator (WASM) |
| 语言检测 | CLD2 (WASM) |
| 前端 | React 19 + Vite 7 + Tailwind CSS 4 + shadcn/ui |
| 压缩 | fzstd (Facebook Zstandard) |
| 缓存 | lru-cache |
| 部署 | Docker (多阶段构建) |

---

## 3. 项目结构

```
MTranServer/
├── src/                          # TypeScript 源码
│   ├── main.ts                   # 入口：CLI 参数解析 + 启动服务器
│   ├── index.ts                  # 库导出入口（NPM 包用）
│   ├── globals.d.ts              # 全局类型（.wasm/.css/.js 等）
│   │
│   ├── config/
│   │   └── index.ts              # 配置系统
│   │
│   ├── server/
│   │   ├── index.ts              # Express 服务器创建、路由注册
│   │   ├── download.ts           # --download 命令
│   │   └── languages.ts          # --languages 命令
│   │
│   ├── controllers/
│   │   ├── translate.controller.ts  # 核心翻译控制器
│   │   ├── language.controller.ts   # 语言列表 + 语言检测
│   │   ├── system.controller.ts     # 系统接口 (/version, /health)
│   │   └── plugins/                 # 第三方 API 兼容
│   │       ├── deepl.controller.ts
│   │       ├── deeplx.controller.ts
│   │       ├── google.controller.ts
│   │       ├── hcfy.controller.ts
│   │       ├── imme.controller.ts
│   │       └── kiss.controller.ts
│   │
│   ├── services/
│   │   ├── index.ts              # 服务层导出
│   │   ├── engine.ts             # 翻译引擎管理（引擎池、缓存、枢轴翻译）
│   │   └── detector.ts           # 语言检测服务
│   │
│   ├── core/
│   │   ├── engine.ts             # TranslationEngine 类：WASM 调用核心
│   │   ├── factory.ts            # 工厂函数
│   │   ├── interfaces.ts         # 接口定义
│   │   └── loader.ts             # ResourceLoader：加载 WASM + 模型
│   │
│   ├── middleware/
│   │   ├── index.ts              # 中间件导出
│   │   ├── auth.ts               # 认证中间件
│   │   ├── cors.ts               # CORS 中间件
│   │   ├── error-handler.ts      # 全局错误处理
│   │   ├── request-id.ts         # 请求 ID
│   │   ├── request-logger.ts     # 请求日志
│   │   ├── swagger.ts            # Swagger 静态资源
│   │   └── ui.ts                 # Web UI 静态资源
│   │
│   ├── models/
│   │   ├── index.ts              # 模型导出
│   │   └── records.ts            # 模型记录管理
│   │
│   ├── utils/
│   │   ├── index.ts              # 工具导出
│   │   ├── cache.ts              # LRU 翻译缓存
│   │   ├── lang-alias.ts         # 语言代码规范化
│   │   ├── memory.ts             # 获取可用内存
│   │   ├── port.ts               # 获取空闲端口
│   │   ├── update-checker.ts     # 更新检查
│   │   └── version.ts            # 版本号比较
│   │
│   ├── lib/
│   │   ├── bergamot/             # Bergamot WASM（~4.73 MB）
│   │   └── cld2/                 # CLD2 WASM + C++ 源码（~1.07 MB）
│   │
│   ├── logger/
│   │   └── index.ts              # 日志系统
│   ├── version/
│   │   └── index.ts              # 版本号
│   ├── generated/                # tsoa 自动生成
│   └── assets/                   # UI/Swagger 资源映射
│
├── scripts/
│   ├── build.ts                  # 构建脚本（单文件/Node.js/全平台）
│   ├── bump.ts                   # 版本号更新
│   ├── gen-ui-assets.ts          # UI 资源映射生成
│   └── gen-swagger-assets.ts     # Swagger 资源映射生成
│
├── ui/                           # React 前端
│   └── src/
│       ├── App.tsx               # 主应用（路由：/main, /settings）
│       ├── components/
│       │   ├── TranslationPanel.tsx
│       │   ├── DesktopSettingsPage.tsx  # 服务器设置页
│       │   ├── HistorySheet.tsx
│       │   └── ui/               # shadcn/ui 组件
│       ├── hooks/                # 自定义 hooks
│       ├── i18n/
│       │   └── index.ts          # 多语言（en/zh/ja）
│       └── lib/
│           ├── desktop.ts        # 设置 API 客户端
│           └── db.ts             # IndexedDB 封装
│
├── Dockerfile                    # 多阶段构建
├── compose.yml                   # Docker Compose
├── package.json
├── tsconfig.json
└── tsoa.json
```

---

## 4. 配置系统

**文件：** `src/config/index.ts`

### 4.1 配置来源与优先级

```
CLI 参数 > 环境变量 > 配置文件 > 默认值
```

- **CLI 参数**：通过 `bun src/main.ts --port 8990 --log-level debug` 传入
- **环境变量**：`MT_HOST`、`MT_PORT`、`MT_API_TOKEN` 等
- **配置文件**：`$CONFIG_DIR/server.yml`（YAML 格式）
- **默认值**：硬编码在 `getDefaultConfig()` 中

### 4.2 配置项

| 配置项 | CLI 参数 | 环境变量 | 默认值 | 说明 |
|--------|----------|----------|--------|------|
| host | `--host` | `MT_HOST` | `0.0.0.0` | 监听地址 |
| port | `--port` | `MT_PORT` | `8989` | 监听端口 |
| logLevel | `--log-level` | `MT_LOG_LEVEL` | `warn` | 日志级别 |
| enableWebUI | `--ui/--no-ui` | `MT_ENABLE_UI` | `true` | Web UI |
| enableOfflineMode | `--offline` | `MT_OFFLINE` | `false` | 离线模式 |
| apiToken | `--api-token` | `MT_API_TOKEN` | 空 | API 认证令牌 |
| modelDir | `--model-dir` | `MT_MODEL_DIR` | `./models` | 模型目录 |
| configDir | `--config-dir` | `MT_CONFIG_DIR` | `./config` | 配置目录 |
| logDir | `--log-dir` | `MT_LOG_DIR` | `./logs` | 日志目录 |
| workerIdleTimeout | `--worker-idle-timeout` | - | `60` | Worker 空闲超时 |
| workersPerLanguage | `--workers-per-language` | - | `1` | 每语言 Worker 数 |
| cacheSize | - | - | `1000` | 翻译缓存条数 |
| maxSentenceLength | - | - | `1000` | 最大断句长度 |

### 4.3 核心函数

- `getDefaultConfig()` → 返回默认配置对象
- `getConfig()` → 获取当前运行时配置（合并所有来源）
- `loadConfigFile()` → 从 YAML 文件加载配置
- `saveConfigFile(config)` → 保存配置到 YAML 文件
- `setConfig(partial)` → 运行时更新配置
- `resetConfig()` → 恢复默认配置
- `clearConfigFile()` → 删除配置文件

---

## 5. 启动流程

**入口文件：** `src/main.ts`

```
main.ts                              src/server/index.ts
┌──────────────┐                    ┌────────────────────┐
│ 1. 解析 CLI  │                    │ 1. 创建 Express    │
│    参数      │                    │ 2. 注册中间件链    │
├──────────────┤   startServer()    ├────────────────────┤
│ 2. 处理命令  │ ─────────────────> │ 3. 注册 API 路由   │
│   - download │                    │ 4. RegisterRoutes  │
│   - languages│                    │ 5. 注册静态资源    │
├──────────────┤                    ├────────────────────┤
│ 3. startServer│                   │ 6. 启动 HTTP 监听   │
└──────────────┘                    └────────────────────┘
```

### 5.1 main.ts 处理逻辑

```
1. process.argv 解析 → 提取 --host, --port, --log-level 等
2. 如果包含 --download → 调用 DownloadCommand，下载模型后退出
3. 如果包含 --languages → 调用 LanguagesCommand，列出语言后退出
4. 否则 → 调用 startServer(config) 启动服务器
```

### 5.2 服务器初始化 (server/index.ts)

```typescript
// 中间件注册顺序（请求处理顺序）
app.use(requestId());           // 1. 请求 ID
app.use(express.json());        // 2. JSON 解析
app.use(cors());                // 3. CORS
if (config.logRequests) {
  app.use(requestLogger());     // 4. 请求日志（可选）
}
RegisterRoutes(app);            // 5. tsoa 自动路由
app.use('/ui', uiMiddleware);   // 6. Web UI 静态资源
app.use('/docs', swaggerMiddleware); // 7. Swagger UI
if (config.apiToken) {
  app.use(authMiddleware);      // 8. API 认证（可选）
}
app.use(errorHandler);          // 9. 全局错误处理
```

---

## 6. 翻译引擎层

翻译引擎由 **两层** 组成：

```
services/engine.ts        → 管理器层（引擎池、缓存、枢轴翻译）
core/engine.ts            → 底层 WASM 调用
core/loader.ts            → WASM 模块 + 模型文件加载
core/factory.ts           → 工厂函数创建
```

### 6.1 底层引擎 `core/engine.ts`

**`TranslationEngine` 类：**

```typescript
class TranslationEngine {
  constructor(module: BergamotModule, config: EngineConfig)
  
  async translate(from: string, to: string, text: string, html: boolean): Promise<string>
  async shutdown(): Promise<void>
}
```

**核心处理流程：**
```
1. 获取或创建翻译模型（from→to 语言对）
2. 调用 Bergamot API：
   ResponseOptions → VectorString → translate() → VectorString
3. 提取译文文本
4. 如果 html=true，保留 HTML 标签
5. 返回翻译结果
```

### 6.2 管理器层 `services/engine.ts`

**`TranslationEngineManager` 类：**

```
引擎管理器
├── 引擎池 (Map<string, TranslationEngine>)
│   └── key = "from→to" 语言对
├── LRU 缓存（翻译结果）
├── 并发控制（信号量）
├── 枢轴翻译：无直接引擎时通过英语中转
└── 长文本分割：超过 maxSentenceLength 时自动断句
```

**关键方法：**

| 方法 | 说明 |
|------|------|
| `translate(from, to, text, html)` | 主翻译接口 |
| `getEngine(from, to)` | 获取或创建引擎实例 |
| `translateByPivot(from, to, text, html)` | 枢轴翻译 (from→en→to) |
| `splitLongText(text)` | 长文本分割（按句子边界） |
| `batchTranslate(from, to, texts)` | 批量翻译 |
| `getAvailableLanguages()` | 获取可用语言列表 |
| `getAvailablePairs()` | 获取可用翻译对 |
| `shutdown()` | 关闭所有引擎释放资源 |

### 6.3 资源加载 `core/loader.ts`

**`ResourceLoader` 类：**

```
加载流程：
1. 下载/加载 WASM 文件 (bergamot-translator.wasm)
2. 实例化 WASM 模块
3. 遍历模型文件列表
4. 下载/加载每个 .spm 源语言模型
5. 下载/加载每个 .spm 目标语言模型
6. 返回配置好的 BergamotModule
```

### 6.4 缓存机制 `utils/cache.ts`

```typescript
// LRU 缓存：最大 1000 条，TTL = 1 小时
const cache = new LRUCache({ max: config.cacheSize, ttl: 3600000 });

// 缓存 key = "from→to:text"
// 命中缓存直接返回，跳过 WASM 翻译
```

---

## 8. 语言检测

**文件：** `services/detector.ts` + `lib/cld2/`

### 14.1 双重检测策略

```
输入文本
    │
    ├── 优先：CLD2 WASM 引擎检测
    │   └── 返回语言代码 + 置信度
    │
    └── 回退：启发式判断
        ├── 包含中文字符 → zh-Hans
        ├── 包含日文字符 → ja
        ├── 包含韩文字符 → ko
        └── 其他 → en
```

### 14.2 CLD2 模块 (`lib/cld2/`)

| 文件 | 说明 |
|------|------|
| `cld2.wasm` | 编译后的 CLD2 WASM 模块 |
| `cld2.js` | WASM 胶水代码 |
| `cldapp.cc` | C++ 封装类 |
| `cld.cpp` | Emscripten 绑定 |
| `cld.idl` | WebIDL 接口定义 |
| `internal/` | CLD2 原始 C++ 源码 |

---

## 9. 控制器层 (API)

### 8.1 核心翻译控制器

**文件：** `src/controllers/translate.controller.ts`

**POST `/translate`**

```
输入：
{
  "from": "en",         // 源语言（可选，auto 自动检测）
  "to": "zh-Hans",      // 目标语言
  "text": "Hello",      // 待翻译文本
  "html": false         // 是否保留 HTML 标签
}

输出：
{
  "from": "en",
  "to": "zh-Hans",
  "text": "你好",
  "original": "Hello",
  "engine": "bergamot"
}
```

**POST `/translate/batch`**

```
输入：{ "from": "en", "to": "zh", "texts": ["Hello", "World"] }
输出：{ "translations": ["你好", "世界"] }
```

### 8.2 语言控制器

**文件：** `src/controllers/language.controller.ts`

- **GET `/languages`** → 返回可用语言列表和翻译对
- **POST `/detect`** → 检测文本语言（CLD2）

### 8.3 系统控制器

**文件：** `src/controllers/system.controller.ts`

- **GET `/version`** → 服务器版本
- **GET `/health`** → 健康检查
- **GET `/__heartbeat__`** → 心跳检测
- **GET `/__lbheartbeat__`** → 负载均衡心跳

### 8.4 第三方 API 兼容

| 文件 | 兼容协议 | 端点 |
|------|----------|------|
| `deepl.controller.ts` | DeepL API | `/v2/translate` |
| `deeplx.controller.ts` | DeepLX | `/translate` (特定格式) |
| `google.controller.ts` | Google Translate | `/translate` (特定格式) |
| `hcfy.controller.ts` | 划词翻译 | `/translate` (特定格式) |
| `imme.controller.ts` | Imme | `/translate` (特定格式) |
| `kiss.controller.ts` | Kiss Translator | `/translate` (特定格式) |

---

## 10. 中间件层

**文件目录：** `src/middleware/`

| 文件 | 中间件名称 | 功能 |
|------|-----------|------|
| `request-id.ts` | `requestId()` | 为每个请求生成/提取 `X-Request-ID` |
| `request-logger.ts` | `requestLogger()` | 记录请求方法、URL、响应时间 |
| `cors.ts` | `cors()` | CORS 跨域支持 |
| `auth.ts` | `authMiddleware()` | 验证 `Authorization: Bearer <token>` |
| `error-handler.ts` | `errorHandler()` | 全局错误捕获，返回 500 |
| `ui.ts` | `uiMiddleware()` | 提供 Web UI 静态文件 |
| `swagger.ts` | `swaggerMiddleware()` | 提供 Swagger UI |
| `auth.ts` | `expressAuthentication()` | tsoa 框架的认证回调 |

### 认证逻辑 (auth.ts)

```
1. 检查 config.apiToken 是否为空 → 为空则跳过认证
2. 提取 Authorization header
3. 验证 Bearer token 是否匹配
4. 不匹配 → 401 Unauthorized
5. 匹配 → next()
```

---

## 11. 工具函数层

**文件目录：** `src/utils/`

| 文件 | 导出 | 功能 |
|------|------|------|
| `cache.ts` | `LRU` 缓存管理 | 翻译结果缓存，TTL 过期 |
| `lang-alias.ts` | `normalizeLang()` | 语言代码标准化（zh→zh-Hans） |
| `lang-alias.ts` | `isCJK()` | 判断是否中日韩文字 |
| `port.ts` | `getFreePort()` | 查找可用端口 |
| `memory.ts` | `getAvailableMemory()` | 获取系统可用内存 |
| `version.ts` | `compareVersions()` | Semver 版本比较 |
| `update-checker.ts` | `checkForUpdates()` | GitHub Releases 检查更新 |

---

## 12. WASM 原生模块

### 11.1 Bergamot Translator

**目录：** `src/lib/bergamot/`

| 文件 | 大小 | 说明 |
|------|------|------|
| `bergamot-translator.wasm` | ~4.73 MB | Mozilla Bergamot 翻译引擎 |
| `bergamot-translator.js` | - | WASM 胶水代码 |

**加载流程：**
```
1. core/loader.ts 读取 .wasm 二进制
2. Bun 实例化 WASM 模块
3. 加载 .spm 模型文件到 WASM 内存
4. 创建 Bergamot Service 实例
5. 绑定到 TranslationEngine
```

### 11.2 CLD2 语言检测

**目录：** `src/lib/cld2/`（含 C++ 源码）

**文件清单：**
- `cld2.wasm` (~1.07 MB) - 编译后的 WASM
- `cld2.js` - WASM 胶水代码
- `cldapp.cc` - C++ 封装类 (CLDApp)
- `cld.cpp` - Emscripten 绑定代码
- `cld.idl` - WebIDL 接口
- `post.js` - JS 后处理
- `Makefile` - Emscripten 构建配置
- `internal/` - CLD2 原始源码（26 个 .h, 25 个 .cc）

**Emscripten 编译：**
```makefile
# Makefile 关键配置
emcc -s WASM=1 -O3 cld.cpp internal/*.cc -o cld2.js
```

---

## 13. 完整请求处理流程

以 **`POST /translate`** 为例：

```
[1] 客户端发送请求
    POST http://localhost:8089/translate
    Content-Type: application/json
    {"from":"en","to":"zh-Hans","text":"Hello world","html":false}
         │
         ▼
[2] Express 中间件链 (server/index.ts L30-37)
    requestId()        → 注入 X-Request-ID
    express.json()     → 解析 body 为 JS 对象
    cors()             → 添加 CORS 头
    requestLogger()    → 记录请求日志（可选）
         │
         ▼
[3] tsoa 路由匹配 (generated/routes.ts)
    匹配 POST /translate → TranslateController.translate()
         │
         ▼
[4] 控制器处理 (controllers/translate.controller.ts)
    - 校验参数 (from, to, text)
    - normalizeLang(from), normalizeLang(to)
    - config.fullwidthZhPunctuation → 转换标点
         │
         ▼
[5] 服务层 (services/engine.ts)
    TranslationEngineManager.translate(from, to, text, html)
    ├── 检查 LRU 缓存 → 命中：直接返回
    ├── 命中？→ 直接返回缓存结果
    ├── 获取翻译引擎：getEngine(from, to)
    │   ├── 有直接引擎？→ 使用
    │   └── 无直接引擎？→ translateByPivot(from→en→to)
    │
    ├── 文本超长？→ splitLongText() 分割
    ├── 并发控制：semaphore.acquire()
    │       │
    │       ▼
    ├── [6] WASM 翻译 (core/engine.ts)
    │       TranslationEngine.translate()
    │       ├── VectorString 包装文本
    │       ├── Bergamot Service.translate()
    │       ├── WASM 执行神经网络推理
    │       └── 提取译文 VectorString
    │
    ├── 存入 LRU 缓存
    └── semaphore.release()
         │
         ▼
[7] 控制器返回 (controllers/translate.controller.ts)
    构建响应：
    { from, to, text: "你好世界", original: "Hello world", engine: "bergamot" }
         │
         ▼
[8] Express 自动序列化
    JSON.stringify() → HTTP 200 Response
```

---

## 14. 模型下载与离线部署

**文件：** `src/models/records.ts` + `src/core/factory.ts`

### 14.1 模型来源

所有翻译模型来自 Mozilla Firefox Translations 项目：

| 资源 | URL |
|------|-----|
| 模型索引 | `https://firefox.settings.services.mozilla.com/v1/buckets/main-preview/collections/translations-models-v2/records` |
| 模型文件 | `https://firefox-settings-attachments.cdn.mozilla.net/<location>` |

### 14.2 模型文件结构

每个语言对目录 `{from}_{to}/` 下包含以下文件类型：

| 文件类型 | record.fileType | 说明 |
|----------|-----------------|------|
| `model.{from}{to}.intgemm.alphas.bin` | `model` | 翻译模型权重（必需） |
| `lex.50.50.{from}{to}.s2t.bin` | `lex` | 词典文件（必需） |
| `srcvocab.{from}{to}.spm` | `srcvocab` | 源语言词表（必需） |
| `trgvocab.{from}{to}.spm` | `trgvocab` | 目标语言词表（必需） |
| `vocab.{from}{to}.spm` | `vocab` | 共享词表（替代 srcvocab+trgvocab） |

**示例** (`models/en_zh-Hans/`)：
```
en_zh-Hans/
├── model.enzh.intgemm.alphas.bin
├── lex.50.50.enzh.s2t.bin
├── srcvocab.enzh.spm
└── trgvocab.enzh.spm
```

### 14.3 在线自动下载（默认）

首次翻译时自动触发，由 `src/models/records.ts` 的 `downloadModel()` 实现：

```
1. initRecords() → 下载 records.json（模型索引）
2. 根据 fromLang + toLang 匹配模型记录
3. 选择最新版本（getLargestVersion）
4. 逐文件下载 .zst 压缩包
5. 解压 zstd（fzstd 库）
6. SHA256 校验
7. 存入 models/{from}_{to}/
```

**代码位置**：`src/models/records.ts` L117-207

### 14.4 离线部署方法

适用于无网络环境或提前准备模型的场景。

#### 步骤 1：下载模型索引

```bash
curl -o ./models/records.json \
  "https://firefox.settings.services.mozilla.com/v1/buckets/main-preview/collections/translations-models-v2/records"
```

#### 步骤 2：解析索引获取模型文件 URL

```bash
# 查看 en→zh-Hans 的模型文件信息
bun -e "
  const records = require('./models/records.json');
  records.data
    .filter(r => r.sourceLanguage === 'en' && r.targetLanguage === 'zh-Hans')
    .forEach(r => console.log(
      r.fileType.padEnd(12),
      r.version.padEnd(20),
      'https://firefox-settings-attachments.cdn.mozilla.net/' + r.attachment.location
    ));
"
```

#### 步骤 3：下载模型文件

```bash
# 创建语言对目录
mkdir -p models/en_zh-Hans

# 下载并解压（文件 URL 从步骤 2 获取）
BASE="https://firefox-settings-attachments.cdn.mozilla.net"

# 示例：下载 model 文件
curl -o models/en_zh-Hans/model.enzh.intgemm.alphas.bin.zst \
  "$BASE/<model_location>"

# 解压 zstd
bun -e "
  const { decompress } = require('fzstd');
  const fs = require('fs');
  const dir = 'models/en_zh-Hans';
  fs.readdirSync(dir).filter(f => f.endsWith('.zst')).forEach(f => {
    const src = dir + '/' + f;
    const dst = src.replace(/.zst$/, '');
    fs.writeFileSync(dst, decompress(fs.readFileSync(src)));
    fs.unlinkSync(src);
    console.log('Decompressed:', dst);
  });
"
```

#### 步骤 4：打包传输到离线服务器

```bash
# 打包
tar -czf mtran-models.tar.gz models/

# 传输到目标服务器后解压
tar -xzf mtran-models.tar.gz -C /path/to/MTranServer/
```

#### 步骤 5：离线启动

```bash
# 启动离线模式（跳过 records.json 远程下载）
bun run src/main.ts --offline --model-dir ./models --port 8989
```

### 14.5 模型目录默认路径

> **v4.0.33 变更**：默认模型目录从 `~/.config/mtran/models` 改为代码根目录 `./models`

配置优先级（`src/config/index.ts` L115-117）：
```
--model-dir CLI 参数  >  MT_MODEL_DIR 环境变量  >  配置  >  ./models
```

`./models`、`./config`、`./logs` 三个运行时目录已加入 `.gitignore`。

---

## 15. 构建与部署

### 8.1 构建脚本

**文件：** `scripts/build.ts`

| 命令 | 说明 |
|------|------|
| `bun run build:node` | 构建 Node.js 版本 (dist/main.js) |
| `bun run build` | 构建单文件可执行 (dist/mtranserver) |
| `bun run build:all` | 构建全平台单文件 (11 个目标) |
| `bun run build:lib` | 构建 NPM 库 (dist/index.js + .d.ts) |
| `bun run build:docker` | 构建 Docker 镜像 |

**node 构建流程 (build:node):**
```
1. 构建 UI: cd ui && bun run build (tsc + vite)
2. 生成 UI 资源映射: bun scripts/gen-ui-assets.ts
3. 生成 Swagger 资源: bun scripts/gen-swagger-assets.ts
4. tsoa 路由生成: bun tsoa spec-and-routes
5. Bun 打包: bun build src/main.ts --outdir dist --target node
```

### 8.2 Dockerfile

**文件：** `Dockerfile`

**两阶段构建：**

```
Stage 1: Builder (oven/bun:1)
├── 安装依赖 (package.json + ui/package.json)
├── 复制源码
├── 版本号注入 (bun run bump)
└── 构建 Node.js 版本 (bun run build:node)

Stage 2: Runtime (node:22-alpine)
├── 从 builder 复制 dist/
├── 设置环境变量 (MT_HOST, MT_PORT)
├── 暴露 8989 端口
└── CMD: node main.js
```

### 8.3 Docker Compose

**文件：** `compose.yml`

```yaml
services:
  mtranserver:
    image: xxnuo/mtranserver:latest
    ports: ["8989:8989"]
    volumes: ["./models:/app/models"]
    healthcheck: curl http://localhost:8989/health
```

---

## 16. API 接口一览

### 9.1 核心 API

| Method | Path | 说明 | 文件 |
|--------|------|------|------|
| `POST` | `/translate` | 单条翻译 | `translate.controller.ts` |
| `POST` | `/translate/batch` | 批量翻译 | `translate.controller.ts` |
| `GET` | `/languages` | 可用语言列表 | `language.controller.ts` |
| `POST` | `/detect` | 语言检测 | `language.controller.ts` |
| `GET` | `/version` | 服务器版本 | `system.controller.ts` |
| `GET` | `/health` | 健康检查 | `system.controller.ts` |
| `GET` | `/__heartbeat__` | 心跳 | `system.controller.ts` |
| `GET` | `/__lbheartbeat__` | 负载均衡心跳 | `system.controller.ts` |

### 9.2 设置 API

| Method | Path | 说明 |
|--------|------|------|
| `GET` | `/ui/api/settings` | 获取当前配置 |
| `POST` | `/ui/api/settings/apply` | 应用新配置 |
| `POST` | `/ui/api/settings/reset` | 恢复默认配置 |
| `POST` | `/ui/api/settings/restart` | 获取状态 |

### 9.3 第三方兼容 API

| 协议 | Path | 说明 |
|------|------|------|
| DeepL | `POST /v2/translate` | DeepL API 兼容 |
| DeepLX | `POST /translate` | DeepLX 格式 |
| Google | `POST /translate` | Google 格式 |
| 划词翻译 | `POST /translate` | HCFY 格式 |
| Imme | `POST /translate` | Imme 格式 |
| Kiss | `POST /translate` | Kiss 格式 |

### 9.4 静态资源

| Path | 说明 |
|------|------|
| `/ui/` | Web 管理界面 |
| `/docs/` | Swagger API 文档 |

---

## 附录 A：文件代码量统计

| 类别 | 文件数 | 说明 |
|------|--------|------|
| TypeScript 源码 | 46 | src/ 业务逻辑 |
| C++ 头文件 | 26 | CLD2 原生代码 |
| C++ 源文件 | 25 | CLD2 原生代码 |
| WASM 模块 | 2 | Bergamot + CLD2 |
| React 组件 | 60+ | shadcn/ui 组件 |
| 构建脚本 | 4 | TypeScript |

## 附录 B：关键依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| express | ^5.2.1 | Web 框架 |
| express-validator | ^7.3.1 | 参数校验 |
| fzstd | ^0.1.1 | Zstandard 压缩/解压 |
| lru-cache | ^11.2.4 | 翻译结果缓存 |
| swagger-ui-express | ^5.0.1 | Swagger 文档 |
| tsoa | ^7.0.0-alpha | API 路由/文档生成 |
| typescript | ^5.9.3 | 类型系统 |
