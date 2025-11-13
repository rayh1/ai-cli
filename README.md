# Claude, Codex & Github Copilot CLIs via Docker on Windows — Minimal Runner (Compose)

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

After this, you can run `claude`, `codex`, `copilot`, `codex-login`, `claude-mcp-playwright`, `codex-mcp-playwright`, and `copilot-mcp-playwright` from **any** directory.

> PowerShell tip: if your command line includes `| > & <`, add `--%` after `claude` or `codex` to stop PS parsing.

### 1) Build the image (one-time)

```powershell
docker compose build
```

### 2) Sign in once per CLI

```powershell
claude           # follows browser flow; creds persist in claude_home
codex-login      # helper for Codex OAuth callback on Windows; creds persist in codex_home
copilot          # enter /login command and follow device code flow; creds persist in copilot_home
```

### 3) Enable Playwright MCP (headless Chromium) for all CLIs

```powershell
claude-mcp-playwright         # registers Python-based Playwright MCP
codex-mcp-playwright          # same for Codex
copilot-mcp-playwright        # same for Github Copilot
```

### 4) Use it

```powershell
# Start any CLI
claude
codex
copilot

# In the CLI prompt, try:
# "Using the Playwright MCP server, open https://example.com and return the page title."
```

---

This README explains **how to use** the repository's Docker/Compose setup to run:

* **Claude Code (CLI)**
* **OpenAI Codex CLI** (incl. a special **OAuth login helper**)
* **Github Copilot CLI**
* **Playwright MCP** (Model Context Protocol) server for **headless browser automation** from all CLIs

…with **persisted auth & settings**, **short commands**, and no local installs.

It assumes the repo contains:

* `Docker/Dockerfile.ai-cli` (single image that installs all CLIs and Playwright MCP + Chromium)
* `docker-compose.yml` (services: `claude`, `codex`, `copilot`, `codex-login`; named volumes incl. browser cache)
* `scripts/claude.cmd`, `scripts/codex.cmd`, `scripts/copilot.cmd`, `scripts/codex-login.cmd`
* `scripts/claude-mcp-playwright.cmd`, `scripts/codex-mcp-playwright.cmd`, `scripts/copilot-mcp-playwright.cmd` + `.sh`
* `mcp/` directory with Python-based Playwright MCP server files

> The files are the source of truth; this README focuses on *usage* and avoids repeating file contents.

---

## What you get

* Run **Claude**, **Codex**, and **Github Copilot** CLIs entirely **inside Docker** on Windows.
* **Auth & settings persist** via named volumes (`claude_home`, `codex_home`, `copilot_home`).
* **Headless browser automation** via **Playwright MCP** (Chromium) from all CLIs.
* **Short commands** using tiny CMD wrappers.
* Run from **any directory** (wrappers target the repo's compose file and mount your *current* folder into `/workspace`).

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

**Github Copilot**

```powershell
copilot
```

Enter `/login` command in the CLI and follow the device code flow in your browser (persists in `copilot_home`).

> **Note:** Requires a GitHub Copilot Pro, Pro+, Business, or Enterprise subscription.

---

## Extending with Python Packages

You can add custom Python packages to the container by editing `extensions/requirements.txt` or adding wheel files to `extensions/packages/`.

**Adding PyPI packages:**

1. Edit `extensions/requirements.txt`:
   ```
   requests==2.31.0
   pandas>=2.0.0
   beautifulsoup4
   ```

2. Rebuild the image:
   ```powershell
   docker compose build
   ```

**Adding local wheel files:**

1. Place your `.whl` file in `extensions/packages/`:
   ```
   extensions/packages/joplink-0.1.0-py3-none-any.whl
   ```

2. Rebuild the image:
   ```powershell
   docker compose build
   ```

> **Note:** Packages are installed into the system Python environment and available to all CLIs and MCP servers. Changes require rebuilding the Docker image.

---

## Enable the Playwright MCP (one command per CLI)

**Claude → Playwright MCP**

```powershell
claude-mcp-playwright
```

Registers the Python-based Playwright MCP server from `/opt/mcp/playwright-mcp.py`.

**Codex → Playwright MCP**

```powershell
codex-mcp-playwright
```

**Github Copilot → Playwright MCP**

```powershell
copilot-mcp-playwright
```

> **Note:** Github Copilot CLI uses a JSON configuration file (`~/.copilot/mcp-config.json`) instead of command-line registration. The script automatically creates this configuration for you.

Verify:

```powershell
claude mcp list
codex  mcp list
```

For Github Copilot, check the config file in the container:

```powershell
copilot bash -c "cat ~/.copilot/mcp-config.json"
```

---

## Everyday use

**Claude**

```powershell
claude
claude -p "run unit tests and summarize failures" --output-format json
```

Ask it to browse via MCP:

> "Using the Playwright MCP server, open [https://example.com](https://example.com) and return the page title."

**Codex**

```powershell
codex
codex -p "refactor foo() and explain changes" --output-format json
```

Ask it to browse via MCP:

> "Use the Playwright MCP to open [https://example.com](https://example.com) and return the page title."

*(PowerShell only: if you include shell metacharacters, add `--%` after `codex`.)*

**Github Copilot**

```powershell
copilot
copilot -p "analyze this code and suggest improvements"
```

Ask it to browse via MCP:

> "Use the Playwright MCP to open [https://example.com](https://example.com) and return the page title."

---

## Persistence (what's stored where)

* **Claude:** `claude_home` → `~/.claude/…`, `~/.claude.json`
* **Codex:**  `codex_home`  → `~/.codex/auth.json`, `~/.codex/config.toml`
* **Github Copilot:** `copilot_home` → `~/.copilot/config.json`, `~/.copilot/mcp-config.json`
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
docker volume rm copilot_home
```

**Backup example (Codex)**

```powershell
docker run --rm -v codex_home:/home busybox tar -C / -czf - home > codex_home_backup.tgz
```

**Backup example (Github Copilot)**

```powershell
docker run --rm -v copilot_home:/home busybox tar -C / -czf - home > copilot_home_backup.tgz
```

---

## Troubleshooting

* **MCP server issues** → verify the Python MCP server files are correctly copied to `/opt/mcp/` in the container.
* **"no configuration file provided"** → use the wrappers (`claude`, `codex`, `copilot`, `codex-login`, `claude-mcp-playwright`, `codex-mcp-playwright`, `copilot-mcp-playwright`) so Compose paths are correct.
* **PowerShell ate my flags** → prefer CMD wrappers, or add `--%` after the command.
* **Github Copilot MCP not working** → verify the config file exists with `copilot bash -c "cat ~/.copilot/mcp-config.json"`. Re-run `copilot-mcp-playwright` if needed.

---

**Done.**
Clone or download, build once, authenticate once, MCP-enable with a single script per CLI—then use `claude`, `codex`, and `copilot` for fast, persistent runs on Windows.
