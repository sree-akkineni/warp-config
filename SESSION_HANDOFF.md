# Session Handoff: Telegram DevOps & System Maintainer Agent Setup

## Context & Standing System State
- **Hardware:** Headless Mac mini (Apple Silicon, 12-core) accessed remotely via Twingate / SSH from MacBook Pro and iPhone (Termius & Telegram).
- **Primary Tool Roles in Stack:**
  - **Warp (Oz on Mac mini):** Host engine, terminal operations, iOS Simulator & build automation, MCP hub, cloud agent fan-out.
  - **Cursor Ultra:** Primary in-editor authoring (whisper IA, Netlify functions, etc.).
  - **Devin Max:** Async PR review gate and autonomous GitHub issues.
  - **OpenClaw:** 24/7 background agent automation on Mac mini (Gateway on port `18789`).
  - **Telegram Bot:** `@srees_coding_bot` (token in `~/.warp/telegram.env`, personal user chat ID: `5944352446`).
- **Repositories managed on Mac mini (`/Users/sakki/Development/projects`):**
  - `rendezvous-unified-mvp` (Sidecar-Tools org)
  - `research-os` (Personal investment research operating system)
  - `AlphaOS` (FastAPI backend + Expo mobile app)
  - `ai-brain` (Knowledge base & Linear credentials)
  - `Akkineni-HQ` (HQ apps & services)

## Completed Infrastructure in `~/.warp` (Repo: `sree-akkineni/warp-config`)
1. **Core Automation CLI Scripts:**
   - `scripts/summary_dashboard.sh` (Aliased as `dashboard`)
   - `scripts/macmini_env.sh` (Aliased as `macmini`)
   - `scripts/remote_build.sh` (Aliased as `build`)
   - `scripts/deploy_simulator.sh` (Aliased as `deploy-sim`)
   - `scripts/capture_simulator_shot.sh` (Aliased as `shot`, `sim-shot`, `screenshot-sim`)
   - `scripts/send_telegram.sh` (Telegram message & photo API dispatcher)
   - `scripts/monitor_anomalies.sh` (Out-of-band resource watchdog running via `launchd`: `dev.warp.anomaly-monitor`)
2. **Warp Workflows:**
   - `summary-dashboard.yaml`
   - `macmini-env-manager.yaml`
   - `remote-build.yaml`
   - `deploy-ios-simulator.yaml`
   - `capture-simulator-screenshot.yaml`
   - `rendezvous-validate.yaml`, `research-os-ops.yaml`, `alphaos-stack.yaml`, `ios-simctl-tools.yaml`

---

## Next Mission: Two-Way Telegram DevOps & System Maintainer Agent

### Goal
Turn `@srees_coding_bot` into an active, intelligent **System Maintainer & DevOps Agent** that listens to incoming messages from Sree on Telegram, executes controlled system tasks on the Mac mini, and explains concepts simply (teaching devops along the way).

### Planned Architecture Options for Next Session
1. **Option 1: OpenClaw Telegram Channel Plugin**
   - Connect OpenClaw's active daemon (`:18789`) to Telegram via OpenClaw plugin.
   - Configure a dedicated system maintenance agent personality (e.g. `SysAdmin / DevOps mentor`).
2. **Option 2: Dedicated Python Telegram Bot Daemon (Long-polling / Webhook)**
   - Lightweight script running as a `launchd` service on Mac mini using `python-telegram-bot` or `telebot`.
   - Wired to trigger:
     - `/dashboard` → Runs `dashboard` and replies with the formatted markdown summary.
     - `/shot` → Captures simulator and sends photo.
     - `/sync` → Runs `macmini repos:sync`.
     - `/build [project]` → Triggers `build` and streams status.
     - Conversational DevOps guidance (backed by Claude / GPT API / local CLI tools) explaining what each command does.
