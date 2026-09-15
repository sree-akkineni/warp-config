#!/usr/bin/env bash
set -eo pipefail

MESSAGE="${1:-}"
PHOTO_PATH="${2:-}"

# Load credentials from environment or ~/.warp/telegram.env
TELEGRAM_ENV_FILE="$HOME/.warp/telegram.env"
if [ -f "$TELEGRAM_ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$TELEGRAM_ENV_FILE"
fi

BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT_ID="${TELEGRAM_CHAT_ID:-}"

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "[WARN] Telegram credentials not configured."
    echo "To enable Telegram notifications, create $HOME/.warp/telegram.env with:"
    echo "  TELEGRAM_BOT_TOKEN=\"your_bot_token\""
    echo "  TELEGRAM_CHAT_ID=\"your_chat_id\""
    exit 0
fi

# 1. Send photo if specified and exists
if [ -n "$PHOTO_PATH" ] && [ -f "$PHOTO_PATH" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto" \
        -F "chat_id=${CHAT_ID}" \
        -F "photo=@${PHOTO_PATH}" \
        -F "caption=${MESSAGE}" >/dev/null 2>&1 || true
elif [ -n "$MESSAGE" ]; then
    # 2. Send text message
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${MESSAGE}" \
        -d "parse_mode=Markdown" >/dev/null 2>&1 || true
fi
