param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Rest
)

# Resolve repo root (compose file lives next to this scripts/ folder)
$RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ComposeYml = Join-Path $RepoRoot "docker-compose.yml"

# Run compose with explicit project directory and compose file
docker compose `
  --project-directory "$RepoRoot" `
  -f "$ComposeYml" `
  run --rm claude @Rest
