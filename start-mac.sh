#!/bin/sh
cd "$(dirname "$0")"
[ -d dist ] || npm run build
exec env DATA_ROOT="$HOME/.local/share/ws-scrcpy-web" node dist/index.js
