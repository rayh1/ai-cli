#!/usr/bin/env python3
"""
Register or unregister MCP servers for all CLIs (Claude, Codex, Github Copilot)

Usage:
    python reg-mcp.py --name <server-name> --command <cmd> [args...] [--env KEY=VALUE ...]
    python reg-mcp.py --name <server-name> --remove

Examples:
    python reg-mcp.py --name myserver --command python3 /opt/mcp/server.py
    python reg-mcp.py --name github --command python3 /opt/mcp/github-mcp.py --env GITHUB_TOKEN=ghp_abc123
    python reg-mcp.py --name custom --command python3 /opt/mcp/custom.py --env API_KEY=secret123 DB_URL=postgresql://...
    python reg-mcp.py --name myserver --remove
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
        description="Register or unregister MCP servers for all CLIs (Claude, Codex, Github Copilot)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python reg-mcp.py --name myserver --command python3 /opt/mcp/server.py
    python reg-mcp.py --name github --command python3 /opt/mcp/github-mcp.py --env GITHUB_TOKEN=ghp_abc123
    python reg-mcp.py --name custom --command python3 /opt/mcp/custom.py --env API_KEY=secret DB_PASS=pwd123
    python reg-mcp.py --name myserver --remove

Security Warning:
  Environment variables are stored in PLAINTEXT in Docker volumes (ai-cli_home:/root).
  Only use for non-sensitive data or accept the security risk.
        """,
    )
    parser.add_argument("--name", required=True, help="MCP server name")
    action_group = parser.add_mutually_exclusive_group(required=True)
    action_group.add_argument(
        "--command",
        nargs="+",
        help="Command and arguments to run the MCP server",
    )
    action_group.add_argument(
        "--remove",
        action="store_true",
        help="Remove/unregister the MCP server from all CLIs",
    )
    parser.add_argument(
        "--env",
        action="append",
        help="Environment variable in KEY=VALUE format (can be specified multiple times)",
    )
    parser.add_argument(
        "--env-file",
        action="append",
        help=(
            "Path to file with environment variables in KEY=VALUE format, one per line. "
            "Lines starting with # and blank lines are ignored. Can be specified multiple times."
        ),
    )
    args = parser.parse_args()

    if args.remove and (args.env or args.env_file):
        parser.error("--env and --env-file can only be used with --command")

    return args


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
    base_command = shlex.join(command_parts)

    if not env_vars:
        return base_command, False

    def _format_env(var: str) -> str:
        """Format a KEY=VALUE env string as KEY='VALUE' for bash export.

        This ensures that complex values (JSON, spaces, special chars) are
        preserved correctly when passed through bash -c.
        """
        if "=" not in var:
            return var
        key, value = var.split("=", 1)
        quoted_value = shlex.quote(value)
        return f"{key}={quoted_value}"

    # Build export statements with safely quoted values
    export_statements = "; ".join(f"export {_format_env(var)}" for var in env_vars)
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


def unregister_claude(name, scripts_dir):
    """Unregister MCP server for Claude."""
    print("[1/3] Unregistering for Claude...")

    claude_cmd = scripts_dir / "claude.cmd"
    if claude_cmd.exists():
        claude_exe = str(claude_cmd)
    else:
        claude_exe = "claude"

    result = subprocess.run(
        [claude_exe, "mcp", "remove", name],
        capture_output=True,
        text=True,
    )

    if result.returncode == 0:
        print(f"[OK] Claude: MCP '{name}' removed")
        return True

    output = f"{result.stdout}\n{result.stderr}".lower()
    if any(token in output for token in ("not found", "not exist", "not registered", "no such")):
        print(f"[OK] Claude: MCP '{name}' was not registered")
        return True

    print("[ERROR] Claude: MCP removal failed.", file=sys.stderr)
    return False


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


def unregister_codex(name, scripts_dir):
    """Unregister MCP server for Codex."""
    print("[2/3] Unregistering for Codex...")

    codex_cmd = scripts_dir / "codex.cmd"
    if codex_cmd.exists():
        codex_exe = str(codex_cmd)
    else:
        codex_exe = "codex"

    result = subprocess.run(
        [codex_exe, "mcp", "remove", name],
        capture_output=True,
        text=True,
    )

    if result.returncode == 0:
        print(f"[OK] Codex: MCP '{name}' removed")
        return True

    output = f"{result.stdout}\n{result.stderr}".lower()
    if any(token in output for token in ("not found", "not exist", "not registered", "no such")):
        print(f"[OK] Codex: MCP '{name}' was not registered")
        return True

    print("[ERROR] Codex: MCP removal failed.", file=sys.stderr)
    return False


def update_copilot(name, command_parts, env_vars, repo_root, remove=False):
    """Register or unregister MCP server for Github Copilot."""
    action = "Unregistering" if remove else "Registering"
    print(f"[3/3] {action} for Github Copilot...")
    
    copilot_server = None
    if not remove:
        # Parse command into executable and args
        copilot_command = command_parts[0]
        copilot_args = command_parts[1:] if len(command_parts) > 1 else []

        # If env vars present, wrap in bash with safely quoted values
        def _format_env(var: str) -> str:
            if "=" not in var:
                return var
            key, value = var.split("=", 1)
            quoted_value = shlex.quote(value)
            return f"{key}={quoted_value}"

        if env_vars:
            export_statements = "; ".join(f"export {_format_env(var)}" for var in env_vars)
            copilot_command = "bash"
            copilot_args = ["-c", f"{export_statements}; {shlex.join(command_parts)}"]

        copilot_server = {
            "type": "local",
            "command": copilot_command,
            "args": copilot_args,
            "tools": ["*"],
        }

    python_script_content = f"""import json
import os
from pathlib import Path

config_dir = Path.home() / ".copilot"
config_file = config_dir / "mcp-config.json"
config_dir.mkdir(parents=True, exist_ok=True)

try:
    config = json.loads(config_file.read_text(encoding="utf-8")) if config_file.exists() else {{}}
except Exception:
    config = {{}}

if not isinstance(config, dict):
    config = {{}}

mcp_servers = config.get("mcpServers")
if not isinstance(mcp_servers, dict):
    mcp_servers = {{}}
config["mcpServers"] = mcp_servers

server_name = {json.dumps(name)}
remove = {repr(remove)}
server_config = {repr(copilot_server)}

if remove:
    existed = server_name in mcp_servers
    mcp_servers.pop(server_name, None)
    status = "removed" if existed else "was not registered"
else:
    mcp_servers[server_name] = server_config
    status = "configured"

config_file.write_text(json.dumps(config, indent=2) + "\\n", encoding="utf-8")
print(f"[OK] Github Copilot: MCP '{{server_name}}' {{status}} in {{config_file}}")
"""
    
    # Write to temporary file
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".py", delete=False, newline="\n"
    ) as f:
        f.write(python_script_content)
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
            f"{temp_script}:/tmp/setup-mcp.py",
            "--entrypoint",
            "python3",
            "ai-cli",
            "/tmp/setup-mcp.py",
        ]
        
        result = subprocess.run(cmd)
        
        if result.returncode != 0:
            print("[ERROR] Github Copilot: MCP update failed.", file=sys.stderr)
            return False
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

    scripts_dir = get_script_dir()
    repo_root = get_repo_root()

    if args.remove:
        print("=" * 40)
        print(f"Unregistering MCP Server: {name}")
        print("=" * 40)

        claude_ok = unregister_claude(name, scripts_dir)
        print()

        codex_ok = unregister_codex(name, scripts_dir)
        print()

        copilot_ok = update_copilot(name, None, None, repo_root, remove=True)
        print()

        print("=" * 40)
        if claude_ok and codex_ok and copilot_ok:
            print("Unregistration complete for all CLIs")
            print("=" * 40)
            return 0

        print("Unregistration completed with errors")
        print("=" * 40)
        return 1

    # Original env var strings from CLI
    raw_env_vars: list[str] = list(args.env or [])

    # Also load env vars from files, if provided. This avoids shell quoting issues
    # for complex values (JSON, %Y formats, etc.).
    if getattr(args, "env_file", None):
        for file_path in args.env_file:
            path_obj = Path(file_path)
            if not path_obj.exists():
                print(f"[WARNING] Env file not found: {path_obj}", file=sys.stderr)
                continue
            try:
                with path_obj.open("r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        raw_env_vars.append(line)
            except Exception as e:
                print(f"[WARNING] Failed to read env file {path_obj}: {e}", file=sys.stderr)

    # Support a friendlier macro syntax to avoid complex JSON quoting in shells:
    #   --env 'JOPLINK_MACRO_today=Journal/%%Y/%%m/%%Y-%m-%d'
    # becomes JOPLINK_MACROS={"today":"Journal/%Y/%m/%Y-%m-%d"}
    env_vars: list[str] = []
    macros: dict[str, str] = {}

    for var in raw_env_vars:
        if var.startswith("JOPLINK_MACRO_") and "=" in var:
            key, value = var.split("=", 1)
            macro_name = key.removeprefix("JOPLINK_MACRO_")
            if macro_name:
                macros[macro_name] = value
        else:
            env_vars.append(var)

    if macros:
        macros_json = json.dumps(macros)
        env_vars.append(f"JOPLINK_MACROS={macros_json}")

    # Build command string
    command_str, _ = build_command_with_env(command_parts, env_vars)

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
    
    copilot_ok = update_copilot(name, command_parts, env_vars, repo_root)
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
