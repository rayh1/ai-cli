# Persistent Claude Sessions with ai-shell and tmux

This workflow is for keeping one long-lived Claude session running inside Docker and reconnecting to it later, including over SSH to your workstation.

## Concept

There are two ai-shell modes:

- `ai-shell` without a name: starts an ephemeral shell and removes the container when you exit.
- `ai-shell <name>`: creates or reuses a named container and opens `bash` inside it. This is shorthand for `ai-shell --name <name>` when you are only specifying the container name.

One nuance: after `ai-shell <name>`, the remaining arguments are passed to `bash`. After `ai-shell --name <name>`, later `ai-shell` options are still parsed. For example, `ai-shell claude-main --root` passes `--root` to `bash`, while `ai-shell --name claude-main --root` runs the named container as root.

If you use `--port <container-port;host-port>`, those published ports are applied when the container is created. If the named container already exists, `ai-shell` will reuse it as-is, so changing published ports requires removing and recreating that container.

When you combine a named container with `tmux`, you get two layers of persistence:

- The named container stays available across shell disconnects.
- The tmux session stays available inside that container.

That means you can:

1. Start `claude` inside tmux.
2. Detach from tmux.
3. Close the terminal or disconnect SSH.
4. Come back later from another terminal or another machine over SSH.
5. Re-enter the same container and reattach to the same tmux session.

## Practical Flow

### 1. Start or reuse a named shell

Choose a stable container name, for example `claude-main`:

```powershell
ai-shell claude-main
```

The first run creates the container. Later runs reuse it.

### 2. Start tmux

Inside the container:

```bash
tmux new -s claude
```

### 3. Start Claude inside tmux

Inside tmux:

```bash
claude
```

Now your Claude session lives inside tmux, which lives inside the named container.

### 4. Detach and leave it running

Detach from tmux with:

```text
Ctrl+b then d
```

You can now exit the shell entirely:

```bash
exit
```

The named container remains available, and the tmux session remains there.

### 5. Reconnect later

From the same workstation, or after SSH-ing into it from elsewhere:

```powershell
ai-shell claude-main
```

Then reattach to tmux:

```bash
tmux attach -t claude
```

If you want a one-liner:

```powershell
ai-shell claude-main -lc "tmux attach -t claude || tmux new -s claude"
```

## SSH Use Case

This is the intended remote workflow:

1. SSH into your Windows workstation.
2. Run `ai-shell claude-main`.
3. Run `tmux attach -t claude`.
4. Continue the existing Claude session.

Your SSH connection can drop without destroying the Claude session, because the active process is anchored by tmux inside the persistent named container.

## Important Practical Detail

The named container keeps the `/workspace` bind mount from the moment it was first created.

That means:

- If you first run `ai-shell claude-main` from `D:\Workspace-prive\ai-work`, then `/workspace` inside the container points to that folder.
- If you later SSH in and run `ai-shell claude-main` from another directory, the container is reused, but `/workspace` still points to the original folder.

So the first launch should be done from the workspace directory you want that persistent container to use.

If you want the same container name to point to a different workspace later, recreate it:

```powershell
docker rm -f claude-main
ai-shell claude-main
```

## Recommended Pattern

For one stable development workspace:

```powershell
cd D:\Workspace-prive\ai-work
ai-shell claude-main
tmux new -s claude
claude
```

For later reconnects:

```powershell
ssh <your-workstation>
ai-shell claude-main -lc "tmux attach -t claude"
```

No `cd` is required for reconnecting to an existing named container. The container already keeps the `/workspace` bind mount from when it was first created.

## Notes

- `tmux` mouse scrolling is enabled.
- tmux scrollback history is increased.
- UTF-8 and terminal defaults are configured for better rendering in tmux.
- If a named container was created before these changes, recreate it once to pick up the new image and tmux config.