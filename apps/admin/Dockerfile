# Build static admin UI; runtime serves with nginx.
# Build arg VITE_API_BASE: public API origin (empty = same-origin via nginx /admin/ proxy).
#
# If docker.io pulls fail, pass:
#   --build-arg REGISTRY_PREFIX=docker.m.daocloud.io/library/

ARG REGISTRY_PREFIX=
FROM ${REGISTRY_PREFIX}node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN --mount=type=cache,target=/root/.npm \
    if [ -f package-lock.json ]; then npm ci; else npm install; fi
COPY . .
ARG VITE_API_BASE=
ENV VITE_API_BASE=$VITE_API_BASE
RUN npm run build

FROM ${REGISTRY_PREFIX}nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
