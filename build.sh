#!/usr/bin/env sh
# Builds (or rebuilds) the Meshtastic Web image from the latest upstream source and starts it.
# Usage:  ./build.sh            # builds WEB_REF from .env (default: main)
#         ./build.sh v2.6.6     # build a specific tag/branch/commit
set -e
cd "$(dirname "$0")"

[ -n "$1" ] && export WEB_REF="$1"

docker compose build --pull
docker compose up -d

PORT="${WEB_PORT:-$(grep -E '^WEB_PORT=' .env | cut -d= -f2)}"
echo
echo "Meshtastic Web is running at http://localhost:${PORT:-8080}"
