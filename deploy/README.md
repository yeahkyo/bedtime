# Deploy notes

- Entry: [`../deploy.sh`](../deploy.sh) — scp local `apps/api/.env.staging` → remote `apps/api/.env`, then git + compose  
- Docs: [docs/deploy-staging.md](../docs/deploy-staging.md)  
- Compose: [docker-compose.staging.yml](../docker-compose.staging.yml) — default `${API_HOST_PORT:-8080}:8000`  

TLS edge: Cloudflare orange-cloud (SSL **Full**). No on-box Caddy/nginx required.
