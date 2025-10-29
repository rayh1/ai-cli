param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Rest
)

# Repo root = parent of this scripts/ folder
$RepoRoot   = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ComposeYml = Join-Path $RepoRoot "docker-compose.yml"

# Set HOST_PWD to the *caller’s* current directory (not the script location)
$env:HOST_PWD = (Get-Location).Path

try {
  docker compose `
    --project-directory "$RepoRoot" `
    -f "$ComposeYml" `
    run --rm claude @Rest
}
finally {
  # Clean up the temp env var
  Remove-Item Env:\HOST_PWD -ErrorAction SilentlyContinue
}
