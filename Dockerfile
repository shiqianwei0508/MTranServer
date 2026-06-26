FROM oven/bun:1 AS builder
WORKDIR /app

ARG VERSION
ENV VERSION=${VERSION}

COPY package.json bun.lock ./
RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun install --frozen-lockfile

COPY ui/package.json ui/bun.lock ./ui/
RUN --mount=type=cache,target=/root/.bun/install/cache \
    cd ui && bun install --frozen-lockfile

COPY . .

RUN if [ -z "$VERSION" ]; then VERSION=$(bun -p "require('./package.json').version"); fi; \
    bun run bump "$VERSION"

RUN --mount=type=cache,target=/root/.bun/install/cache \
    bun run build:node

# 预下载常用语言模型（英语 ↔ 使用人口前 12 的语言）
# 中文、西班牙语、法语、德语、日语、俄语、葡萄牙语、意大利语、荷兰语、波兰语、捷克语
RUN --mount=type=cache,target=/root/.bun/install/cache \
    cd /app && mkdir -p models && \
    bun run src/main.ts --download \
      en-zh zh-en \
      en-es es-en \
      en-fr fr-en \
      en-de de-en \
      en-ja ja-en \
      en-ru ru-en \
      en-pt pt-en \
      en-it it-en \
      en-nl nl-en \
      en-pl pl-en \
      en-cs cs-en

FROM node:22-alpine

WORKDIR /app

COPY --from=builder /app/dist ./
COPY --from=builder /app/models ./models

ENV MT_HOST=0.0.0.0 \
    MT_PORT=8989 \
    NODE_ENV=production

EXPOSE 8989

CMD ["node", "main.js"]
