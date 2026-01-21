# Claude Configuration

This directory contains default Claude Code configuration files that are copied into the container at build time.

## Files

- `CLAUDE.md` - Project-specific instructions for Claude Code
- `settings.json` - Claude Code settings (permissions, hooks, status line, etc.)
- `claude-powerline.json` - Powerline status bar configuration
- `commands/` - Custom slash commands for development workflows
- `hooks/` - Shell hooks for automation and validation

## Usage

### Build-time (Default)
These files are baked into the container image:
```bash
container build -t claude-code-container .
```

### Run-time Override (Optional)
To use live config from your host machine instead of baked-in defaults:

**Apple container:**
```bash
container run -it --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.claude:/home/dev/.claude" \
  -w /workspace \
  claude-code-container
```

**Docker:**
```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.claude:/home/dev/.claude" \
  -w /workspace \
  claude-code-container
```

## Updating Config

1. Edit files in this directory
2. Rebuild the image for changes to take effect
3. Or use runtime mount for immediate updates without rebuild
