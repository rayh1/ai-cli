#!/bin/bash
set -e

# Playwright MCP setup for Github Copilot CLI

CONFIG_DIR="$HOME/.copilot"
CONFIG_FILE="$CONFIG_DIR/mcp-config.json"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Create or update the mcp-config.json file
cat > "$CONFIG_FILE" << 'EOF'
{
  "mcpServers": {
    "playwright": {
      "type": "local",
      "command": "python3",
      "args": ["/opt/mcp/playwright-mcp.py"],
      "tools": ["*"]
    }
  }
}
EOF

echo "[OK] Playwright MCP configured in $CONFIG_FILE"
