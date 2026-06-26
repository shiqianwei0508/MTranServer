# MTranServer

> 离线翻译服务器，基于 Mozilla Bergamot + WebAssembly，无需显卡。单个请求平均响应 50ms。

[English](docs/README_en.md) | [日本語](docs/README_ja.md) | [Français](docs/README_fr.md) | [Deutsch](docs/README_de.md)

---

## 环境要求

| 依赖 | 版本 |
|------|------|
| [Bun](https://bun.sh) | >= 1.3 |
| Node.js（备选） | >= 18 |

## 快速开始

```bash
# 克隆仓库
git clone <your-repo-url>
cd MTranServer

# 安装依赖
bun install
cd ui && bun install && cd ..

# 生成路由和资源文件
bun tsoa spec-and-routes
bun run scripts/gen-swagger-assets.ts

# 构建前端
cd ui && bun run build && cd ..
bun run scripts/gen-ui-assets.ts

# 启动（首次翻译自动下载模型）
bun run src/main.ts --log-level debug --port 8089
```

访问：
- Web UI：`http://localhost:8089/ui/`
- API 文档：`http://localhost:8089/docs/`

### 下载翻译模型

```bash
# 下载指定语言对
bun run src/main.ts --download en-zh zh-en

# 查看可用语言对
bun run src/main.ts --languages
```

模型存放在 `./models/`。离线部署详见 [docs/DESIGN.md](docs/DESIGN.md#14-模型下载与离线部署)。

---

## Docker 部署

```bash
# 构建镜像
docker build -t mtranserver .

# 启动
docker run -d --name mtranserver -p 8989:8989 -v ./models:/app/models mtranserver
```

或者用 Docker Compose（使用本地构建的镜像）：

```yaml
# docker-compose.yml
services:
  mtranserver:
    build: .
    container_name: mtranserver
    restart: unless-stopped
    ports:
      - "8989:8989"
    volumes:
      - ./models:/app/models
```

---

## API 文档

| 文档 | 说明 |
|------|------|
| [DESIGN.md](docs/DESIGN.md) | 项目设计文档（架构、数据流、模块详解） |
| [OpenAPI](http://localhost:8989/docs/) | Swagger 交互式 API 文档（启动后访问） |
| [API_en.md](docs/API_en.md) | English API docs |
| [API_ja.md](docs/API_ja.md) | 日本語 API ドキュメント |
| [API_de.md](docs/API_de.md) | Deutsche API-Dokumentation |
| [API_fr.md](docs/API_fr.md) | Documentation API française |

### 兼容接口

服务器兼容多个翻译插件的 API 格式：

| 接口 | 兼容协议 |
|------|----------|
| `/deepl` | DeepL API v2 |
| `/deeplx` | DeepLX |
| `/google/language/translate/v2` | Google Translate API |
| `/imme` | 沉浸式翻译 |
| `/kiss` | 简约翻译 (Kiss Translator) |
| `/hcfy` | 划词翻译 |

---

## 命令参考

```bash
bun run src/main.ts [options]

Options:
  --host <ip>           监听地址 (default: 0.0.0.0)
  --port <port>         监听端口 (default: 8989)
  --log-level <level>   日志级别: debug|info|warn|error
  --model-dir <path>    模型目录 (default: ./models)
  --config-dir <path>   配置目录 (default: ./config)
  --offline             离线模式
  --no-ui               禁用 Web UI
  --api-token <token>   API 认证令牌
  --download <pairs>    下载模型，如: --download en-zh
  --languages            列出可用语言对
```

---

## 项目结构

详见 [docs/DESIGN.md](docs/DESIGN.md#3-项目结构)

---

## License

Apache-2.0
