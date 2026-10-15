# Bedtime Admin

Vue 3 + Element Plus 内部运营后台（仿 Bandage admin 架构）。

## 本地开发

```bash
# API 先在 :8000 跑起来
cd apps/admin
npm install
npm run dev   # http://localhost:5174 ，/admin 代理到 API
```

登录账号来自 API 环境变量 `ADMIN_BOOTSTRAP_USERNAME` / `ADMIN_BOOTSTRAP_PASSWORD`。

## Docker

```bash
# 与 API 一起（profile admin）
docker compose --profile admin up -d --build
# Admin: http://localhost:8083
```

Staging：

```bash
docker compose -p bedtime -f docker-compose.staging.yml --profile admin up -d --build
```

构建可选 `ADMIN_UI_API_BASE`（浏览器直连公网 API 时）；默认空字符串，由 nginx 同域反代 `/admin/`。
