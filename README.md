# Claude Code (CLI) via Docker on Windows — Minimal Runner (Compose)

This README documents **how to use** the provided Docker/Compose setup to run **Claude Code (CLI)** on a Windows workstation with **persisted authentication & settings**, and **short commands**.
It assumes the repo already contains:

* `docker/Dockerfile.claude`
* `docker-compose.yml`
* `scripts/claude.ps1` and `scripts/claude.cmd`

> The files themselves are the source of truth. This README avoids repeating their contents and focuses on usage, tips, and troubleshooting.

---

## What this gives you

* Run `Claude Code (CLI)` **inside Docker** on Windows.
* **Config & auth persist** between runs (Docker **named volume**).
* **Short commands** via the wrapper scripts.
* Works from **any directory** (wrappers target the repo’s compose file explicitly).

---

## Prerequisites

* **Docker Desktop for Windows** (WSL2 backend recommended)
* **PowerShell** and/or **CMD**

If PowerShell blocks script execution, either run once with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\claude.ps1
```

or set your policy to allow local scripts (e.g., `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`).

---

## First-time setup

1. **Build the image**

```powershell
docker compose build
```

2. **Sign in once**

```powershell
# PowerShell
.\scripts\claude.ps1
# or CMD
scripts\claude.cmd
```

Follow the login prompt in your browser.
Your **credentials and settings** are stored in the Docker volume and reused next time (no re-login).

---

## Everyday use

* **Interactive TUI**

  ```powershell
  .\scripts\claude.ps1
  ```
* **Headless one-shot task (machine-readable)**

  ```powershell
  .\scripts\claude.ps1 -p "run unit tests and summarize failures" --output-format json
  ```
* **Run from anywhere** (full path works; wrappers locate the compose file automatically)

  ```powershell
  C:\path\to\repo\scripts\claude.ps1 -p "hello"
  ```

> Optional: add `your-repo\scripts` to your **PATH** so you can type `claude.ps1` / `claude.cmd` anywhere.

---

## Persistence (what’s stored where)

* The container’s **home directory** (`/root`) is persisted via a named volume (defined in `docker-compose.yml`).
  That includes:

  * `~/.claude/…` (settings, credentials)
  * `~/.claude.json` (user-level config/sentinel)

Result: **no repeated authentication prompts** after the first login.

---

## Updating, resetting, and backup

* **Update to the latest CLI**

  ```powershell
  docker compose build --no-cache
  ```

* **Reset (sign out & wipe settings)**

  ```powershell
  docker compose down
  docker volume rm claude_home
  ```

* **Backup the persisted home (optional)**

  ```powershell
  docker run --rm -v claude_home:/home busybox tar -C / -czf - home > claude_home_backup.tgz
  ```

---

## Optional: API key (no browser sign-in)

If you prefer using a **Claude Console API key** instead of OAuth:

1. Create a `.env` (not committed) in the repo root:

   ```
   ANTHROPIC_API_KEY=your_api_key_here
   ```
2. Add the environment variable to the service (see the comment in `docker-compose.yml`) and rebuild.
   Then run the wrapper as usual. The CLI will use the API key automatically.

---

## Troubleshooting

* **“no configuration file provided: not found”**
  You’re running a wrapper from outside the repo. The provided wrappers already pass the repo’s compose file, so this should be resolved. Ensure you’re using the **updated** `scripts/claude.ps1` / `.cmd`.

* **Asks to authenticate every run**
  Confirm the compose volume maps the container **home** directory (not just `~/.claude`). After the first successful login, future runs should start without prompts.

  Quick check:

  ```powershell
  docker compose run --rm claude sh -lc 'ls -la ~ | grep "\.claude\.json"; ls -la ~/.claude | grep credentials'
  ```

  You should see both a `~/.claude.json` and a `~/.claude/.credentials.json`.

* **Git operations from inside the container**
  Simplest on Windows is **HTTPS** remotes with a **PAT**. SSH agent forwarding is possible but intentionally not included here (to keep things minimal).

---

## Notes & next steps

* This is the **minimal** pattern: one service, one named volume, two tiny wrappers.
* When you need more control later, you can:

  * Add **permission defaults** in `~/.claude/settings.json` or a repo-level `.claude/settings.json`.
  * Introduce **egress controls** or a firewall layer in the image.
  * Wire up **SSH agent** or credential helpers for Git.

---

**That’s it.**
Build once, sign in once, and use `.\scripts\claude.ps1` (or `scripts\claude.cmd`) for fast, persistent Claude runs inside Docker.
