# Changelog

## v4.0.34 (2026-06-26)

- 清理仓库：移除 `deprecated/` 目录（103 个旧版 Go/C++/JS/Rust 文件）
- 移除 Electron 桌面端支持（`desktop/`、`scripts/electron-*`、`src/desktop.ts`）
- 默认模型目录从 `~/.config/mtran/models` 改为 `./models`（代码根目录）
- 默认配置目录从 `~/.config/mtran` 改为 `./config`
- 默认日志目录从 `~/.config/mtran/logs` 改为 `./logs`
- 新增 `docs/DESIGN.md` 项目设计文档（含离线模型下载指南）
- 重写 `README.md`，精简结构，API 文档链接到 `docs/` 目录
- 新增 `.gitignore` 规则：`/config`、`/logs`、`.codebuddy/`
- 清理 `src/server/index.ts` 中的 Electron 桌面控制桥接代码
- 修复 `package.json` JSON 尾随逗号错误

## v4.0.33

- 上一个版本
