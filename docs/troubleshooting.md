# Troubleshooting Guide

Common issues and solutions for Claude Code Secure Container.

## Authentication Issues

See [Authentication Guide - Troubleshooting](authentication.md#troubleshooting) for:
- "Invalid API key" errors
- Permission denied errors
- Login state not persisting
- Cannot access claude.ai

## Firewall Issues

### Firewall Initialization Failed

**Common causes:**
- **GitHub API rate limiting** (wait 60 minutes)
- **DNS resolution failure** (check host DNS settings)
- **Missing iptables capabilities (Docker)**: Ensure `--cap-add=NET_ADMIN` and `--cap-add=NET_RAW` flags are used
- **Architecture mismatch (Apple Container)**: Apple Silicon automatically builds ARM64 images

**Check logs:**
```bash
# Inside container
cat /tmp/firewall-init.log
cat /tmp/firewall-status
```

**Expected success message:**
```
Firewall initialized successfully
```

### Firewall Not Blocking Domains

If the firewall appears to allow unauthorized domains:

**1. Verify firewall initialized:**
```bash
# Inside container
cat /tmp/firewall-status
# Should output: "Firewall initialized successfully"
```

**2. Check iptables rules:**
```bash
# Inside container
iptables -L OUTPUT -v -n
# Should show:
# - Chain OUTPUT (policy DROP ...)
# - ACCEPT rules for DNS, localhost, allowed-domains
# - REJECT rule at the end
```

**3. Test blocking works:**
```bash
# Inside container - should FAIL (blocked)
curl --connect-timeout 5 https://www.facebook.com
curl --connect-timeout 5 https://www.google.com
curl --connect-timeout 5 https://example.com

# Should SUCCEED (allowed)
curl --connect-timeout 5 https://api.github.com/zen
curl --connect-timeout 5 https://registry.npmjs.org/
```

**4. Check allowed IPs:**
```bash
# Inside container
ipset list allowed-domains
# Should show ~92 IP ranges for GitHub, npm, Anthropic, etc.
```

### Cannot Reach Required Domain

If Claude Code cannot access a required service:

1. **Verify domain is in allowlist:**
   ```bash
   grep "your-domain.com" scripts/init-firewall.sh
   ```

2. **Add to allowlist if missing:**
   - Edit `scripts/init-firewall.sh`
   - Add domain around line 67-75
   - Rebuild: `docker build -t claude-code-container .`

3. **Verify firewall loaded domain:**
   ```bash
   # Inside container
   cat /tmp/firewall-init.log | grep your-domain.com
   ```

### Platform-Specific Issues

**Docker:**
- **Missing capabilities**: Container must be started with `--cap-add=NET_ADMIN --cap-add=NET_RAW`
- **Verification**: `docker inspect <container-id> | grep -A5 CapAdd` should show NET_ADMIN and NET_RAW

**Apple Container:**
- **Architecture**: Automatically builds ARM64 images on Apple Silicon
- **Build command**: `container build --tag claude-code-container:latest --file Dockerfile .`
- **Verification**: `container exec <name> uname -m` should show `aarch64`

### Known Fixed Issues

Previous versions had firewall issues that have been resolved:

- ✅ **Missing iptables extension modules**: Now installs both `iptables-legacy` and `iptables` packages
- ✅ **IPv6 CIDR ranges causing errors**: Now filters out IPv6 ranges automatically
- ✅ **Duplicate IP entries**: Uses `-exist` flag to handle gracefully
- ✅ **Apple Container incompatibility**: Firewall now works with iptables-legacy on Apple Container

## Git Issues

### "cannot run ssh" or "Permission denied (publickey)"

The container has no SSH binary. Git SSH URLs are automatically rewritten to HTTPS via `.gitconfig`, but this requires the config to be present.

**Check if `.gitconfig` is intact:**
```bash
# Inside container
cat ~/.gitconfig
# Should show:
# [url "https://github.com/"]
#   insteadOf = git@github.com:
#   insteadOf = ssh://git@github.com/
```

**If missing** (e.g., after manual deletion), restart the container — the entrypoint restores it automatically from `/opt/claude-templates/.gitconfig`.

## Performance Issues

### Container Feels Slow

**Git operations slow:**
- Git status caching activates automatically for repos >30k files
- First call builds cache (~5s), subsequent calls are fast (~1.3s)
- Cache refreshes every 5 minutes

**General slowness:**
- Check memory usage: `container exec <id> free -h`
- Increase container memory if needed (see Memory Issues below)

### Git Status Cache Not Working

**Check if enabled:**
```bash
# Inside container
which git
# Should show: /home/dev/.local/bin/git (wrapper)

# Check cache status
ls -la /tmp/git-status-cache-*
```

**Force cache rebuild:**
```bash
# Inside container
rm /tmp/git-status-cache-*
git status  # Will rebuild cache
```

## Memory Issues

### Out of Memory Errors

There are two memory limits to consider:

1. **Container Memory** (set with `-m` flag):
   - Controls total memory for container
   - Set when starting container
   - Cannot change for running container

2. **Node.js Heap** (set via `NODE_OPTIONS`):
   - Controls memory for Node.js/Claude Code
   - Should be ~75% of container memory
   - Can set via environment variable

**Increase memory:**

```bash
# 8GB example (Mac/Apple Container)
container run -it --rm \
  -m 8G \
  -e NODE_OPTIONS="--max-old-space-size=6144" \
  -v "$PWD:/workspace" \
  -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
  ghcr.io/erepublik-labs/claude-code-container:latest

# 8GB example (Docker)
docker run -it --rm \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -m 8G \
  -e NODE_OPTIONS="--max-old-space-size=6144" \
  -v "$PWD:/workspace" \
  -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
  ghcr.io/erepublik-labs/claude-code-container:latest
```

**Check current usage:**
```bash
# List containers with memory
container list
docker ps

# Check actual usage inside container
container exec <container-id> free -h
docker exec <container-id> free -h
```

## Terminal Issues

### Terminal Doesn't Use Full Width

**Solutions:**
- Ensure using `-it` flags (both interactive and TTY)
- Resize terminal window after starting container
- Container responds to terminal resize signals (SIGWINCH)

### Status Line Not Showing

**Check if enabled:**
```bash
# Inside container
cat ~/.claude/settings.json | jq .statusLine
```

**If disabled, enable in settings:**
```json
{
  "statusLine": {
    "type": "command",
    "command": "claude-powerline --style=minimal --theme=rose-pine"
  }
}
```

## Volume and Permission Issues

### Permission Denied on Volume Mounts

**Cause:** Volume owned by root, Claude Code runs as node user

**Solution:** Automatically fixed by entrypoint. If still occurring:

```bash
# Stop and remove container
container stop <container-name>
container rm <container-name>

# Recreate volume
container volume rm claude-auth
container volume create claude-auth

# Try again
```

### Cannot Write to Workspace

**Check volume mount:**
```bash
# Inside container
ls -la /workspace
# Should show your files

pwd
# Should show /workspace
```

**Verify mount in run command:**
```bash
-v "$(pwd)":/workspace
```

## Build Issues

### Container Build Fails

**Common causes:**
- Network connectivity issues
- Docker/Container daemon not running
- Insufficient disk space
- Build cache corruption

**Solutions:**
```bash
# Check daemon is running
container system start  # Apple Container
docker info             # Docker

# Clean build cache
container system prune  # Apple Container
docker system prune     # Docker

# Build without cache
container build --no-cache -t ghcr.io/erepublik-labs/claude-code-container:latest .
docker build --no-cache -t ghcr.io/erepublik-labs/claude-code-container:latest .
```

### "Structure needs cleaning" Error

**Apple Container specific issue with build cache**

**Solution:**
```bash
container system prune
container build -t ghcr.io/erepublik-labs/claude-code-container:latest .
```

## Runtime Issues

### Container Won't Start

**Check logs:**
```bash
container logs <container-id>
docker logs <container-id>
```

**Common issues:**
- Port conflicts (not applicable to this container)
- Memory limit too low (minimum 2GB recommended)
- Missing capabilities (Docker: need NET_ADMIN, NET_RAW)

### Container Starts But Claude Code Fails

**Check firewall status:**
```bash
# Inside container
cat /tmp/firewall-status
cat /tmp/firewall-init.log
```

**Check Claude Code status:**
```bash
# Inside container
claude --version
which claude
```

## Getting Help

If you can't resolve the issue:

1. **Check logs:**
   - `/tmp/firewall-init.log` - Firewall initialization
   - `/tmp/firewall-status` - Current firewall state
   - `~/.claude/debug/` - Claude Code debug logs

2. **Create GitHub issue:**
   - Include container runtime (Docker or Apple Container)
   - Include relevant logs
   - Describe steps to reproduce
   - Link: https://github.com/eRepublik-Labs/claude-code-container/issues

3. **Search existing issues:**
   - Someone may have encountered similar problem
   - Solutions often documented in issue comments
