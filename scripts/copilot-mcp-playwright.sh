#!/bin/bash
set -e

# Playwright MCP setup for Github Copilot CLI
# Configures: --browser chromium --headless --isolated --no-sandbox

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
      "command": "npx",
      "args": ["-y", "@playwright/mcp@latest", "--browser", "chromium", "--headless", "--isolated", "--no-sandbox"],
      "tools": ["*"]
    }
  }
}
EOF

echo "[OK] Playwright MCP configured in $CONFIG_FILE"
echo ""
echo "Configuration:"
cat "$CONFIG_FILE"
echo ""
echo "[INFO] Restart copilot CLI to use Playwright MCP."
