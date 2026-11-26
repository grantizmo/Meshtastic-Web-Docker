# Meshtastic Web in Docker

Builds the [Meshtastic Web client](https://github.com/meshtastic/web) from source and serves it with nginx.

The clone happens **inside the Docker build** (BuildKit git source, including the `sdk-kmp` submodule).
The host needs only Docker with Compose, not git, Node or Java.

## Quick start

```powershell
.\build.ps1          # Windows
```
```sh
./build.sh           # Linux / macOS  (or: sh build.sh)
```
…or directly:

```sh
docker compose up -d --build
```

Then open <http://localhost:8080>.

## Configuration (`.env`)

| Variable   | Default                                   | Meaning                                  |
|------------|-------------------------------------------|------------------------------------------|
| `WEB_REF`  | `main`                                    | Branch, tag (e.g. `v2.6.6`) or commit     |
| `WEB_REPO` | `https://github.com/meshtastic/web.git`   | Source repo (to build from a fork)       |
| `WEB_PORT` | `8080`                                    | Host port                                |

Build a specific version once without editing `.env`: `.\build.ps1 -Ref v2.6.6` / `./build.sh v2.6.6`.

## Updating

Run the build script again. BuildKit checks the remote ref on every build, so a new upstream commit triggers a rebuild automatically. If the ref hasn't changed, the cached image is reused.

## How it builds

1. **build stage** (`node:24-bookworm` + Temurin JDK 21):
   `pnpm install` → `pnpm --filter @meshtastic/sdk-kmp build` (Gradle compiles the Kotlin SDK to JS) → `vite build`.
   The pnpm store and Gradle caches are BuildKit cache mounts, so rebuilds are faster.
2. **runtime stage** (`nginx:alpine-slim`): the upstream `apps/web/infra/default.conf` (port 8080, SPA fallback,
   COOP/COEP headers needed for the app's SQLite/OPFS storage) and the built `dist/`.

The first build takes a while (Gradle + Kotlin/JS compile, several minutes) and needs a few GB of RAM for Docker.

## Important: HTTPS / secure context

Browsers only expose **Web Serial and Web Bluetooth** (and SharedArrayBuffer for persistent storage) on a
*secure context*: `https://…` or `http://localhost`.

- Using it on the same machine via `http://localhost:8080` works fully.
- From other machines via `http://<server-ip>:8080`, you can only connect to nodes over **HTTP/WiFi**.
  For Serial or Bluetooth from other machines, put it behind a reverse proxy with TLS (Caddy, Traefik,
  nginx-proxy-manager, etc.).
