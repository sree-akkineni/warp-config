#!/usr/bin/env bash
set -eo pipefail

LABEL="${1:-review}"
TARGET_SIM="${2:-booted}"
CUSTOM_DEST="${3:-}"

DEFAULT_SCREENSHOT_DIR="/Users/sakki/.warp/screenshots"
DEST_DIR="${CUSTOM_DEST:-$DEFAULT_SCREENSHOT_DIR}"

COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_RED="\033[0;31m"
COLOR_BLUE="\033[0;34m"
COLOR_BOLD="\033[1m"
COLOR_RESET="\033[0m"

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

log_success() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $1"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $1"
}

notify_desktop() {
    local title="$1"
    local message="$2"
    if command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"${message}\" with title \"${title}\"" 2>/dev/null || true
    fi
}

echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD} 📸 IOS SIMULATOR SCREENSHOT CAPTURE & REMOTE REVIEW EXPORTER${COLOR_RESET}"
echo -e " Label: ${LABEL} | Target: ${TARGET_SIM} | $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"

# 1. Resolve Target Simulator UDID
TARGET_UDID=""
if [ "${TARGET_SIM}" = "booted" ]; then
    TARGET_UDID=$(xcrun simctl list devices | grep -i "booted" | head -n 1 | grep -oE '[0-9A-F-]{36}' || true)
else
    TARGET_UDID=$(xcrun simctl list devices | grep -i "${TARGET_SIM}" | grep -v "unavailable" | head -n 1 | grep -oE '[0-9A-F-]{36}' || true)
fi

if [ -z "$TARGET_UDID" ]; then
    log_error "No booted simulator found. Boot an iOS simulator first."
    exit 1
fi

DEVICE_NAME=$(xcrun simctl list devices | grep "${TARGET_UDID}" | awk -F'(' '{print $1}' | sed 's/^[ \t]*//' || echo "Simulator")
log_success "Attached to simulator: ${DEVICE_NAME} (${TARGET_UDID})"

# 2. Ensure destination folder exists
mkdir -p "${DEST_DIR}"

# 3. Generate timestamped file name
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SAFE_LABEL=$(echo "${LABEL}" | tr ' /' '_-')
FILENAME="${TIMESTAMP}-${SAFE_LABEL}.png"
FILEPATH="${DEST_DIR}/${FILENAME}"

# 4. Capture screenshot via simctl
log_info "Capturing screenshot..."
xcrun simctl io "${TARGET_UDID}" screenshot "${FILEPATH}"

# Also maintain a symlink to 'latest.png' for instant review
ln -sf "${FILEPATH}" "${DEST_DIR}/latest.png"

FILE_SIZE=$(ls -lh "${FILEPATH}" | awk '{print $5}')
log_success "Screenshot saved: ${FILEPATH} (${FILE_SIZE})"
log_success "Updated shortcut: ${DEST_DIR}/latest.png"

# 5. Dispatch notification
notify_desktop "iOS Screenshot Captured" "${FILENAME} ready for remote review in ${DEST_DIR}"

echo -e "\n${COLOR_BOLD}${COLOR_GREEN}✓ CAPTURE & EXPORT COMPLETE${COLOR_RESET}"
echo -e "  File:   ${FILEPATH}"
echo -e "  Latest: ${DEST_DIR}/latest.png"
echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}\n"
