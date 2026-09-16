#!/usr/bin/env bash
# Local alternative to the webhook: announce the current deploy state via lark-cli.
# Usage: scripts/notify-lark-cli.sh <chat_id> [live_url]
set -euo pipefail
CHAT_ID="${1:?chat_id required (oc_xxx)}"
LIVE="${2:-https://the-asura.github.io/devops-demo/}"
MAIN_SHA=$(git rev-parse origin/main)
LIVE_SHA=$(curl -sf "${LIVE}version.json?t=$(date +%s)" | node -pe 'JSON.parse(require("fs").readFileSync(0)).sha')
if [ "$MAIN_SHA" = "$LIVE_SHA" ]; then STATE="✅ 一致"; else STATE="❌ 不一致，线上落后"; fi
lark-cli im +messages-send --chat-id "$CHAT_ID" --markdown "**DevOps 核对报告**
- 主分支 main：\`${MAIN_SHA:0:7}\`
- 线上运行：\`${LIVE_SHA:0:7}\`
- 结果：${STATE}
- 地址：${LIVE}" --jq '{ok, message_id: .data.message_id}'
