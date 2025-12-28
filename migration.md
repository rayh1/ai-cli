# Migration Guide: Root to Non-Root User

This guide covers migrating existing Docker volume data after switching from running as `root` to running as `aiuser`.

## Why Migration is Needed

The existing `ai-cli_home` volume contains authentication tokens and settings created as `root:root` (UID 0). After the changes, this volume is now mounted at `/home/aiuser`, but `aiuser` cannot access files owned by root.

## Migration Steps

### 1. Rebuild the Docker Image

First, rebuild the image with the new non-root user configuration:

```bash
docker compose build ai-cli
```

### 2. Fix Ownership of Existing Data

Run this command once to change ownership of all files in the home directory to `aiuser`:

```bash
docker compose run --rm --user root --entrypoint bash ai-cli -c "chown -R aiuser:aiuser /home/aiuser"
```

**What this does:**
- Temporarily runs the container as `root` (using `--user root`)
- Changes ownership of all files in `/home/aiuser` to `aiuser:aiuser`
- Exits automatically when complete

### 3. Test the Setup

Verify that the CLI works with the migrated data:

```bash
.\scripts\claude.cmd --version
```

You should see the version output without any permission errors.

## Alternative: Start Fresh

If you don't need to preserve authentication tokens or cached data, you can delete the old volume and start fresh:

```bash
# Stop any running containers
docker compose down

# Remove the old volume
docker volume rm ai-cli_home

# Rebuild (if not already done)
docker compose build ai-cli

# Use normally - you'll be prompted to authenticate on first use
.\scripts\claude.cmd --version
```

## Verification

Check that the container is running as the non-root user:

```bash
docker compose run --rm --entrypoint whoami ai-cli
```

Expected output: `aiuser`

## Troubleshooting

**Permission denied errors:**
- Run the migration command (step 2) again
- Verify the volume is mounted correctly in docker-compose.yml

**Authentication required:**
- Normal if you started fresh (deleted the volume)
- Run authentication commands for each CLI as needed
