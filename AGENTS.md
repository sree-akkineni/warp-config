# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Overview & Big Picture Architecture

`~/.warp` is the central orchestration repository and environment manager for the Mac mini execution engine (`sakki` host) and connected client machines (such as MacBook Pro over Twingate). It does not contain application business logic directly; instead, it coordinates external multi-repository development stacks, background agent daemons, iOS simulators, and executive reporting.

```
~/.warp
├── bin/                 # Executable symlinks exposed to system PATH
├── init.sh              # Shell bootstrap sourcing PATH additions and aliases
├── scripts/             # Core automation and environment management scripts
├── workflows/           # Warp Command Search YAML definitions (Ctrl + Shift + R)
├── tab_configs/         # Multi-pane terminal and agent workspace layouts (TOML)
├── screenshots/         # Target output for simulator captures (includes latest.png)
├── settings.toml        # Warp application, privacy, and agent execution profile settings
├── telegram.env         # Local Telegram bot secrets (git-ignored)
└── telegram.env.example # Credential template for TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID
```

### Multi-Project & Service Topology

The scripts and workflows in this repo directly control and integrate with projects located in `/Users/sakki/Development/projects`:

* **`rendezvous-unified-mvp`**: React Native / Expo mobile app (`apps/mobile`), Netlify functions (`:9999`), and web app. Targeted by `deploy_simulator.sh` (bundle ID `com.rendezvous.mobile`, scheme `rendezvous://`) and `remote_build.sh` (`mobile:validate`, `web:validate`, `shared:typecheck`, `validate`).
* **`AlphaOS`**: Monorepo with FastAPI agent backend (`:8000`) and Expo Metro (`:8081`). Targeted by `deploy_simulator.sh` (bundle ID `com.alphaos.app`, scheme `alphaos://`) and `remote_build.sh` (`ci:local`, `typecheck`, `lint`, `test`, `build`).
* **`research-os`**: Python valuation model registry and decision memo pipeline (`coverage/`). Targeted by `remote_build.sh` (`scorecard`, `tests`, `dashboard`).
* **`ai-brain`**: Contains `.env` storing `LINEAR_API_KEY` (used by `summary_dashboard.sh` to query Linear GraphQL API) and `FMP_API_KEY`.
* **`Akkineni-HQ` & `corp-dev`**: Git status tracked in `summary_dashboard.sh`.

### Agent Daemons & Hardware Integrations

* **OpenClaw Gateway**: Local agent daemon listening on port `18789`. Controlled via `openclaw gateway` or `~/Library/LaunchAgents/ai.openclaw.gateway.plist` through `scripts/macmini_env.sh`.
* **iOS Simulators (`xcrun simctl`)**: Booted, shut down, inspected, and deployed to. DerivedData is scanned under `~/Library/Developer/Xcode/DerivedData` for built `.app` bundles, falling back to custom URL scheme dispatch.
* **Notification Layer**: Dual dispatch. macOS desktop notifications via `osascript`, and Telegram bot photo/text alerts via `scripts/send_telegram.sh` reading credentials from `~/.warp/telegram.env`.
* **Warp Command Layer**: Workflows in `workflows/*.yaml` expose parameterized actions in Warp Command Search (`Ctrl + Shift + R`). Tab configurations in `tab_configs/*.toml` open pre-configured split panes combining standard terminals and Warp Oz agent panes.

---

## Commonly Used Commands & Development Workflows

### Syntax & Integrity Validation

When modifying scripts, workflows, or tab configs in this repository, run the following verification commands:

```bash
# Validate bash syntax across all scripts
bash -n init.sh scripts/*.sh

# Validate YAML syntax for all Warp workflow definitions
ruby -ryaml -e 'Dir.glob("workflows/*.yaml") { |f| YAML.load_file(f) }; puts "Workflows YAML valid"'

# Validate TOML syntax for all tab workspace configurations
python3 -c 'import tomllib, glob; [tomllib.load(open(f, "rb")) for f in glob.glob("tab_configs/*.toml")]; print("Tab configs TOML valid")'
```

### Executive Summary Dashboard

Gathers live status of OpenClaw, Grok, coding agents, booted iOS simulators, Twingate, git status across all 6 project repos, open GitHub PRs via `gh`, and active Linear tasks via GraphQL:

```bash
dashboard
# or
./scripts/summary_dashboard.sh
```

### Stack & Environment Manager (`macmini`)

Manages services, simulators, and repository synchronization:

```bash
macmini [action] [param2] [param3]
# or
./scripts/macmini_env.sh [action]
```

* `macmini health` (or `status`): Full health check across OpenClaw, simulators, Research OS coverage registry, AlphaOS ports (`:8000`, `:8081`), and host load.
* `macmini repos:sync`: Fetches and rebases (`git fetch --prune` + `git pull --rebase --autostash`) `research-os`, `AlphaOS`, `rendezvous-unified-mvp`, and `ai-brain`.
* `macmini repos:status`: Reports active branches and uncommitted changes across target repos.
* `macmini start [device_name] [open_gui]`: Boots target simulator (default: `"iPhone 17 Pro"`, headless by default; set `open_gui` to `true` to display Simulator.app) and starts OpenClaw gateway.
* `macmini stop`: Shuts down all iOS simulators and terminates OpenClaw gateway.
* `macmini restart`: Performs clean teardown and restart of simulators and OpenClaw.
* `macmini research`: Checks Research OS active coverage registry and FMP environment key.
* `macmini alphaos`: Checks port bindings for AlphaOS FastAPI (`:8000`) and Expo Metro (`:8081`).

### Remote Build & Verification Runner (`build`)

Triggers test suites, linters, and verification gates across connected projects, dispatching desktop and Telegram notifications on completion:

```bash
build [project] [task] [notify:true|false]
# or
./scripts/remote_build.sh [project] [task] [notify]
```

* **Rendezvous tasks**:
  * `build rendezvous mobile:validate` (lint + design audit + typecheck + jest + contracts)
  * `build rendezvous web:validate` (typecheck + lint + vitest + functions)
  * `build rendezvous shared:typecheck` (monorepo shared packages typecheck)
  * `build rendezvous validate` (runs full verification gate chain)
  * `build rendezvous mobile:start` (verifies/launches Metro on `:8081`)
* **AlphaOS tasks**:
  * `build alphaos ci:local` (runs complete local CI check)
  * `build alphaos typecheck`
  * `build alphaos lint`
  * `build alphaos test`
  * `build alphaos build`
* **Research OS tasks**:
  * `build research-os scorecard` (runs `tests/test_scorecard.py`)
  * `build research-os test` (discovers and runs `test_scorecard*.py` test suite)
  * `build research-os dashboard` (runs `scripts/dashboard.py`)

### iOS Simulator Deployment (`deploy-sim`)

Finds the latest compiled `.app` in Xcode DerivedData, installs it to the target simulator, launches via bundle ID or URL scheme, and optionally brings the GUI to the foreground:

```bash
deploy-sim [app] [simulator_name] [open_gui:true|false]
# or
./scripts/deploy_simulator.sh [app] [simulator_name] [open_gui]

# Examples:
deploy-sim rendezvous booted true
deploy-sim alphaos "iPhone 17 Pro" true
```

### Simulator Screenshot Capture (`screenshot-sim`)

Captures a high-resolution screenshot from the target simulator, saves to `~/.warp/screenshots/<timestamp>-<label>.png`, updates the `latest.png` symlink, dispatches a macOS banner, and sends the image via Telegram:

```bash
screenshot-sim [label] [simulator_name] [custom_folder]
# or
./scripts/capture_simulator_shot.sh [label] [simulator_name] [custom_folder]

# Examples:
screenshot-sim review
screenshot-sim login-screen booted
```

### Telegram Notifications (`notify-telegram`)

Sends text or image alerts via Telegram Bot API using credentials in `~/.warp/telegram.env`:

```bash
notify-telegram "Message text" [path/to/image.png]
# or
./scripts/send_telegram.sh "Message text" [path/to/image.png]
```
