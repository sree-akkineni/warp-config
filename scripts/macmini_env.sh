#!/usr/bin/env bash
set -eo pipefail

ACTION="${1:-health}"
PARAM2="${2:-}"
PARAM3="${3:-}"

PROJECTS_DIR="/Users/sakki/Development/projects"
RESEARCH_OS_DIR="${PROJECTS_DIR}/research-os"
ALPHA_OS_DIR="${PROJECTS_DIR}/AlphaOS"
RENDEZVOUS_DIR="${PROJECTS_DIR}/rendezvous-unified-mvp"
AI_BRAIN_DIR="${PROJECTS_DIR}/ai-brain"

COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_RED="\033[0;31m"
COLOR_BLUE="\033[0;34m"
COLOR_CYAN="\033[0;36m"
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

print_header() {
    echo "======================================================="
    echo " 🦞 Mac mini Stack & Environment Manager"
    echo "======================================================="
}

check_openclaw() {
    echo -e "\n--- OpenClaw Gateway Status ---"
    if command -v openclaw >/dev/null 2>&1; then
        local status_output
        if status_output=$(openclaw gateway status 2>&1); then
            log_success "OpenClaw CLI & Gateway detected."
            echo "$status_output" | grep -E "(Service|Runtime|Connectivity|Dashboard|Listening|Probe target)" | sed 's/^/  /'
        else
            log_warn "OpenClaw is installed but gateway query returned warnings/errors:"
            echo "$status_output" | sed 's/^/  /'
        fi
    else
        log_error "openclaw binary not found in PATH."
    fi
}

start_openclaw() {
    echo -e "\n--- Starting OpenClaw Gateway ---"
    if pgrep -f "openclaw.*gateway" >/dev/null 2>&1; then
        log_success "OpenClaw gateway process is already running."
    else
        if [ -f "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist" ]; then
            log_info "Loading OpenClaw LaunchAgent..."
            launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist" 2>/dev/null || \
            launchctl load "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist" 2>/dev/null || true
            sleep 2
        else
            log_info "Starting OpenClaw gateway via CLI..."
            nohup openclaw gateway >/tmp/openclaw-startup.log 2>&1 &
            sleep 2
        fi
        check_openclaw
    fi
}

stop_openclaw() {
    echo -e "\n--- Stopping OpenClaw Gateway ---"
    if [ -f "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist" ]; then
        log_info "Unloading OpenClaw LaunchAgent..."
        launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist" 2>/dev/null || \
        launchctl unload "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist" 2>/dev/null || true
    fi
    pkill -f "openclaw.*gateway" 2>/dev/null && log_success "OpenClaw process stopped." || log_info "No active OpenClaw process found."
}

check_ios_sim() {
    echo -e "\n--- iOS Simulator Status ---"
    if command -v xcrun >/dev/null 2>&1; then
        local booted_sims
        booted_sims=$(xcrun simctl list devices | grep -i "booted" || true)
        if [ -n "$booted_sims" ]; then
            log_success "Active booted simulator(s):"
            echo "$booted_sims" | sed 's/^/  /'
        else
            log_warn "No iOS simulator is currently booted."
        fi
    else
        log_error "xcrun / Xcode command line tools not found."
    fi
}

start_ios_sim() {
    local sim_name="${PARAM2:-iPhone 17 Pro}"
    local open_gui="${PARAM3:-false}"
    echo -e "\n--- Booting iOS Simulator: ${sim_name} ---"
    local sim_udid
    sim_udid=$(xcrun simctl list devices | grep -i "${sim_name}" | grep -v "unavailable" | head -n 1 | grep -oE '[0-9A-F-]{36}' || true)

    if [ -z "$sim_udid" ]; then
        log_warn "Could not find exact device '${SIMULATOR_NAME}'. Finding latest available iPhone..."
        sim_udid=$(xcrun simctl list devices | grep -i "iPhone" | grep -v "unavailable" | head -n 1 | grep -oE '[0-9A-F-]{36}' || true)
    fi

    if [ -n "$sim_udid" ]; then
        log_info "Target UDID: ${sim_udid}"
        # Check if already booted
        if xcrun simctl list devices | grep "${sim_udid}" | grep -qi "booted"; then
            log_success "Device (${sim_udid}) is already booted."
        else
            log_info "Booting simulator headless..."
            xcrun simctl boot "${sim_udid}" || true
            log_success "Simulator booted successfully."
        fi

        if [ "$open_gui" = "true" ]; then
            log_info "Launching Simulator.app GUI..."
            open -a Simulator --args -CurrentDeviceUDID "${sim_udid}" 2>/dev/null || open -a Simulator
        fi
    else
        log_error "No compatible iOS simulator device found."
    fi
}

stop_ios_sim() {
    echo -e "\n--- Shutting Down iOS Simulators ---"
    xcrun simctl shutdown all 2>/dev/null || true
    if pgrep -x "Simulator" >/dev/null 2>&1; then
        killall Simulator 2>/dev/null || true
    fi
    log_success "All iOS simulators shut down."
}

check_system_health() {
    echo -e "\n--- Host Health & Remote Access ---"
    echo -n "  Uptime: "
    uptime | awk -F'( |,|:)+' '{if ($7=="days" || $7=="day") {print $6,$7,", load: ",$(NF-2),$(NF-1),$NF} else {print "up", $6 " hrs, load:", $(NF-2),$(NF-1),$NF}}'
    
    # Check Twingate / network listeners
    if pgrep -f -i "twingate" >/dev/null 2>&1; then
        log_success "Twingate service is running."
    else
        log_info "Twingate process check: inactive or running as system daemon."
    fi

    local ip_addr
    ip_addr=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
    echo "  Local IP: ${ip_addr}"
}

sync_repos() {
    echo -e "\n--- Synchronizing Active Repositories (git fetch + pull --rebase) ---"
    local repos=("research-os" "AlphaOS" "rendezvous-unified-mvp" "ai-brain")
    for r in "${repos[@]}"; do
        local dir="${PROJECTS_DIR}/${r}"
        if [ -d "$dir" ]; then
            echo -e "${COLOR_CYAN}>> Syncing ${r}...${COLOR_RESET}"
            git -C "$dir" fetch --prune || true
            local upstream
            upstream=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
            if [ -n "$upstream" ]; then
                git -C "$dir" pull --rebase --autostash || log_warn "Pull encountered an issue in ${r}"
            else
                log_info "No upstream branch tracked for current branch in ${r} (fetched latest remotes)."
            fi
        else
            log_warn "Directory ${dir} does not exist, skipping."
        fi
    done
}

status_repos() {
    echo -e "\n--- Repository Git Status Overview ---"
    local repos=("research-os" "AlphaOS" "rendezvous-unified-mvp" "ai-brain")
    for r in "${repos[@]}"; do
        local dir="${PROJECTS_DIR}/${r}"
        if [ -d "$dir" ]; then
            local branch
            branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
            local status_summary
            status_summary=$(git -C "$dir" status -s 2>/dev/null || true)
            echo -e "${COLOR_CYAN}[${r}]${COLOR_RESET} Branch: ${branch}"
            if [ -z "$status_summary" ]; then
                echo "  Working tree clean."
            else
                echo "$status_summary" | head -n 5 | sed 's/^/  /'
                local extra_lines
                extra_lines=$(echo "$status_summary" | wc -l | tr -d ' ')
                if [ "$extra_lines" -gt 5 ]; then
                    echo "  ... ($extra_lines total changed files)"
                fi
            fi
        fi
    done
}

check_research_os() {
    echo -e "\n--- Research OS Status & Coverage Funnel ---"
    if [ -d "$RESEARCH_OS_DIR" ]; then
        if [ -f "$RESEARCH_OS_DIR/coverage/COVERAGE.md" ]; then
            echo "Current Coverage Registry (active tickers):"
            grep -E "^\| \[" "$RESEARCH_OS_DIR/coverage/COVERAGE.md" | head -n 8 | sed 's/^/  /' || true
        fi
        if [ -n "$FMP_API_KEY" ]; then
            log_success "FMP_API_KEY is exported in environment."
        else
            log_info "FMP_API_KEY is sourced from ai-brain/.env for agent runs."
        fi
    else
        log_error "research-os directory not found at ${RESEARCH_OS_DIR}"
    fi
}

check_alpha_os() {
    echo -e "\n--- AlphaOS Status & Dev Ports ---"
    if [ -d "$ALPHA_OS_DIR" ]; then
        local agent_running="no"
        local mobile_running="no"
        if lsof -i :8000 >/dev/null 2>&1; then
            agent_running="active (port 8000)"
        fi
        if lsof -i :8081 >/dev/null 2>&1; then
            mobile_running="active (port 8081)"
        fi
        echo "  FastAPI Agent: ${agent_running}"
        echo "  Expo Metro:    ${mobile_running}"
    else
        log_error "AlphaOS directory not found at ${ALPHA_OS_DIR}"
    fi
}

print_header

case "${ACTION}" in
    start|up)
        start_openclaw
        start_ios_sim
        check_system_health
        ;;
    health|status)
        check_openclaw
        check_ios_sim
        check_research_os
        check_alpha_os
        check_system_health
        ;;
    stop|down)
        stop_ios_sim
        stop_openclaw
        ;;
    restart)
        stop_ios_sim
        stop_openclaw
        sleep 2
        start_openclaw
        start_ios_sim
        check_system_health
        ;;
    repos:sync|sync)
        sync_repos
        ;;
    repos:status|repos)
        status_repos
        ;;
    research|research:status)
        check_research_os
        ;;
    alphaos|alphaos:status)
        check_alpha_os
        ;;
    *)
        echo "Usage: $0 [health|start|stop|restart|repos:sync|repos:status|research|alphaos] [simulator_device] [open_gui:true|false]"
        exit 1
        ;;
esac

echo -e "\n${COLOR_GREEN}✓ Task complete.${COLOR_RESET}\n"
