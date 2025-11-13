#!/usr/bin/env python3
"""
Register MCP Server for all CLIs (Claude, Codex, Github Copilot)

Usage:
    python reg-mcp.py --name <server-name> --command <cmd> [args...] [--env KEY=VALUE ...]

Examples:
    python reg-mcp.py --name playwright --command python3 /opt/mcp/playwright-mcp.py
    python reg-mcp.py --name github --command python3 /opt/mcp/github-mcp.py --env GITHUB_TOKEN=ghp_abc123
    python reg-mcp.py --name myserver --command python3 /opt/mcp/server.py --env API_KEY=secret123 DB_URL=postgresql://...
"""

import argparse
import json
import os
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Register MCP server for all CLIs (Claude, Codex, Github Copilot)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python reg-mcp.py --name playwright --command python3 /opt/mcp/playwright-mcp.py
  python reg-mcp.py --name github --command python3 /opt/mcp/github-mcp.py --env GITHUB_TOKEN=ghp_abc123
  python reg-mcp.py --name custom --command python3 /opt/mcp/custom.py --env API_KEY=secret DB_PASS=pwd123

Security Warning:
  Environment variables are stored in PLAINTEXT in Docker volumes (ai-cli_home:/root).
  Only use for non-sensitive data or accept the security risk.
        """,
    )
    parser.add_argument("--name", required=True, help="MCP server name")
    parser.add_argument(
        "--command",
        required=True,
        nargs="+",
        help="Command and arguments to run the MCP server",
    )
    parser.add_argument(
        "--env",
        action="append",
        help="Environment variable in KEY=VALUE format (can be specified multiple times)",
    )
    return parser.parse_args()


def get_script_dir():
    """Get the directory containing this script."""
    return Path(__file__).parent.absolute()


def get_repo_root():
    """Get the repository root directory."""
    return get_script_dir().parent


def build_command_with_env(command_parts, env_vars):
    """
    Build the final command, wrapping with bash if env vars are present.
    
    Args:
        command_parts: List of command parts (e.g., ['python3', '/opt/mcp/server.py'])
        env_vars: List of KEY=VALUE strings or None
    
    Returns:
        Tuple of (command_string, is_wrapped_in_bash)
    """
    base_command = " ".join(command_parts)
    
    if not env_vars:
        return base_command, False
    
    # Build export statements
    export_statements = "; ".join(f"export {var}" for var in env_vars)
    wrapped_command = f"bash -c {shlex.quote(f'{export_statements}; {base_command}')}"
    
    return wrapped_command, True


def register_claude(name, command_str, scripts_dir):
    """Register MCP server for Claude."""
    print("[1/3] Registering for Claude...")
    
    claude_cmd = scripts_dir / "claude.cmd"
    if claude_cmd.exists():
        claude_exe = str(claude_cmd)
    else:
        claude_exe = "claude"
    
    # Remove existing registration (ignore errors)
    subprocess.run(
        [claude_exe, "mcp", "remove", name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    
    # Add new registration - use shlex.split to properly parse quoted command
    cmd = [claude_exe, "mcp", "add", name, "--"] + shlex.split(command_str)
    result = subprocess.run(cmd)
    
    if result.returncode != 0:
        print("[ERROR] Claude: MCP registration failed.", file=sys.stderr)
        return False
    else:
        print(f"[OK] Claude: MCP '{name}' registered")
        return True


def register_codex(name, command_str, scripts_dir):
    """Register MCP server for Codex."""
    print("[2/3] Registering for Codex...")
    
    codex_cmd = scripts_dir / "codex.cmd"
    if codex_cmd.exists():
        codex_exe = str(codex_cmd)
    else:
        codex_exe = "codex"
    
    # Remove existing registration (ignore errors)
    subprocess.run(
        [codex_exe, "mcp", "remove", name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    
    # Add new registration - use shlex.split to properly parse quoted command
    cmd = [codex_exe, "mcp", "add", name, "--"] + shlex.split(command_str)
    result = subprocess.run(cmd)
    
    if result.returncode != 0:
        print("[ERROR] Codex: MCP registration failed.", file=sys.stderr)
        return False
    else:
        print(f"[OK] Codex: MCP '{name}' registered")
        return True


def register_copilot(name, command_parts, env_vars, repo_root):
    """Register MCP server for Github Copilot."""
    print("[3/3] Registering for Github Copilot...")
    
    # Parse command into executable and args
    copilot_command = command_parts[0]
    copilot_args = command_parts[1:] if len(command_parts) > 1 else []
    
    # If env vars present, wrap in bash
    if env_vars:
        export_statements = "; ".join(f"export {var}" for var in env_vars)
        copilot_command = "bash"
        copilot_args = ["-c", f"{export_statements}; {' '.join(command_parts)}"]
    
    # Generate bash script for Copilot configuration
    bash_script_content = f"""#!/bin/bash
set -e

CONFIG_DIR="$HOME/.copilot"
CONFIG_FILE="$CONFIG_DIR/mcp-config.json"

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" << 'EOFMCP'
{{
  "mcpServers": {{
    "{name}": {{
      "type": "local",
      "command": "{copilot_command}",
      "args": {json.dumps(copilot_args)},
      "tools": ["*"]
    }}
  }}
}}
EOFMCP

echo "[OK] MCP '{name}' configured in $CONFIG_FILE"
"""
    
    # Write to temporary file
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".sh", delete=False, newline="\n"
    ) as f:
        f.write(bash_script_content)
        temp_script = f.name
    
    try:
        # Execute in container
        compose_file = repo_root / "docker-compose.yml"
        cmd = [
            "docker",
            "compose",
            "--project-directory",
            str(repo_root),
            "-f",
            str(compose_file),
            "run",
            "--rm",
            "-v",
            f"{temp_script}:/tmp/setup-mcp.sh",
            "--entrypoint",
            "bash",
            "ai-cli",
            "/tmp/setup-mcp.sh",
        ]
        
        result = subprocess.run(cmd)
        
        if result.returncode != 0:
            print("[ERROR] Github Copilot: MCP configuration failed.", file=sys.stderr)
            return False
        else:
            print(f"[OK] Github Copilot: MCP '{name}' configured")
            return True
    finally:
        # Clean up temp file
        try:
            os.unlink(temp_script)
        except Exception:
            pass


def main():
    """Main entry point."""
    args = parse_args()
    
    name = args.name
    command_parts = args.command
    env_vars = args.env or []
    
    scripts_dir = get_script_dir()
    repo_root = get_repo_root()
    
    # Build command string
    command_str, has_env = build_command_with_env(command_parts, env_vars)
    
    print("=" * 40)
    print(f"Registering MCP Server: {name}")
    print("=" * 40)
    
    if env_vars:
        print()
        print("[WARNING] Environment variables will be stored in PLAINTEXT")
        print("          in Docker volume 'ai-cli_home:/root'")
        print()
    
    # Register for each CLI
    claude_ok = register_claude(name, command_str, scripts_dir)
    print()
    
    codex_ok = register_codex(name, command_str, scripts_dir)
    print()
    
    copilot_ok = register_copilot(name, command_parts, env_vars, repo_root)
    print()
    
    print("=" * 40)
    if claude_ok and codex_ok and copilot_ok:
        print("Registration complete for all CLIs")
        print("=" * 40)
        return 0
    else:
        print("Registration completed with errors")
        print("=" * 40)
        return 1


if __name__ == "__main__":
    sys.exit(main())
