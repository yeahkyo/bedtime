# Lullvale Bedtime

Personalized bilingual bedtime stories with natural TTS and parent voice cloning.

## Stack

- **Flutter** (`apps/mobile`) — iOS first（不进服务器 Docker）
- **FastAPI** (`apps/api`) — **默认 Docker Compose 容器内 uvicorn**
- **MariaDB + Redis**（Compose；生产复用 Linode 同机栈）
- **Object storage**：本地 `.data` / MinIO profile / Cloudflare R2（线上用 R2）
- Providers：豆包 Ark + 火山语音（或 `MOCK_PROVIDERS=1` / `openai` profile）

## Quick start（默认：全容器）

```bash
# Start Docker Desktop, then one command:
docker compose up --build

# API: http://127.0.0.1:8000/docs
# MariaDB host port 3307 · Redis host port 6380
# (Dockerfile 默认用 DaoCloud python 镜像源，避免 Docker Hub 超时；可在 compose 改 BASE_IMAGE)
```

Flutter（连映射出来的 API 端口）：

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

可选 MinIO（网络能拉镜像时）：

```bash
docker compose --profile minio up -d
# 并将 api 的 STORAGE_BACKEND 改为 s3
```

### 可选捷径（非默认）

仅 DB/Redis 在 Compose、API 在宿主机跑时，用 `apps/api/.env` 里的 `127.0.0.1:3307` / `:6380`，再：

```bash
cd apps/api && source .venv/bin/activate
uvicorn app.main:app --reload --port 8000
```

生产与日常联调请优先 **容器内 api**，避免环境漂移。

## Staging / online App testing

Cloudflare orange-cloud → origin **:8080** (co-exists with Bandage on :80). Secrets stay local.

```bash
cp apps/api/.env.staging.example apps/api/.env.staging   # fill secrets locally (gitignored)
./deploy.sh                                              # scp .env + git pull + compose

cd apps/mobile
flutter run --dart-define=API_BASE_URL=https://bedtime-api.lullvale.com
```

Details: [docs/deploy-staging.md](docs/deploy-staging.md).

## Docs

- [Staging deploy](docs/deploy-staging.md)
- [Provider swap guide](docs/providers.md)
- [Privacy / retention](docs/privacy-retention.md)
- [Code review checklist](docs/code-review.md)
