# AI CLI Runner — Claude, Codex & GitHub Copilot via Docker on Windows

Run **Claude**, **Codex**, and **GitHub Copilot** CLIs entirely inside Docker on Windows with:
- ✅ **Persistent authentication & settings** via named volumes
- ✅ **MCP (Model Context Protocol)** support with easy registration
- ✅ **Headless browser automation** via Playwright MCP
- ✅ **Short commands** from any directory
- ✅ **Custom Python packages** via requirements.txt
- ✅ **No local CLI installs required**

---

## 🚀 Quick Start

### Prerequisites

* **Docker Desktop for Windows** (WSL2 backend recommended)
* PowerShell and/or Command Prompt (CMD)

### 1) Get this repository

**Option A — Clone with Git (recommended)**

```powershell
cd C:\Workspace
git clone <REPO_URL> ai-cli
cd .\ai-cli
```

**Option B — Download ZIP**

1. Download and extract ZIP to a folder (e.g., `C:\Workspace\ai-cli`)
2. Open a terminal in that folder

### 2) Add scripts to PATH (optional but recommended)

```powershell
# Current session only:
$env:Path += ";C:\Workspace\ai-cli\scripts"

# Persist for your user:
setx Path "$($env:Path);C:\Workspace\ai-cli\scripts"
```

This allows you to run `claude`, `codex`, `copilot`, and other commands from **any** directory.

> **Tip:** Without this, you can always run commands as `.\scripts\<name>`.

### 3) Build the Docker image

```powershell
docker compose build
```

### 4) Sign in once per CLI

**Claude:**
```powershell
claude
```
Follow the browser prompt. Credentials persist in the `claude_home` volume.

**Codex:**
```powershell
codex-login
```
Uses an in-container bridge for OAuth callback on Windows. Credentials persist in `codex_home`.

**GitHub Copilot:**
```powershell
copilot
```
Enter `/login` in the CLI and follow the device code flow. Credentials persist in `copilot_home`.

> **Note:** GitHub Copilot requires a Pro, Pro+, Business, or Enterprise subscription.

### 5) Enable Playwright MCP (optional)

```powershell
reg-playwright    # Registers Playwright MCP for all CLIs at once
```

### 6) Start using it!

```powershell
claude
codex
copilot

# Try in the CLI prompt:
# "Using the Playwright MCP server, open https://example.com and return the page title."
```

---

## 📦 What's Included

**CLI Tools:**
- **Claude Code CLI** — Anthropic's Claude with native MCP support
- **OpenAI Codex CLI** — With Windows OAuth helper (`codex-login`)
- **GitHub Copilot CLI** — With JSON-based MCP configuration

**MCP Servers:**
- **Playwright MCP** — Headless Chromium for web automation
- **Universal MCP registration tool** (`reg-mcp`) for any MCP server

**Features:**
- Single Docker image for all CLIs
- Named volumes for persistent auth, settings, and browser cache
- Current directory auto-mounted to `/workspace` in container
- Extensible via `extensions/requirements.txt` or `.whl` packages

---

## 📖 Table of Contents

- [Everyday Usage](#everyday-usage)
- [MCP Server Management](#mcp-server-management)
  - [Using the Universal MCP Registration Tool](#using-the-universal-mcp-registration-tool)
  - [Quick Playwright Registration](#quick-playwright-registration)
  - [Registering Custom MCP Servers](#registering-custom-mcp-servers)
  - [Verifying MCP Registration](#verifying-mcp-registration)
  - [MCP Security Warning](#mcp-security-warning)
- [Extending with Python Packages](#extending-with-python-packages)
- [Persistence & Data](#persistence--data)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Repository Structure](#repository-structure)

---

## Everyday Usage

**Claude:**
```powershell
claude
claude -p "run unit tests and summarize failures" --output-format json
```

**Codex:**
```powershell
codex
codex -p "refactor foo() and explain changes" --output-format json
```
> **PowerShell tip:** If your command includes `| > & <`, add `--%` after `codex` to prevent parsing issues.

**GitHub Copilot:**
```powershell
copilot
copilot -p "analyze this code and suggest improvements"
```

**Using MCP servers:**

Ask any CLI to browse via Playwright:
> "Using the Playwright MCP server, open https://example.com and return the page title."

---

## MCP Server Management

### Using the Universal MCP Registration Tool

The `reg-mcp` tool simplifies registering any MCP server across all three CLIs (Claude, Codex, and GitHub Copilot) with optional environment variable support.

**Basic syntax:**
```powershell
reg-mcp --name <server-name> --command <cmd> [args...] [--env KEY=VALUE ...]
```

**How it works:**
- **Claude & Codex:** Registers via `<cli> mcp add <name> -- <command>`
  - With environment variables, wraps command in `bash -c "export VAR=val; <command>"`
- **GitHub Copilot:** Creates/updates `~/.copilot/mcp-config.json` with proper configuration

**Examples:**

1. **Register Playwright MCP (no environment variables):**
   ```powershell
   reg-mcp --name playwright --command python3 /opt/mcp/playwright-mcp.py
   ```

2. **Register GitHub MCP with token:**
   ```powershell
   # PowerShell (use single quotes):
   reg-mcp --name github --command python3 /opt/mcp/github-mcp.py --env 'GITHUB_TOKEN=ghp_abc123'
   
   # CMD (use double quotes):
   reg-mcp --name github --command python3 /opt/mcp/github-mcp.py --env "GITHUB_TOKEN=ghp_abc123"
   ```
   
   > **Important:** In PowerShell, **always use single quotes** around `KEY=VALUE` pairs to prevent parsing issues.

3. **Multiple environment variables:**
   ```powershell
   reg-mcp --name myserver --command python3 /opt/mcp/myserver.py --env 'API_KEY=secret123' --env 'DB_URL=postgresql://...'
   ```

4. **MCP server with command-line arguments:**
   ```powershell
   reg-mcp --name custom --command python3 /opt/mcp/server.py --port 8080 --debug
   ```

### Quick Playwright Registration

Use the dedicated helper to register Playwright MCP for all CLIs at once:

```powershell
reg-playwright
```

This is equivalent to running `reg-mcp --name playwright --command python3 /opt/mcp/playwright-mcp.py`.

### Registering Custom MCP Servers

To add your own MCP server:

1. **Copy your MCP server script to the container:**
   
   Add it to the `mcp/` directory in this repository, then rebuild:
   ```powershell
   docker compose build
   ```

2. **Register it using `reg-mcp`:**
   ```powershell
   reg-mcp --name myserver --command python3 /opt/mcp/myserver.py
   ```

3. **With environment variables (if needed):**
   ```powershell
   reg-mcp --name myserver --command python3 /opt/mcp/myserver.py --env 'API_KEY=your_key'
   ```

   Your MCP Python script should read environment variables like:
   ```python
   import os
   api_key = os.getenv("API_KEY")
   ```

### Verifying MCP Registration

**Claude:**
```powershell
claude mcp list
```

**Codex:**
```powershell
codex mcp list
```

**GitHub Copilot:**
```powershell
docker compose run --rm --entrypoint bash ai-cli -c "cat ~/.copilot/mcp-config.json"
```

Or use the helper:
```powershell
copilot bash -c "cat ~/.copilot/mcp-config.json"
```

### MCP Security Warning

⚠️ **WARNING:** Environment variables are stored in **PLAINTEXT** in Docker volumes:
- Claude: `~/.claude/...` (in `ai-cli_home` volume)
- Codex: `~/.codex/config.toml` (in `ai-cli_home` volume)
- GitHub Copilot: `~/.copilot/mcp-config.json` (in `ai-cli_home` volume)

**Only use this for:**
- Non-sensitive configuration values
- Development/testing environments
- When you accept the security risk

**For production:** Consider alternative approaches like runtime environment variable injection.

---

## Extending with Python Packages

Add custom Python packages to the container by editing `extensions/requirements.txt` or adding wheel files to `extensions/packages/`.

### Adding PyPI packages

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

### Adding local wheel files

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

## Persistence & Data

**What's stored where:**
- **All CLIs:** `ai-cli_home` volume → `/root` (contains `~/.claude`, `~/.codex`, `~/.copilot`)
  - Claude: `~/.claude/...`, `~/.claude.json`
  - Codex: `~/.codex/auth.json`, `~/.codex/config.toml`
  - GitHub Copilot: `~/.copilot/config.json`, `~/.copilot/mcp-config.json`
- **Playwright cache:** `playwright_cache` volume → `~/.cache/ms-playwright` (for faster cold starts)

**Workspace mounting:**
- Your current directory is automatically mounted to `/workspace` in the container
- All CLIs start in `/workspace` by default
- Files created/modified in the container are reflected on your host

---

## Maintenance

### Update CLIs / Playwright MCP

```powershell
docker compose build --no-cache
```

### Reset authentication (wipe settings)

```powershell
docker compose down
docker volume rm ai-cli_home
```

### Backup volumes

**All CLI authentication & settings:**
```powershell
docker run --rm -v ai-cli_home:/root busybox tar -C / -czf - root > ai-cli_home_backup.tgz
```

**Playwright browser cache:**
```powershell
docker run --rm -v playwright_cache:/cache busybox tar -C / -czf - cache > playwright_cache_backup.tgz
```

### Restore volumes

**Restore authentication & settings:**
```powershell
docker run --rm -v ai-cli_home:/root busybox tar -C / -xzf - < ai-cli_home_backup.tgz
```

**Restore Playwright cache:**
```powershell
docker run --rm -v playwright_cache:/cache busybox tar -C / -xzf - < playwright_cache_backup.tgz
```

---

## Troubleshooting

### MCP Server Issues

**Problem:** MCP server not working or not found

**Solutions:**
- Verify the Python MCP server files are correctly copied to `/opt/mcp/` in the container
- Check the server script exists: `docker compose run --rm --entrypoint bash ai-cli -c "ls -la /opt/mcp/"`
- Re-register the MCP server using `reg-mcp` or the specific registration script
- Check MCP server logs in the CLI output

### PowerShell Command Parsing

**Problem:** PowerShell "ate my flags" or special characters

**Solutions:**
- Use CMD wrappers instead of PowerShell
- Add `--%` after the command name in PowerShell: `codex --% -p "prompt"`
- For `reg-mcp`, always use single quotes around `--env` values: `--env 'KEY=value'`

### Environment Variables Not Working

**Problem:** MCP server doesn't see environment variables

**Solutions:**
- Verify your MCP Python script reads from `os.getenv("VAR_NAME")`
- Check the stored command includes the export clause:
  - Claude: `claude mcp list`
  - Codex: `codex mcp list`
- Remember: variables are set at MCP server start, not at CLI invocation
- Re-register with correct syntax if needed

### Docker Compose Issues

**Problem:** "no configuration file provided"

**Solutions:**
- Use the wrapper scripts (`claude`, `codex`, `copilot`) so Compose paths are correct
- Ensure you're in the repository directory or scripts are on PATH
- Check Docker Desktop is running

### GitHub Copilot MCP Not Working

**Problem:** GitHub Copilot doesn't recognize MCP server

**Solutions:**
- GitHub Copilot uses JSON configuration, not CLI registration
- Verify config exists: `copilot bash -c "cat ~/.copilot/mcp-config.json"`
- Re-run `copilot-mcp-playwright` or `reg-playwright`
- Check that the JSON is valid and includes your server

### Authentication Issues

**Problem:** CLI asks for login repeatedly

**Solutions:**
- Verify named volumes exist: `docker volume ls | findstr ai-cli`
- Check volume permissions
- For Codex on Windows, use `codex-login` helper instead of `codex login`
- Restart Docker Desktop if volumes aren't persisting

---

## Repository Structure

```
ai-cli/
├── docker-compose.yml          # Service definitions for all CLIs
├── README.md                   # This file
├── Docker/
│   └── Dockerfile.ai-cli       # Single image for all CLIs + MCP
├── extensions/
│   ├── requirements.txt        # PyPI packages to install
│   └── packages/               # Local wheel files to install
│       └── joplink-0.1.0-py3-none-any.whl
├── mcp/
│   ├── playwright-mcp.json     # Playwright MCP metadata
│   └── playwright-mcp.py       # Playwright MCP server implementation
└── scripts/
    ├── ai-cli.cmd              # Generic AI CLI wrapper
    ├── claude.cmd              # Claude CLI wrapper
    ├── codex.cmd               # Codex CLI wrapper
    ├── copilot.cmd             # GitHub Copilot CLI wrapper
    ├── codex-login.cmd         # Codex OAuth helper for Windows
    ├── reg-mcp.cmd             # Universal MCP registration wrapper
    ├── reg-mcp.py              # Universal MCP registration (Python)
    └── reg-playwright.cmd      # Quick Playwright registration wrapper
```

**Key files:**
- **Dockerfile.ai-cli:** Installs all CLIs, Playwright MCP, Chromium, and extensions
- **docker-compose.yml:** Defines services with named volumes for persistence
- **reg-mcp.py:** Universal Python script for registering any MCP server
- **Wrapper scripts (.cmd):** Invoke Docker Compose services from any directory

---

## Advanced Usage

### Running arbitrary commands in the container

```powershell
docker compose run --rm --entrypoint bash ai-cli
```

### Accessing a specific CLI's config directory

```powershell
# Claude
docker compose run --rm --entrypoint bash ai-cli -c "cd ~/.claude && ls -la"

# Codex
docker compose run --rm --entrypoint bash ai-cli -c "cd ~/.codex && ls -la"

# GitHub Copilot
docker compose run --rm --entrypoint bash ai-cli -c "cd ~/.copilot && ls -la"
```

### Using Python packages in MCP servers

After adding packages to `extensions/requirements.txt` and rebuilding, they're available in MCP servers:

```python
# In your MCP server script
import requests
import pandas as pd
import joplink  # From local wheel file
```

---

**Done!**

Clone or download, build once, authenticate once, enable MCP with a single command—then use `claude`, `codex`, and `copilot` for fast, persistent AI-assisted development on Windows.
