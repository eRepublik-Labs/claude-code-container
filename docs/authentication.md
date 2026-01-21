# Authentication Guide

Claude Code supports two authentication methods, each designed for different use cases.

## Method 1: Subscription Account (OAuth)

**Best for**: Interactive development, human users, Claude Pro/Team/Max subscriptions

This method uses browser-based OAuth authentication through claude.ai. Your credentials are stored securely in the container and persist across restarts when using volume mounts.

### Setup

1. **Create a persistent volume** (required for login state):
   ```bash
   # Docker
   docker volume create claude-auth

   # Apple Container
   container volume create claude-auth
   ```

2. **Start container WITHOUT `CLAUDE_API_KEY`**:
   ```bash
   # Docker
   docker run -it --rm \
     --cap-add=NET_ADMIN \
     --cap-add=NET_RAW \
     -m 4G \
     -v claude-auth:/home/dev/.claude \
     -v "$(pwd)":/workspace \
     ghcr.io/erepublik-labs/claude-code-container:latest

   # Apple Container
   container run -it --rm \
     -m 4G \
     -v claude-auth:/home/dev/.claude \
     -v "$(pwd)":/workspace \
     ghcr.io/erepublik-labs/claude-code-container:latest
   ```

3. **Login interactively**:
   ```bash
   # Inside container
   claude

   # Follow the browser prompts to authenticate with your Claude subscription
   ```

4. **Verify persistence** - Restart the container with the same volume:
   ```bash
   # Same command as step 2
   # You should NOT be prompted to login again
   ```

### How It Works

- OAuth credentials stored in `/home/dev/.claude/.credentials.json` (mode 600)
- Access tokens automatically refresh when expired
- Volume mount on `/home/dev/.claude` persists login state
- No API key needed in environment variables

### Limitations

- Only works for interactive sessions (`claude` command)
- Does NOT work with print mode (`claude -p`) - print mode requires direct API access
- Requires browser access during initial login

## Method 2: API Key

**Best for**: Automation, CI/CD pipelines, print mode (`claude -p`), programmatic access

This method uses Anthropic API keys from the Claude Console for direct API access.

### Setup

1. **Get your API key** from [console.anthropic.com](https://console.anthropic.com)

2. **Start container with `CLAUDE_API_KEY`**:
   ```bash
   # Docker
   docker run -it --rm \
     --cap-add=NET_ADMIN \
     --cap-add=NET_RAW \
     -m 4G \
     -v "$(pwd)":/workspace \
     -e CLAUDE_API_KEY="sk-ant-api03-..." \
     ghcr.io/erepublik-labs/claude-code-container:latest

   # Apple Container
   container run -it --rm \
     -m 4G \
     -v "$(pwd)":/workspace \
     -e CLAUDE_API_KEY="sk-ant-api03-..." \
     ghcr.io/erepublik-labs/claude-code-container:latest
   ```

### How It Works

- API key stored securely in `/home/dev/.claude/.api-key` (mode 600)
- Removed from environment variables after container starts
- Works for both interactive and print mode

**Security note:** The API key is visible in `docker inspect` during container creation but is immediately removed from the environment after startup.

## Decision Matrix

| Use Case | Recommended Method | Reason |
|----------|-------------------|--------|
| Daily interactive development | OAuth Subscription | More secure, auto-refresh, consolidated billing |
| Scripts & automation | API Key | Non-interactive, programmatic access |
| Print mode (`claude -p`) | API Key | OAuth tokens don't work for direct API calls |
| CI/CD pipelines | API Key | Non-interactive environment |
| Team collaboration | OAuth Subscription | Better credential management |
| One-off quick tasks | API Key | No login flow needed |

## Troubleshooting

### "Invalid API key" error with subscription login

**Cause:** Container started with `CLAUDE_API_KEY` environment variable, which overrides OAuth credentials.

**Solution:**
```bash
# Remove CLAUDE_API_KEY from your run command
# Ensure you're mounting the volume with your OAuth credentials
container run -it --rm \
  -m 4G \
  -v claude-auth:/home/dev/.claude \
  -v "$(pwd)":/workspace \
  ghcr.io/erepublik-labs/claude-code-container:latest
```

### "EACCES: permission denied, mkdir '/home/dev/.claude/debug'"

**Cause:** Volume ownership issue (volume owned by root, Claude runs as node user).

**Solution:** This is automatically fixed by the entrypoint script. If you still see this error:
```bash
# Stop the container and recreate the volume
container stop <container-name>
container volume rm claude-auth
container volume create claude-auth
# Try again
```

### Login state not persisting across container restarts

**Cause:** Not using a volume mount for `/home/dev/.claude`.

**Solution:**
```bash
# Ensure you're using -v flag with volume mount:
-v claude-auth:/home/dev/.claude
```

### Cannot access claude.ai during login

**Cause:** Firewall blocking claude.ai domain.

**Solution:** This should not happen with the current configuration. Verify:
```bash
# Inside container
cat /tmp/firewall-init.log | grep claude.ai
# Should show: "Resolving claude.ai..." and "Adding <IP> for claude.ai"
```

## Technical Details

See [CLAUDE.md](../CLAUDE.md#authentication) for implementation details about:
- Conditional authentication logic in entrypoint.sh
- How apiKeyHelper injection works
- Firewall requirements for each auth method
- Permission fix mechanism
