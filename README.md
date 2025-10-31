# Claude & Codex CLIs via Docker on Windows — Minimal Runner (Compose)

This README explains **how to use** the repository’s Docker/Compose setup to run:

* **Claude Code (CLI)**
* **OpenAI Codex CLI** (incl. a special **OAuth login helper**)

…with **persisted auth & settings**, **short commands**, and without local installs.

---

## What you get

* Run **Claude** and **Codex** CLIs entirely **inside Docker** on Windows.
* **Auth & settings persist** via named volumes (`claude_home`, `codex_home`).
* **Short commands** using tiny CMD wrappers.
* Run from **any directory** (wrappers target the repo’s compose file and mount your *current* folder into `/workspace`).

---

## Prerequisites

* **Docker Desktop for Windows** (WSL2 backend recommended)
* **PowerShell** and/or **Command Prompt (CMD)**
* Add `your-repo\scripts` to your **PATH** so you can run `claude`, `codex`, and `codex-login` from anywhere.

> Tip (PowerShell): if you pass shell metacharacters (`| > & <`), use the **stop-parsing** token `--%` after the command.

---

## First-time setup

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

Starts a small in-container bridge so the browser callback works on Windows:

```powershell
codex-login
```

  After success, credentials persist in `codex_home`.

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

### Codex

* **Interactive TUI**

  ```powershell
  codex
  ```
* **Headless / one-shot**

  ```powershell
  codex -p "refactor foo() and explain changes" --output-format json
  ```

  *(PowerShell only: if you include shell metacharacters, add `--%` after `codex`.)*

---

## Persistence (what’s stored where)

* The container **home** (`/root`) is persisted per CLI:

  * **Claude:** `claude_home` → contains `~/.claude/…` and `~/.claude.json`
  * **Codex:**  `codex_home`  → contains `~/.codex/auth.json`, `~/.codex/config.toml`

Result: **no repeated logins** after the first authentication.

---

## Updating, resetting, and backup

**Update CLIs in the image**

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

* **Codex OAuth login fails with localhost callback**
  Use `codex-login` (it runs a small bridge inside the container), or use the **API key** method.

* **I accidentally see a `login:` prompt in the terminal**
  That’s the Linux `/bin/login`. Don’t pass the word `login` to the normal `codex` service. Use the dedicated `codex-login` command instead.

* **“no configuration file provided”**
  Ensure you’re using the provided wrappers (`claude`, `codex`, `codex-login`) which pass the correct compose/project paths.

* **PowerShell ate my flags**
  Use the **CMD** wrappers (recommended), or add `--%` after the command in PowerShell:

  ```powershell
  codex --% -p "echo a | echo b" --output-format json
  ```

---

## Notes & next steps

* This is the **minimal** pattern: single image, per-CLI volumes, tiny wrappers.
* When you need more control, you can:

  * Add **permission defaults** (Claude) via user or repo settings.
  * Introduce **egress controls** or firewall rules in the image.
  * Wire up **SSH** or credential helpers for Git (we keep it minimal here).

---

**Done.**
Build once, authenticate once, then use `claude` and `codex` for fast, persistent CLI runs—use `codex-login` only for the one-time OAuth flow on Windows.
