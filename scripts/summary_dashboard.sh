#!/usr/bin/env bash
set -eo pipefail

COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_RED="\033[0;31m"
COLOR_BLUE="\033[0;34m"
COLOR_CYAN="\033[0;36m"
COLOR_BOLD="\033[1m"
COLOR_RESET="\033[0m"

PROJECTS_DIR="/Users/sakki/Development/projects"
REPOS=("rendezvous-unified-mvp" "research-os" "AlphaOS" "ai-brain" "Akkineni-HQ" "corp-dev")

echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"
echo -e "${COLOR_BOLD} 📊 MAC MINI COMMAND CENTER & MULTI-AGENT SUMMARY DASHBOARD${COLOR_RESET}"
echo -e " Host: $(hostname) | $(date '+%Y-%m-%d %H:%M:%S %Z') | Uptime: $(uptime | awk -F'( |,|:)+' '{if ($7=="days" || $7=="day") {print $6,$7} else {print $6 " hrs"}}')"
echo -e "${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"

# -----------------------------------------------------------------------------
# SECTION 1: ACTIVE AGENT & SYSTEM PROCESSES
# -----------------------------------------------------------------------------
echo -e "\n${COLOR_BOLD}${COLOR_CYAN}🤖 [1/3] ACTIVE AGENTS & BACKGROUND DAEMONS${COLOR_RESET}"
echo "----------------------------------------------------------------------"

# 1. OpenClaw Gateway
if pgrep -f "openclaw.*gateway" >/dev/null 2>&1; then
    OPENCLAW_PID=$(pgrep -f "openclaw.*gateway" | head -n 1)
    echo -e "  🦞 ${COLOR_GREEN}● OpenClaw Gateway${COLOR_RESET}     : RUNNING (PID: ${OPENCLAW_PID}, Port: 18789)"
else
    echo -e "  🦞 ${COLOR_RED}○ OpenClaw Gateway${COLOR_RESET}     : STOPPED"
fi

# 2. Grok Bot / CLI Runners
GROK_PIDS=$(pgrep -f "grok" 2>/dev/null || true)
if [ -n "$GROK_PIDS" ]; then
    echo -e "  ⚡ ${COLOR_GREEN}● Grok Supervisor / CLI${COLOR_RESET} : ACTIVE (PIDs: $(echo $GROK_PIDS | tr '\n' ' '))"
else
    echo -e "  ⚡ ${COLOR_YELLOW}○ Grok Supervisor${COLOR_RESET}       : IDLE (on standby for dispatch)"
fi

# 3. Cursor / Claude / Other Agent Runners
AGENT_PIDS=$(pgrep -f "cursor.*agent|claude.*agent|devin" 2>/dev/null || true)
if [ -n "$AGENT_PIDS" ]; then
    echo -e "  🧠 ${COLOR_GREEN}● Coding Agent Runners${COLOR_RESET}  : ACTIVE (PIDs: $(echo $AGENT_PIDS | tr '\n' ' '))"
else
    echo -e "  🧠 ${COLOR_YELLOW}○ Coding Agent Runners${COLOR_RESET}  : IDLE (no active CLI sessions running)"
fi

# 4. iOS Simulators
BOOTED_SIMS=$(xcrun simctl list devices 2>/dev/null | grep -i "booted" | sed 's/^[ \t]*//' || true)
if [ -n "$BOOTED_SIMS" ]; then
    echo -e "  📱 ${COLOR_GREEN}● iOS Simulators${COLOR_RESET}        : BOOTED"
    echo "$BOOTED_SIMS" | while IFS= read -r line; do
        echo -e "     ↳ ${COLOR_GREEN}${line}${COLOR_RESET}"
    done
else
    echo -e "  📱 ${COLOR_YELLOW}○ iOS Simulators${COLOR_RESET}        : ALL SHUT DOWN"
fi

# 5. Remote Access (Twingate / SSH)
if pgrep -f -i "twingate" >/dev/null 2>&1; then
    echo -e "  🛡️ ${COLOR_GREEN}● Twingate Connector${COLOR_RESET}   : CONNECTED"
else
    echo -e "  🛡️ ${COLOR_YELLOW}○ Twingate Connector${COLOR_RESET}   : SYSTEM DAEMON / UNKNOWN"
fi

# -----------------------------------------------------------------------------
# SECTION 2: GITHUB REPOSITORIES & OPEN PRS
# -----------------------------------------------------------------------------
echo -e "\n${COLOR_BOLD}${COLOR_CYAN}🐙 [2/3] GITHUB REPOSITORIES & PULL REQUESTS${COLOR_RESET}"
echo "----------------------------------------------------------------------"

for r in "${REPOS[@]}"; do
    REPO_DIR="${PROJECTS_DIR}/${r}"
    if [ -d "$REPO_DIR" ]; then
        BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
        DIRTY_COUNT=$(git -C "$REPO_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        
        if [ "$DIRTY_COUNT" -eq 0 ]; then
            STATUS_STR="${COLOR_GREEN}clean${COLOR_RESET}"
        else
            STATUS_STR="${COLOR_YELLOW}${DIRTY_COUNT} uncommitted changes${COLOR_RESET}"
        fi
        
        printf "  %-24s : branch %-22s [%b]\n" "$r" "${COLOR_BOLD}${BRANCH}${COLOR_RESET}" "$STATUS_STR"
    fi
done

echo -e "\n  ${COLOR_BOLD}Open Pull Requests (Authored by you):${COLOR_RESET}"
if command -v gh >/dev/null 2>&1; then
    PRS=$(gh search prs --author "@me" --state open --limit 5 --json number,title,repository 2>/dev/null || true)
    if [ -n "$PRS" ] && [ "$PRS" != "[]" ]; then
        python3 -c "
import json, sys
try:
    data = json.loads('''$PRS''')
    for pr in data:
        repo = pr.get('repository', {}).get('name', 'unknown')
        num = pr.get('number')
        title = pr.get('title', '')
        print(f'   ↳ #{num} in {repo}: {title}')
except Exception as e:
    pass
"
    else
        echo "   (No open PRs found)"
    fi
else
    echo "   (gh CLI not available)"
fi

# -----------------------------------------------------------------------------
# SECTION 3: LINEAR ACTIVE WORKSTREAM
# -----------------------------------------------------------------------------
echo -e "\n${COLOR_BOLD}${COLOR_CYAN}📐 [3/3] LINEAR ACTIVE TASKS (In Progress & Todo)${COLOR_RESET}"
echo "----------------------------------------------------------------------"

LINEAR_KEY=""
if [ -f "/Users/sakki/Development/projects/ai-brain/.env" ]; then
    LINEAR_KEY=$(grep -E "^LINEAR_API_KEY=" /Users/sakki/Development/projects/ai-brain/.env | cut -d'=' -f2- | tr -d ' "\r\n' || true)
fi

if [ -n "$LINEAR_KEY" ]; then
    python3 -c "
import urllib.request, json

key = '''$LINEAR_KEY'''
query = '''
query {
  issues(first: 6, filter: { state: { type: { nin: [\"completed\", \"canceled\"] } } }) {
    nodes {
      identifier
      title
      state { name type }
      project { name }
    }
  }
}
'''

try:
    req = urllib.request.Request(
        'https://api.linear.app/graphql',
        data=json.dumps({'query': query}).encode('utf-8'),
        headers={'Content-Type': 'application/json', 'Authorization': key}
    )
    with urllib.request.urlopen(req, timeout=5) as resp:
        res = json.loads(resp.read().decode('utf-8'))
        nodes = res.get('data', {}).get('issues', {}).get('nodes', [])
        if not nodes:
            print('  (No active Linear issues found)')
        for issue in nodes:
            ident = issue.get('identifier')
            title = issue.get('title')
            state_name = issue.get('state', {}).get('name')
            state_type = issue.get('state', {}).get('type')
            color_code = '\033[0;32m' if state_type == 'started' else '\033[0;33m'
            reset = '\033[0m'
            print(f'  • {color_code}[{ident}]{reset} {title} - {color_code}{state_name}{reset}')
except Exception as e:
    print(f'  (Failed to query Linear API: {e})')
"
else
    echo "  (LINEAR_API_KEY not found in ai-brain/.env)"
fi

echo -e "\n${COLOR_BOLD}${COLOR_BLUE}======================================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}✓ Dashboard refresh complete.${COLOR_RESET}\n"
