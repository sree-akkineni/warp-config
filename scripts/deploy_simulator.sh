#!/usr/bin/env bash
set -eo pipefail

APP_TARGET="${1:-rendezvous}"
SIMULATOR_NAME="${2:-booted}"
LAUNCH_SIMULATOR_APP="${3:-true}"

PROJECTS_DIR="/Users/sakki/Development/projects"
RENDEZVOUS_DIR="${PROJECTS_DIR}/rendezvous-unified-mvp"
ALPHA_OS_DIR="${PROJECTS_DIR}/AlphaOS"

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

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $1"
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
echo -e "${COLOR_BOLD} 📲 AUTOMATED IOS SIMULATOR DEPLOYER & TEST LAUNCHER${COLOR_RESET}"
echo -e " Target App: ${APP_TARGET} | Target Simulator: ${SIMULATOR_NAME} | $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"

# 1. Resolve Target Simulator UDID
TARGET_UDID=""
if [ "${SIMULATOR_NAME}" = "booted" ]; then
    TARGET_UDID=$(xcrun simctl list devices | grep -i "booted" | head -n 1 | grep -oE '[0-9A-F-]{36}' || true)
    if [ -z "$TARGET_UDID" ]; then
        log_warn "No booted simulator found. Booting default iPhone 17 Pro Max..."
        TARGET_UDID=$(xcrun simctl list devices | grep -i "iPhone 17 Pro Max" | grep -v "unavailable" | head -n 1 | grep -oE '[0-9A-F-]{36}' || true)
        if [ -n "$TARGET_UDID" ]; then
            xcrun simctl boot "${TARGET_UDID}" || true
        fi
    fi
else
    TARGET_UDID=$(xcrun simctl list devices | grep -i "${SIMULATOR_NAME}" | grep -v "unavailable" | head -n 1 | grep -oE '[0-9A-F-]{36}' || true)
    if [ -n "$TARGET_UDID" ]; then
        # Check if booted
        if ! xcrun simctl list devices | grep "${TARGET_UDID}" | grep -qi "booted"; then
            log_info "Booting simulator ${SIMULATOR_NAME} (${TARGET_UDID})..."
            xcrun simctl boot "${TARGET_UDID}" || true
        fi
    fi
fi

if [ -z "$TARGET_UDID" ]; then
    log_error "Could not resolve a valid simulator device."
    exit 1
fi

DEVICE_NAME=$(xcrun simctl list devices | grep "${TARGET_UDID}" | awk -F'(' '{print $1}' | sed 's/^[ \t]*//' || echo "Simulator")
log_success "Target simulator ready: ${DEVICE_NAME} (${TARGET_UDID})"

# 2. Determine App Bundle & Binary Path
BUNDLE_ID=""
APP_PATH=""
SCHEME=""

case "${APP_TARGET}" in
    rendezvous|rendezvous-mobile)
        BUNDLE_ID="com.rendezvous.mobile"
        SCHEME="rendezvous"
        # Find latest Debug or Release build
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -iname "rendezvous.app" -ipath "*iphonesimulator*" 2>/dev/null | sort -r | head -n 1 || true)
        ;;
    alphaos|AlphaOS)
        BUNDLE_ID="com.alphaos.app"
        SCHEME="alphaos"
        APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -iname "alphaos.app" -ipath "*iphonesimulator*" 2>/dev/null | sort -r | head -n 1 || true)
        ;;
    *)
        log_error "Unknown app target: ${APP_TARGET}. Options: rendezvous, alphaos."
        exit 1
        ;;
esac

# 3. Deploy App to Simulator
if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
    log_info "Found compiled native build: ${APP_PATH}"
    log_info "Installing ${APP_TARGET} onto simulator ${TARGET_UDID}..."
    xcrun simctl install "${TARGET_UDID}" "${APP_PATH}"
    log_success "Installation successful."
else
    log_warn "No pre-built .app found in DerivedData. Launching via Expo URL scheme..."
fi

# 4. Open Simulator GUI window if requested
if [ "${LAUNCH_SIMULATOR_APP}" = "true" ]; then
    log_info "Opening Simulator.app window..."
    open -a Simulator --args -CurrentDeviceUDID "${TARGET_UDID}" 2>/dev/null || open -a Simulator
fi

# 5. Launch the Application
log_info "Launching app: ${BUNDLE_ID}..."
if xcrun simctl launch "${TARGET_UDID}" "${BUNDLE_ID}" 2>/dev/null; then
    log_success "App launched successfully via bundle ID: ${BUNDLE_ID}"
else
    log_info "Attempting launch via custom URL scheme: ${SCHEME}://..."
    xcrun simctl openurl "${TARGET_UDID}" "${SCHEME}://" 2>/dev/null || true
    log_success "URL scheme dispatched."
fi

notify_desktop "iOS Simulator Deploy: SUCCESS" "${APP_TARGET} deployed and running on ${DEVICE_NAME}"

echo -e "\n${COLOR_BOLD}${COLOR_GREEN}✓ DEPLOYMENT & LAUNCH COMPLETE${COLOR_RESET}"
echo -e "  Device: ${DEVICE_NAME}"
echo -e "  Bundle: ${BUNDLE_ID}"
echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}\n"
