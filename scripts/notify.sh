#!/usr/bin/env bash
# Notify Feishu from CI. Usage: scripts/notify.sh <success|failure|info> <title> <markdown>
# Prefers lark-cli (bot identity, needs LARK_APP_ID/LARK_APP_SECRET/LARK_CHAT_ID);
# falls back to custom-bot webhook (FEISHU_WEBHOOK/FEISHU_SECRET); skips if neither is set.
set -euo pipefail
STATUS="$1"; TITLE="$2"; BODY="$3"
if [ -n "${LARK_APP_ID:-}" ] && [ -n "${LARK_APP_SECRET:-}" ] && [ -n "${LARK_CHAT_ID:-}" ]; then
  command -v lark-cli >/dev/null || npm i -g @larksuite/cli >/dev/null 2>&1
  printf '%s' "$LARK_APP_SECRET" | lark-cli config init --app-id "$LARK_APP_ID" --app-secret-stdin --brand feishu >/dev/null
  lark-cli im +messages-send --as bot --chat-id "$LARK_CHAT_ID" --markdown "**${TITLE}**
${BODY}" --jq '{ok}'
elif [ -n "${FEISHU_WEBHOOK:-}" ]; then
  node scripts/notify-feishu.mjs "$STATUS" "$TITLE" "$BODY"
else
  echo "no Feishu credentials configured, skip notify"
fi
