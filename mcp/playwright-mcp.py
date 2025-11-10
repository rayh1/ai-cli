import json
import os
import subprocess
import sys
from pathlib import Path

# Load config from playwright-mcp.json next to this script
config_path = Path(__file__).with_name("playwright-mcp.json")
try:
    with open(config_path, "r") as f:
        config = json.load(f)
except FileNotFoundError:
    print(f"Config file {config_path} not found, using defaults.", file=sys.stderr)
    config = {"headed": False, "display": ""}

headed = config.get("headed", False)
display = config.get("display", "")

# Determine the version of @playwright/mcp to use
playwright_version = ""
try:
    out = subprocess.check_output(
        ["npm", "ls", "-g", "@playwright/mcp", "--json", "--depth=0"],
        stderr=subprocess.DEVNULL,
        text=True,
    )
    data = json.loads(out)
    dep = data.get("dependencies", {}).get("@playwright/mcp")
    if dep and "version" in dep:
        print("Found @playwright/mcp version via npm ls")
        playwright_version = dep["version"]
except Exception:
    print(f"Could not determine @playwright/mcp version", file=sys.stderr)

if not playwright_version:
    sys.exit(1)

# Set DISPLAY environment variable if headed mode is enabled
if headed:
    if display:
        os.environ["DISPLAY"] = display
    else:
        os.environ["DISPLAY"] = "host.docker.internal:0.0"

cmd = [
    "npx",
    "--yes",
    f"@playwright/mcp@{playwright_version}",
    "--browser",
    "chromium",
    "--isolated",
    "--no-sandbox",
]
if not headed:
    cmd.append("--headless")

print(
    f"[playwright-mcp] Starting {' '.join(cmd)} (DISPLAY={os.getenv('DISPLAY', '<unset>')})",
    file=sys.stderr,
)
result = subprocess.run(cmd)
sys.exit(result.returncode)