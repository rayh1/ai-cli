# Claude & Codex CLIs via Docker on Windows — Minimal Runner (Compose)

## 🚀 Quickstart

**Prerequisites**

* **Docker Desktop for Windows** (WSL2 backend recommended)
* PowerShell and/or Command Prompt (CMD)

### 0) Get this repository

**Option A — Clone with Git (recommended)**

```powershell
# Choose a folder and clone the repo
cd C:\Workspace
git clone <REPO_URL> ai-cli-runner
cd .\ai-cli-runner
```

**Option B — Download ZIP**

1. Open the repository page in your browser.
2. Click **Code ▸ Download ZIP**.
3. Extract the ZIP to a folder, e.g. `C:\Workspace\ai-cli-runner`.
4. Open a terminal in that folder.

> If you don’t want to put `scripts` on PATH (next step), you can always run commands as `.\scripts\<name>`.

### 0.1) Put `scripts\` on PATH (optional but recommended)

```powershell
# Current session only:
$env:Path += ";C:\Workspace\ai-cli-runner\scripts"

# Persist for your user (new terminals will pick it up):
setx Path "$($env:Path);C:\Workspace\ai-cli-runner\scripts"
```

After this, you can run `claude`, `codex`, `codex-login`, `claude-mcp-playwright`, and `codex-mcp-playwright` from **any** directory.

> PowerShell tip: if your command line includes `| > & <`, add `--%` after `claude` or `codex` to stop PS parsing.

### 1) Build the image (one-time)

```powershell
docker compose build
```

### 2) Sign in once per CLI

```powershell
claude           # follows browser flow; creds persist in claude_home
codex-login      # helper for Codex OAuth callback on Windows; creds persist in codex_home
```

### 3) Enable Playwright MCP (headless Chromium) for both CLIs

```powershell
claude-mcp-playwright         # registers: --browser chromium --headless --isolated --no-sandbox
codex-mcp-playwright          # same for Codex
```

### 4) Use it

```powershell
# Start either CLI
claude
codex

# In the CLI prompt, try:
# “Using the Playwright MCP server, open https://example.com and return the page title.”
```

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

## First-time setup (details)

1. **Build the image**

```powershell
docker compose build
```

2. **Sign in (one-time)**

**Claude**

```powershell
claude
```

Follow the browser prompt (persists in `claude_home`).

**Codex**

```powershell
codex-login
```

Uses an in-container bridge so the OAuth callback succeeds on Windows (persists in `codex_home`).

---

## Enable the Playwright MCP (one command per CLI)

**Claude → Playwright MCP**

```powershell
claude-mcp-playwright
```

Registers with Docker-safe defaults:

```
--browser chromium --headless --isolated --no-sandbox
```

> Persistent profile (stay logged in):
>
> ```powershell
> claude-mcp-playwright persist
> ```

**Codex → Playwright MCP**

```powershell
codex-mcp-playwright
```

Verify:

```powershell
claude mcp list
codex  mcp list
```

---

## Everyday use

**Claude**

```powershell
claude
claude -p "run unit tests and summarize failures" --output-format json
```

Ask it to browse via MCP:

> “Using the Playwright MCP server, open [https://example.com](https://example.com) and return the page title.”

**Codex**

```powershell
codex
codex -p "refactor foo() and explain changes" --output-format json
```

Ask it to browse via MCP:

> “Use the Playwright MCP to open [https://example.com](https://example.com) and return the page title.”

*(PowerShell only: if you include shell metacharacters, add `--%` after `codex`.)*

---

## Persistence (what’s stored where)

* **Claude:** `claude_home` → `~/.claude/…`, `~/.claude.json`
* **Codex:**  `codex_home`  → `~/.codex/auth.json`, `~/.codex/config.toml`
* **Playwright cache:** `~/.cache/ms-playwright` (mounted as a named volume for faster cold starts)

---

## Updating, resetting, and backup

**Update CLIs / Playwright MCP**

```powershell
docker compose build --no-cache
```

**Reset (wipe settings)**

```powershell
docker compose down
docker volume rm claude_home
docker volume rm codex_home
```

**Backup example (Codex)**

```powershell
docker run --rm -v codex_home:/home busybox tar -C / -czf - home > codex_home_backup.tgz
```

---

## Troubleshooting

* **Chrome path errors** → use the provided scripts (they target **chromium**).
* **“Browser is already in use …”** → default scripts use `--isolated`; or switch to a persistent profile and avoid parallel sessions.
* **Sandbox issues** → scripts include `--no-sandbox` for root-in-container. For stricter isolation, run services as **non-root** with a seccomp profile (advanced).
* **Crashes/blank pages** → add `ipc: host` **or** `shm_size: "1g"` to the `claude`/`codex` service.
* **“no configuration file provided”** → use the wrappers (`claude`, `codex`, `codex-login`, `claude-mcp-playwright`, `codex-mcp-playwright`) so Compose paths are correct.
* **PowerShell ate my flags** → prefer CMD wrappers, or add `--%` after the command.

---

**Done.**
Clone or download, build once, authenticate once, MCP-enable with a single script per CLI—then use `claude` and `codex` for fast, persistent runs on Windows.
