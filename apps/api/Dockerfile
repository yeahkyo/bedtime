# BASE_IMAGE can be overridden when Docker Hub is slow/unreachable, e.g.:
# docker compose build --build-arg BASE_IMAGE=docker.m.daocloud.io/library/python:3.12-slim
ARG BASE_IMAGE=python:3.12-slim
FROM ${BASE_IMAGE}

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# Production default (compose overrides with --reload for local)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD curl -f http://127.0.0.1:8000/health || exit 1
