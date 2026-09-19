#!/bin/sh
set -e
DATA="$HOME/.local/share/ws-scrcpy-web"
LOG=/tmp/cloudflared.log

pkill -f "cloudflared tunnel --url http://localhost:8000" 2>/dev/null || true
for p in $(lsof -ti tcp:8000 -sTCP:LISTEN); do kill "$p"; done
sleep 1

: > "$LOG"
nohup cloudflared tunnel --url http://localhost:8000 >"$LOG" 2>&1 &

HOST=""
for _ in $(seq 1 30); do
  HOST=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG" | head -1 | sed 's#https://##')
  [ -n "$HOST" ] && break
  sleep 1
done
[ -n "$HOST" ] || { echo "cloudflared did not print a URL, see $LOG" >&2; exit 1; }

node -e '
const fs = require("fs");
const p = process.argv[1];
const c = JSON.parse(fs.readFileSync(p, "utf8"));
c.allowedHosts = [process.argv[2]];
fs.writeFileSync(p, JSON.stringify(c, null, 2) + "\n");
' "$DATA/config.json" "$HOST"

nohup "$(dirname "$0")/start-mac.sh" >/tmp/wssw.log 2>&1 &
for _ in $(seq 1 30); do
  curl -sf -o /dev/null http://localhost:8000/ && break
  sleep 1
done

for _ in $(seq 1 60); do
  [ -n "$(dig +short @1.1.1.1 "$HOST" 2>/dev/null)" ] && break
  sleep 2
done
for _ in $(seq 1 30); do
  [ -n "$(dig +short "$HOST" 2>/dev/null)" ] && break
  dscacheutil -flushcache 2>/dev/null || true
  sleep 5
done

echo "https://$HOST"
