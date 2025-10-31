# Claude & Codex CLIs via Docker on Windows — Minimal Runner (Compose)

## 🚀 Quickstart

**Prerequisites**

* **Docker Desktop for Windows** (WSL2 backend recommended)
* PowerShell and/or Command Prompt (CMD)
* Add `your-repo\scripts` to your **PATH** (recommended).
  If you don’t, replace `claude` with `.\scripts\claude` (and similarly for other commands below).

**One-time setup**

```powershell
# 1) Build the image
docker compose build

# 2) Sign in once per CLI
claude           # follows browser flow; creds persist in volume
codex-login      # special helper that enables OAuth callback on Windows; creds persist
```

**Enable Playwright MCP (headless Chromium)**

```powershell
# 3) Register the Playwright MCP server for each CLI
claude-mcp-playwright         # registers: --browser chromium --headless --isolated --no-sandbox
codex-mcp-playwright          # same for Codex
```

**Use it**

```powershell
# 4) Run either CLI
claude
codex

# 5) Ask the CLI to browse via Playwright MCP (example)
# In the CLI prompt, type:
# “Using the Playwright MCP server, open https://example.com and return the page title.”
```

> PowerShell tip: if your command line includes `| > & <`, add `--%` after `claude` or `codex` to stop PS parsing.

---

This README explains **how to use** the repository’s Docker/Compose setup to run:

* **Claude Code (CLI)**
* **OpenAI Codex CLI** (incl. a special **OAuth login helper**)
* **Playwright MCP** (Model Context Protocol) server for **headless browser automation** from Claude *and* Codex

…with **persisted auth & settings**, **short commands**, and no local installs.

It assumes the repo contains:

* `docker/Dockerfile.ai-cli` (single image that installs both CLIs and Playwright MCP + Chromium)
* `docker-compose.yml` (services: `claude`, `codex`, `codex-login`; named volumes incl. browser cache)
* `scripts/claude.cmd`, `scripts/codex.cmd`, `scripts/codex-login.cmd`
* `scripts/claude-mcp-playwright.cmd`, `scripts/codex-mcp-playwright.cmd`

> The files are the source of truth; this README focuses on *usage* and avoids repeating file contents.

---

## What you get

* Run **Claude** and **Codex** CLIs entirely **inside Docker** on Windows.
* **Auth & settings persist** via named volumes (`claude_home`, `codex_home`).
* **Headless browser automation** via **Playwright MCP** (Chromium) from both CLIs.
* **Short commands** using tiny CMD wrappers.
* Run from **any directory** (wrappers target the repo’s compose file and mount your *current* folder into `/workspace`).

---

## Prerequisites

* **Docker Desktop for Windows** (WSL2 backend recommended)
* **PowerShell** and/or **Command Prompt (CMD)**
* Add `your-repo\scripts` to your **PATH** so you can run `claude`, `codex`, `codex-login`, `claude-mcp-playwright`, and `codex-mcp-playwright` from anywhere.

> PowerShell tip: if you pass shell metacharacters (`| > & <`), use the **stop-parsing** token `--%` after the command.

---

## First-time setup (details)

1. **Build the image (once)**

```powershell
docker compose build
```

2. **Sign in (one-time)**

### Claude

```powershell
claude
```

Follow the browser prompt. Credentials persist in the `claude_home` volume.

### Codex

Use the helper that sets up a temporary bridge for the browser callback:

```powershell
codex-login
```

After success, credentials persist in `codex_home`.

---

## Enable the Playwright MCP (one command per CLI)

The image already includes the Playwright MCP server and Chromium. Register it with each CLI:

### Claude → Playwright MCP

```powershell
claude-mcp-playwright
```

This registers the server with **sane Docker defaults**:

```
--browser chromium --headless --isolated --no-sandbox
```

* `chromium` + `--headless`: supported in containers
* `--isolated`: avoids “browser already in use” profile locks
* `--no-sandbox`: required when running as root in Docker

> If you prefer a persistent logged-in profile (no isolation), run:
>
> ```powershell
> claude-mcp-playwright persist
> ```
>
> (Uses a fixed user-data-dir; don’t run multiple sessions in parallel on the same profile.)

### Codex → Playwright MCP

```powershell
codex-mcp-playwright
```

Registers the same MCP server and flags for Codex.

> You can confirm registration with:
>
> ```powershell
> claude mcp list
> codex  mcp list
> ```

---

## Everyday use

### Claude

* **Interactive TUI**

  ```powershell
  claude
  ```
* **Headless / one-shot**

  ```powershell
  claude -p "run unit tests and summarize failures" --output-format json
  ```
* **Using Playwright MCP**
  In the Claude prompt, ask for a browse action, e.g.:

  > “Using the Playwright MCP server, open [https://example.com](https://example.com) and return the page title.”

### Codex

* **Interactive TUI**

  ```powershell
  codex
  ```
* **Headless / one-shot**

  ```powershell
  codex -p "refactor foo() and explain changes" --output-format json
  ```
* **Using Playwright MCP**

  > “Use the Playwright MCP to open [https://example.com](https://example.com) and return the page title.”

*(PowerShell only: if you include shell metacharacters, add `--%` after `codex`.)*

---

## Persistence (what’s stored where)

* The container **home** (`/root`) is persisted per CLI:

  * **Claude:** `claude_home` → `~/.claude/…`, `~/.claude.json`
  * **Codex:**  `codex_home`  → `~/.codex/auth.json`, `~/.codex/config.toml`
* **Playwright browser cache** persists in a named volume (faster cold starts), mounted at:

  * `/root/.cache/ms-playwright`

Result: **no repeated logins** and faster Playwright startup after first run.

---

## Updating, resetting, and backup

**Update CLIs / Playwright MCP in the image**

```powershell
docker compose build --no-cache
```

**Reset (sign out & wipe settings)**

```powershell
docker compose down
docker volume rm claude_home
docker volume rm codex_home
```

**Backup a persisted home (example for Codex)**

```powershell
docker run --rm -v codex_home:/home busybox tar -C / -czf - home > codex_home_backup.tgz
```

---

## Troubleshooting

* **Chrome path errors (e.g., `/opt/google/chrome/chrome` not found)**
  You accidentally targeted `chrome`. The scripts register **`--browser chromium`** which is supported in Docker; re-run the MCP registration script.

* **“Browser is already in use … use --isolated”**
  Use the default registration (**isolated**), or switch to a **persistent** profile with `claude-mcp-playwright persist` / `codex-mcp-playwright persist` and avoid parallel sessions.

* **Sandbox / root errors**
  The scripts include `--no-sandbox` for root-in-container. For stronger hardening, run the services as a **non-root** user and provide a seccomp profile (advanced).

* **Crashes / blank pages in headless Chromium**
  Add one of the following to the `claude`/`codex` service in `docker-compose.yml`:

  ```yaml
  ipc: host
  # or
  shm_size: "1g"
  ```

* **“no configuration file provided”**
  Use the provided wrappers (`claude`, `codex`, `codex-login`, `claude-mcp-playwright`, `codex-mcp-playwright`) which pass the correct compose/project paths.

* **PowerShell ate my flags**
  Prefer the **CMD** wrappers, or add `--%` after the command in PowerShell:

  ```powershell
  codex --% -p "echo a | echo b" --output-format json
  ```

---

## Notes & next steps

* This is the **minimal** pattern: single image, per-CLI volumes, browser cache volume, tiny wrappers.
* When you need more control:

  * Add **permission defaults** (Claude) via user or repo settings.
  * Introduce **egress controls** or firewall rules in the image.
  * Switch to **non-root** user for Playwright (remove `--no-sandbox`) if you need stricter isolation.

---

**Done.**
Build once, authenticate once, MCP-enable with a single script per CLI, then use `claude` and `codex` for fast, persistent runs—`codex-login` only for the one-time OAuth flow on Windows.
