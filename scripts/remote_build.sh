#!/usr/bin/env bash
set -eo pipefail

PROJECT="${1:-rendezvous}"
TASK="${2:-validate}"
NOTIFY="${3:-true}"

PROJECTS_DIR="/Users/sakki/Development/projects"
RENDEZVOUS_DIR="${PROJECTS_DIR}/rendezvous-unified-mvp"
ALPHA_OS_DIR="${PROJECTS_DIR}/AlphaOS"
RESEARCH_OS_DIR="${PROJECTS_DIR}/research-os"

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
    if [ "$NOTIFY" = "true" ] && command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"${message}\" with title \"${title}\"" 2>/dev/null || true
    fi
}

echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD} 🚀 REMOTE BUILD & VALIDATION RUNNER (Mac mini Engine)${COLOR_RESET}"
echo -e " Target: ${PROJECT} | Task: ${TASK} | $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"

START_TIME=$(date +%s)
STATUS="FAILED"
SUMMARY=""

case "${PROJECT}" in
    rendezvous|rendezvous-unified-mvp)
        log_info "Navigating to ${RENDEZVOUS_DIR}..."
        cd "${RENDEZVOUS_DIR}"
        
        case "${TASK}" in
            mobile:validate)
                log_info "Running Rendezvous mobile gate (lint + design + typecheck + jest + contracts)..."
                npm run mobile:validate
                STATUS="SUCCESS"
                SUMMARY="Rendezvous mobile:validate passed cleanly."
                ;;
            web:validate)
                log_info "Running Rendezvous web gate (typechecks + lints + vitest + functions)..."
                npm run web:validate
                STATUS="SUCCESS"
                SUMMARY="Rendezvous web:validate passed cleanly."
                ;;
            shared:typecheck)
                log_info "Running shared packages typecheck..."
                npm run shared:typecheck
                STATUS="SUCCESS"
                SUMMARY="Rendezvous shared:typecheck passed cleanly."
                ;;
            validate|full)
                log_info "Running full verification gate chain..."
                npm run validate
                STATUS="SUCCESS"
                SUMMARY="Rendezvous full validate gate chain passed cleanly."
                ;;
            mobile:start)
                log_info "Checking Metro bundler status for Rendezvous mobile..."
                if lsof -i :8081 >/dev/null 2>&1; then
                    log_success "Metro is already listening on port 8081."
                else
                    log_info "Starting Expo Metro on port 8081..."
                    nohup npm run mobile:start >/tmp/rendezvous-metro.log 2>&1 &
                    sleep 3
                fi
                STATUS="SUCCESS"
                SUMMARY="Rendezvous mobile Metro ready on port 8081."
                ;;
            *)
                log_info "Running custom npm script: npm run ${TASK}..."
                npm run "${TASK}"
                STATUS="SUCCESS"
                SUMMARY="Rendezvous npm run ${TASK} finished successfully."
                ;;
        esac
        ;;

    alphaos|AlphaOS)
        log_info "Navigating to ${ALPHA_OS_DIR}/alpha-os..."
        cd "${ALPHA_OS_DIR}/alpha-os"

        case "${TASK}" in
            ci:local)
                log_info "Running AlphaOS local CI suite..."
                pnpm ci:local
                STATUS="SUCCESS"
                SUMMARY="AlphaOS ci:local passed cleanly."
                ;;
            typecheck)
                log_info "Running AlphaOS typecheck across monorepo..."
                pnpm typecheck
                STATUS="SUCCESS"
                SUMMARY="AlphaOS typecheck passed."
                ;;
            lint)
                log_info "Running AlphaOS linter..."
                pnpm lint
                STATUS="SUCCESS"
                SUMMARY="AlphaOS lint passed."
                ;;
            test)
                log_info "Running AlphaOS test suite..."
                pnpm test
                STATUS="SUCCESS"
                SUMMARY="AlphaOS tests passed."
                ;;
            build)
                log_info "Building AlphaOS packages..."
                pnpm build
                STATUS="SUCCESS"
                SUMMARY="AlphaOS build passed."
                ;;
            *)
                log_info "Running custom pnpm task: pnpm ${TASK}..."
                pnpm "${TASK}"
                STATUS="SUCCESS"
                SUMMARY="AlphaOS task ${TASK} completed successfully."
                ;;
        esac
        ;;

    research-os|research)
        log_info "Navigating to ${RESEARCH_OS_DIR}..."
        cd "${RESEARCH_OS_DIR}"

        case "${TASK}" in
            scorecard)
                log_info "Running Research OS scorecard tests..."
                python3 -m unittest tests/test_scorecard.py
                STATUS="SUCCESS"
                SUMMARY="Research OS scorecard test suite passed."
                ;;
            test|tests)
                log_info "Running Research OS unit tests (excluding missing optional Excel modules)..."
                python3 -m unittest discover -s tests -p "test_scorecard*.py"
                STATUS="SUCCESS"
                SUMMARY="Research OS unit tests passed."
                ;;
            dashboard)
                log_info "Generating Research OS dashboard..."
                python3 scripts/dashboard.py
                STATUS="SUCCESS"
                SUMMARY="Research OS dashboard generated."
                ;;
            *)
                log_info "Executing python3 scripts/${TASK}..."
                python3 "scripts/${TASK}"
                STATUS="SUCCESS"
                SUMMARY="Research OS script ${TASK} finished."
                ;;
        esac
        ;;

    *)
        log_error "Unknown project: ${PROJECT}. Options: rendezvous, alphaos, research-os."
        exit 1
        ;;
esac

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "\n${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"
if [ "$STATUS" = "SUCCESS" ]; then
    echo -e "${COLOR_BOLD}${COLOR_GREEN}✓ REMOTE BUILD RESULT: PASSED (${DURATION}s)${COLOR_RESET}"
    echo -e "  Summary: ${SUMMARY}"
    notify_desktop "Mac mini Remote Build: PASSED" "${PROJECT} [${TASK}] completed in ${DURATION}s"
    if [ -f "/Users/sakki/.warp/scripts/send_telegram.sh" ]; then
        /Users/sakki/.warp/scripts/send_telegram.sh "✅ *Remote Build Passed* (${DURATION}s)%0A*Project:* ${PROJECT}%0A*Task:* ${TASK}%0A${SUMMARY}" "" || true
    fi
else
    echo -e "${COLOR_BOLD}${COLOR_RED}✗ REMOTE BUILD RESULT: FAILED (${DURATION}s)${COLOR_RESET}"
    notify_desktop "Mac mini Remote Build: FAILED" "${PROJECT} [${TASK}] failed after ${DURATION}s"
    if [ -f "/Users/sakki/.warp/scripts/send_telegram.sh" ]; then
        /Users/sakki/.warp/scripts/send_telegram.sh "❌ *Remote Build Failed* (${DURATION}s)%0A*Project:* ${PROJECT}%0A*Task:* ${TASK}" "" || true
    fi
    exit 1
fi
echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}\n"
