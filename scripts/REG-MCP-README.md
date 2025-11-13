# reg-mcp - Register MCP Server

## Overview
`reg-mcp` is a generalized MCP server registration tool (Python script with CMD wrapper) that registers any MCP server across all CLI tools (Claude, Codex, and GitHub Copilot) with optional environment variable support.

## Usage

```bash
python reg-mcp.py --name <server-name> --command <cmd> [args...] [--env KEY=VALUE ...]

# Or via CMD wrapper:
reg-mcp.cmd --name <server-name> --command <cmd> [args...] [--env KEY=VALUE ...]
```

### Basic Example (No Environment Variables)

```bash
python reg-mcp.py --name playwright --command python3 /opt/mcp/playwright-mcp.py

# Or:
reg-mcp.cmd --name playwright --command python3 /opt/mcp/playwright-mcp.py
```

### With Environment Variables

**From PowerShell (use single quotes):**
```powershell
python reg-mcp.py --name github --command python3 /opt/mcp/github-mcp.py --env 'GITHUB_TOKEN=ghp_abc123'

# Multiple env vars:
python reg-mcp.py --name myserver --command python3 /opt/mcp/server.py --env 'API_KEY=secret123' --env 'DB_PASS=pwd456'
```

**From CMD:**
```cmd
python reg-mcp.py --name github --command python3 /opt/mcp/github-mcp.py --env "GITHUB_TOKEN=ghp_abc123"
```

## How It Works

1. **Claude & Codex**: Registers via `<cli> mcp add <name> -- <command>`
   - If environment variables are provided, wraps the command in `bash -c "export VAR=val; <command>"`
   - Secrets are stored in plaintext in the CLI config files inside the Docker volume

2. **GitHub Copilot**: Creates/updates `~/.copilot/mcp-config.json`
   - Generates dynamic bash script using PowerShell helper
   - Stores configuration in JSON format

## Security Warning

⚠️ **WARNING**: Environment variables are stored in PLAINTEXT in Docker volumes (`ai-cli_home:/root`).

This includes:
- Claude: `~/.claude/...` 
- Codex: `~/.codex/config.toml`
- Copilot: `~/.copilot/mcp-config.json`

Only use this for:
- Non-sensitive configuration
- Development/testing environments
- When you accept the security risk

For production, consider using Option A (runtime environment variable injection via modified `ai-cli.cmd`).

## Examples

### Playwright MCP (No Secrets)
```bash
python reg-mcp.py --name playwright --command python3 /opt/mcp/playwright-mcp.py
```

Equivalent to running `reg-playwright.cmd`.

### GitHub MCP (With Token)
```powershell
python reg-mcp.py --name github --command python3 /opt/mcp/github-mcp.py --env 'GITHUB_TOKEN=ghp_yourtoken123'
```

### Custom MCP (Multiple Environment Variables)
```powershell
python reg-mcp.py --name myserver --command python3 /opt/mcp/myserver.py --env 'API_KEY=key123' --env 'DB_URL=postgresql://...'
```

### Using Arguments in Command
```bash
python reg-mcp.py --name custom --command python3 /opt/mcp/server.py --port 8080 --debug
```

## Verifying Registration

**Claude:**
```cmd
claude mcp list
```

**Codex:**
```cmd
codex mcp list
```

**GitHub Copilot:**
```cmd
docker compose run --rm --entrypoint bash ai-cli -c "cat ~/.copilot/mcp-config.json"
```

## Troubleshooting

### PowerShell Parsing Issues
When using `--env` with environment variables from PowerShell, **always use single quotes** around the KEY=VALUE pairs:

```powershell
# Correct:
python reg-mcp.py --name test --command python3 /opt/mcp/test.py --env 'API_KEY=secret123'

# Wrong (PowerShell may strip the = sign):
python reg-mcp.py --name test --command python3 /opt/mcp/test.py --env API_KEY=secret123
```

### Registration Fails
- Ensure the MCP server script exists in `/opt/mcp/` inside the container
- Check Docker is running
- Verify the command syntax is correct

### Environment Variables Not Working
- Verify your MCP Python script reads from `os.getenv("VAR_NAME")`
- Check the stored command includes the export clause
- Remember: vars are set at MCP server start, not at CLI invocation

## Implementation Details

- `reg-mcp.py`: Main Python script (cross-platform, handles all logic)
- `reg-mcp.cmd`: Simple CMD wrapper that calls the Python script
- No longer requires `generate-mcp-script.ps1` (Python generates configs directly)

### Advantages of Python Implementation

1. **Clean argument parsing**: Uses `argparse` for robust command-line handling
2. **No escaping issues**: Properly handles `=` signs, quotes, and special characters
3. **Cross-platform**: Works on Windows, Linux, macOS
4. **Maintainable**: Clear, readable code vs. complex batch scripting
5. **Better error handling**: Python's exception handling vs. batch ERRORLEVEL

All files should be in the same directory (`scripts/`).
