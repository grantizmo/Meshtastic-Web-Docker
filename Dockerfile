# syntax=docker/dockerfile:1.7
#
# Self-contained build of the Meshtastic Web client (https://github.com/meshtastic/web).
# The source is cloned inside the build (with submodules), so the host needs nothing but Docker.
#
#   Stage 1 (build): Node 24 + pnpm + JDK 21 -> builds the Kotlin SDK (Gradle) and the Vite app
#   Stage 2 (runtime): nginx serving the static files on port 8080
#
# Build args:
#   WEB_REPO  git URL of the repo (default: upstream)
#   WEB_REF   branch, tag or commit to build (default: main)

ARG NODE_VERSION=24

############################
# Stage 1: build
############################
FROM node:${NODE_VERSION}-bookworm AS build

ARG WEB_REPO=https://github.com/meshtastic/web.git
ARG WEB_REF=main

# JDK 21 for the Kotlin Multiplatform SDK (packages/sdk-kmp).
# (git, used for version labels, already ships in node:*-bookworm.)
COPY --from=eclipse-temurin:21-jdk /opt/java/openjdk /opt/java/openjdk
ENV JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:$PATH \
    HUSKY=0 \
    CI=true

# BuildKit git source: fetches the ref plus submodules, and re-checks the remote on
# every build, so a new upstream commit automatically invalidates the cache.
ADD --keep-git-dir=true ${WEB_REPO}#${WEB_REF} /src
WORKDIR /src

# Make sure the submodule is present even if the git source skipped it.
RUN git config --global --add safe.directory '*' \
 && git submodule update --init --recursive || true

# Install the exact pnpm version pinned in package.json ("packageManager").
RUN npm install -g "$(node -p "require('./package.json').packageManager")"

RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

# Kotlin SDK -> JS (Gradle downloads its own toolchain deps; cache them between builds)
RUN --mount=type=cache,id=gradle,target=/root/.gradle \
    pnpm --filter @meshtastic/sdk-kmp build

# Web app
RUN pnpm --filter meshtastic-web build

############################
# Stage 2: runtime
############################
FROM nginx:alpine-slim AS runtime

RUN rm -rf /usr/share/nginx/html && mkdir -p /usr/share/nginx/html

# Upstream nginx config (port 8080, SPA fallback, COOP/COEP headers for SQLite OPFS storage)
COPY --from=build /src/apps/web/infra/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/apps/web/dist /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
