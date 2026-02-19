# Session Documentation Protocol

This is a Claude Code session managed by the cs tool. Session metadata lives in the .cs/ directory. The session root is your workspace for project files.

## Session Files - READ THESE ON RESUME

When resuming this session, read the following files to restore context:

1. **.cs/summary.md** - If exists, read first for previous session overview
2. **.cs/README.md** - Session objective, environment, and outcome
3. **.cs/discoveries.md** - Recent findings, observations, and ideas
4. **.cs/discoveries.compact.md** - If exists, condensed historical findings
5. **.cs/changes.md** - Modifications and fixes made
6. **.cs/artifacts/MANIFEST.json** - List of tracked artifacts

Note: Historical discoveries are archived to .cs/discoveries.archive.md
and condensed into .cs/discoveries.compact.md. Only read the archive
if you need full detail on a specific past finding.

## Artifact Auto-Tracking

Scripts and configuration files you create are **automatically saved to .cs/artifacts/**:

- Scripts: .sh, .bash, .zsh, .py, .js, .ts, .rb, .pl
- Configs: .conf, .config, .json, .yaml, .yml, .toml, .ini, .env

When you use the Write tool for these file types, they are automatically redirected to the .cs/artifacts/ directory and tracked in MANIFEST.json.

## Documentation Discipline

Update the markdown documentation files throughout the session:

1. **Start of session:** Fill in .cs/README.md objective and environment
2. **As you work:** Update .cs/discoveries.md with findings and .cs/changes.md with modifications
3. **End of session:** Complete the .cs/README.md outcome section

Treat these files as a lab notebook - document as you go, not just at the end.

## Summary Command

When the session is complete, use the `/summary` command to generate an intelligent summary of the entire session. This will create a .cs/summary.md file synthesizing all documentation.

## Secure Secrets Handling

Sensitive data is automatically detected and stored securely (macOS Keychain, Windows Credential Manager, or encrypted file):

**Auto-detected patterns:**
- Files: .env, filenames containing key, secret, password, token, credential, auth
- Content: Variables like API_KEY, SECRET_TOKEN, PASSWORD, etc.

**What happens:**
1. Sensitive values are extracted and stored securely
2. The artifact file contains redacted placeholders
3. MANIFEST.json lists which secrets exist (not the values)

**Retrieving secrets:**
```bash
cs -secrets backend                # Check which storage backend is active
cs -secrets list                   # List secrets for current session
cs -secrets get API_KEY            # Get a specific secret value
cs -secrets export                 # Export as environment variables
```

**If you detect sensitive data** that wasn't auto-captured (unusual patterns, embedded credentials, etc.), use cs -secrets directly:
```bash
cs -secrets set <name> <value>     # Store manually
```

## Best Practices

- Document discoveries as you find them - don't wait until the end
- Use .cs/artifacts/ for any reusable scripts or configs
- .cs/changes.md is updated automatically when files are modified
- Run `/summary` at the end to create a cohesive record
- Never write raw API keys or passwords to artifact files - use cs -secrets


---

# Project Instructions

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a secure, isolated container environment for Claude Code development. The container implements strict network firewall rules that allow only authorized domains while maintaining full functionality for Claude Code, npm, and GitHub.

## Security Approaches: Container vs Native Sandbox

Claude Code offers two security approaches with different trade-offs:

### 1. Native Sandbox (Recommended for most use cases)

**What it is:** Claude Code's built-in sandboxing feature that provides OS-level isolation without containers.

**Pros:**
- ✅ **Zero performance penalty** - runs at native host speed
- ✅ **Simpler setup** - just edit `~/.claude/settings.json`
- ✅ **Auto-approve bash** - automatic command approval when sandboxed
- ✅ **Built-in and maintained** - supported directly by Anthropic
- ✅ **Perfect for Unity projects** - no VirtioFS overhead on large repos

**Cons:**
- ⚠️ Domain-level network filtering (can't inspect traffic content)
- ⚠️ Shares host environment (Node.js, tools, dependencies)
- ⚠️ Requires careful permission configuration

**Configuration:** Enable in `~/.claude/settings.json`:
```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "excludedCommands": ["docker", "container"]
  },
  "permissions": {
    "allow": ["WebFetch(domain:api.github.com)", ...],
    "deny": ["Read(.env**)", "Read(~/.ssh/**)", ...]
  }
}
```

**Best for:**
- Unity projects or large repositories (50k+ files)
- Development requiring frequent git operations
- Workflows prioritizing performance
- Most general development work

### 2. Container Approach (This Project)

**What it is:** Docker/Container-based environment with iptables firewall providing IP-level network isolation.

**Pros:**
- ✅ **IP-level network control** - more granular than domain filtering
- ✅ **Complete environment isolation** - reproducible development environment
- ✅ **Can inspect traffic** - full network visibility
- ✅ **Controlled tool versions** - locked Node.js, npm, git versions

**Cons:**
- ❌ **250x slower git operations** on large projects (VirtioFS overhead)
- ❌ **Setup complexity** - requires building/managing containers
- ❌ **Manual bash approval** - can't auto-approve in container mode

**Best for:**
- Web/Node.js projects with small to medium codebases
- Situations requiring maximum isolation
- Reproducible development environments
- Projects where security > performance

### Decision Matrix

| Use Case | Recommended Approach | Reason |
|----------|---------------------|--------|
| Unity development | Native Sandbox | Performance critical, large repos |
| React/Vue/Angular web apps | Either | Personal preference |
| Node.js API development | Either | Personal preference |
| Large monorepos (50k+ files) | Native Sandbox | Avoid VirtioFS overhead |
| Maximum security requirements | Container | IP-level control + isolation |
| Shared/team environment setup | Container | Reproducible environment |

**Hybrid Approach:** Use native sandbox for Unity, container for web projects - get the best of both worlds.

### Verifying Native Sandbox

After enabling native sandbox in `~/.claude/settings.json`, restart Claude Code and verify it's working:

**1. Check sandbox status:**
```bash
# Look for sandbox indicators in Claude Code session
# Bash commands should show "Running in sandbox" in the UI
```

**2. Test file access restrictions:**
```bash
# Should be blocked by Read deny rules
cat ~/.ssh/id_rsa          # Should fail
cat .env                   # Should fail (if .env exists)
cat ~/.aws/credentials     # Should fail

# Should work (not in deny list)
cat README.md              # Should succeed
cat package.json           # Should succeed
```

**3. Test network restrictions:**
```bash
# Should be blocked (not in allow list)
curl --connect-timeout 5 https://example.com

# Should work (in allow list)
curl --connect-timeout 5 https://api.github.com/zen
curl --connect-timeout 5 https://registry.npmjs.org
curl --connect-timeout 5 https://api.anthropic.com
```

**4. Verify auto-approve is working:**
- When sandbox is enabled with `autoAllowBashIfSandboxed: true`, bash commands should execute without permission prompts
- If you still see permission prompts for every bash command, the sandbox may not be active

**Troubleshooting:**
- If sandbox isn't active: Restart Claude Code completely
- If commands aren't auto-approved: Check `autoAllowBashIfSandboxed` is `true`
- If wrong files are blocked: Review `permissions.deny` patterns
- If network access fails: Add domain to `permissions.allow` list

## Architecture

### Container Components

- **Base Image**: Alpine Linux 3.22 (~5MB base)
- **Shell**: Bash
- **Coding Agents**: Claude Code (native binary)
- **Network Security**: iptables + ipset-based firewall with allowlist
- **Persistence**: Single volume at `/home/dev` for all state
- **Size**: ~330MB (vs ~800MB with previous Debian version)
- **User**: `claude` (UID 1000)

**Key Technical Details:**
- Uses musl libc (requires libgcc, libstdc++, gcompat for Claude Code binary)
- External ripgrep required (`USE_BUILTIN_RIPGREP=0`)
- Process management via su-exec (Alpine's gosu alternative)
- ast-grep installed from native Alpine package (edge/community repository)
- SSH client available via `openssh-client`; firewall allows outbound SSH (port 22)
- Firewall works in both Docker (requires `--cap-add=NET_ADMIN --cap-add=NET_RAW`) and Apple Container
- Apple Container automatically builds ARM64 images on Apple Silicon

### Firewall Architecture

The `init-firewall.sh` script implements a strict allowlist-based firewall using iptables-legacy:

1. **Allowed Services**:
   - GitHub (API, web, git via api.github.com/meta CIDR ranges, IPv6 filtered)
   - npm registry (registry.npmjs.org)
   - Anthropic API (api.anthropic.com)
   - Statsig analytics (statsig.anthropic.com, statsig.com)
   - GHCR (ghcr.io) for update checks
   - Local host network (auto-detected /24 subnet)

2. **Process Flow**:
   - Preserves Docker DNS rules (127.0.0.11)
   - Flushes existing iptables rules
   - Creates ipset hash:net for CIDR ranges
   - Resolves domain IPs via DNS
   - Fetches GitHub IP ranges from api.github.com/meta (filters out IPv6)
   - Adds IPs to ipset with `-exist` flag (handles duplicates gracefully)
   - Sets default DROP policy
   - Allows established connections and ipset matches
   - Rejects other traffic with ICMP admin-prohibited

3. **Verification**:
   - Confirms example.com is blocked (negative test)
   - Confirms api.github.com is accessible (positive test)

**Platform Support:**
- ✅ Docker: Requires `--cap-add=NET_ADMIN --cap-add=NET_RAW` capabilities
- ✅ Apple Container: Works with iptables-legacy (requires ARM64 images)
- Uses iptables-legacy backend for maximum compatibility
- Requires both `iptables-legacy` and `iptables` packages (for extension modules)

### Container Configuration

Key runtime requirements:

- Docker: Requires `--cap-add=NET_ADMIN --cap-add=NET_RAW` for iptables firewall
- Apple Container: No additional capabilities needed (iptables-legacy works by default)
- Mounts persistent volume for Claude config
- Sets `NODE_OPTIONS=--max-old-space-size=3072` for memory (3 GB for Node.js, optimized for 4 GB container)
- Runs `init-firewall.sh` automatically on container start

### Update Notification System

The container automatically notifies users when new versions are available using Claude Code's built-in `companyAnnouncements` feature.

**Architecture:**
- Uses native Claude Code `companyAnnouncements` setting (introduced in Claude Code 2.0.32)
- Background update check runs on every container startup
- Injects notification message into `~/.claude/settings.json` when update detected
- Clears notification when container is up-to-date
- Notification displays when user runs `claude` command
- Script location: `/usr/local/bin/check-updates.sh`

**Implementation Details:**

1. **Version Detection:**
   - `CONTAINER_VERSION` environment variable set during build
   - Passed as build arg from CI/CD workflow (`publish.yml`)
   - Extracted from git tags via docker/metadata-action
   - CalVer format: `YYYY.M.PATCH`

2. **Update Check Process:**
   - Gets anonymous token from GHCR: `https://ghcr.io/token?scope=repository:...`
   - Queries GHCR tags list: `https://ghcr.io/v2/{repo}/tags/list`
   - Filters for CalVer tags (YYYY.M.PATCH), sorts to find latest
   - Lexicographic version comparison (works for CalVer)
   - Fetches OCI index annotations for release notes
   - 5-second timeout with silent failure
   - Injects `companyAnnouncements` into settings.json if update available
   - Clears `companyAnnouncements` if up-to-date

3. **Release Notes:**
   - Release notes embedded as `com.erepubliklabs.release-notes` label in image config
   - CI workflow extracts first 3 dash-prefixed lines from GitHub Release body
   - Format: `grep -E '^-'` to find bullet points, `head -n 3` to limit
   - Joins lines with spaces, removes pipe characters
   - Update check reads from image config labels (no auth needed)

4. **Notification Display:**
   - Format: Single-line message with version and first 3 release notes
   - Pattern: `🔔 Container update available: {current} → {latest}\n{note1} {note2} {note3}`
   - Displays when Claude Code starts (native integration)
   - Injected as `companyAnnouncements` array in `~/.claude/settings.json`

5. **Settings Injection:**
   ```bash
   # Script uses jq to safely update settings.json
   jq '.companyAnnouncements = [$msg]' settings.json

   # Resulting settings.json contains:
   {
     "companyAnnouncements": [
       "🔔 Container update available: 2025.11.4 → 2025.11.5\n- Add colored firewall messages\n- Fix CHANGELOG initialization"
     ]
   }
   ```

**Network Requirements:**
- Requires `ghcr.io` in firewall allowlist (configured in init-firewall.sh)
- Anonymous token authentication (public container images)
- No rate limits for public container images

**Disabling:**
- Set environment variable: `SKIP_UPDATE_CHECK=1`
- Check skipped entirely, no network calls or settings modifications made

**Error Handling:**
- Fails silently on network timeout (5 seconds)
- Fails silently on API errors (rate limit, DNS failure)
- Fails silently if `CONTAINER_VERSION=dev` or `unknown`
- Fails silently if settings.json doesn't exist or is malformed
- No error messages displayed to user

**Performance:**
- Background spawn: `check-updates.sh >/dev/null 2>&1 &`
- No blocking, no startup delay
- Checks GHCR on every container start (5 second timeout)
- Settings.json update using jq: <10ms

**User Experience:**
- Users only see notification when they run `claude` command
- Native integration with Claude Code's UI
- No duplicate notifications or custom shell rendering

## Performance Characteristics

### Project Size Considerations

Container performance varies significantly based on project size and git repository complexity:

**Optimal Use Cases** (Fast Performance):
- Web applications (React, Vue, Angular)
- Node.js projects
- Small to medium codebases (<10k files)
- Projects with shallow git history

**Challenging Use Cases** (Slow Git Operations):
- Unity projects with large asset repositories
- Projects with 50k+ tracked files
- Repos with extensive git history

### Measured Performance

Benchmark results on Unity project (50k+ files):

| Operation | Host (macOS) | Container | Overhead |
|-----------|--------------|-----------|----------|
| File read (10x) | 0.075s | 0.009s | **8.3x faster** |
| File write (100MB) | 0.027s | 0.033s | 22% slower |
| **git status** | **0.36s** | **90s** | **250x slower** |
| git log | 0.03s | 0.12s | 4x slower |
| Node.js startup | 0.27s | 0.14s | **2x faster** |
| Code search (grep) | 3.0s | 32s | 10x slower |

### Root Cause

The git performance bottleneck is **architectural**:
- VirtioFS (Apple's virtualization filesystem) adds latency to each filesystem operation
- Git operations require thousands of stat() calls across many small files
- Each operation crosses the hypervisor boundary
- Large projects amplify this overhead

### Git Status Caching Solution

The container includes an **automatic git status caching system** that dramatically improves performance for large repositories:

**How it works:**
1. Auto-detects large repos (>30,000 tracked files)
2. Returns cached results instantly
3. Cache refreshes every 5 minutes in background
4. Small repos use normal git (no overhead)

**Performance:**
- First call: Shows "Building cache in background" message (~2 minutes to build)
- Subsequent calls: **0.06s** (instant)
- Small repos: **0.02s** (no caching overhead)

**Implementation details:**
- System git moved to `/usr/bin/.git-original` (not `git-*` pattern to avoid git builtin name parsing)
- Git wrapper installed at `/usr/bin/git` (intercepts all git calls)
- Wrapper script at `/usr/local/bin/git-wrapper`
- Caching script at `/usr/local/bin/git-status-fast.sh`
- Cache stored in `/tmp/git-status-cache-<hash>` per repository
- Automatic cache expiration after 5 minutes
- Works transparently - no PATH or configuration needed

**Trade-offs:**
- Cache staleness: Results can be up to 5 minutes old
- First call requires ~2 minutes to build cache
- Acceptable for most workflows (Claude Code, IDE usage)

### Legacy Optimization Attempts

Previous strategies tested before the caching solution:

1. **Git Config Tuning**: Enabled core.preloadIndex, core.untrackedCache, feature.manyFiles
   - Result: No improvement (bottleneck is filesystem, not git algorithms)

2. **Watchman/FSMonitor**: Attempted to reduce filesystem operations
   - Result: Daemon crashed on startup, incompatible with container environment

3. **Git Proxy (prototype)**: Execute git commands on host via IPC
   - Result: Named pipes don't work reliably across container/host boundary

### Recommendation

**Use containers for:**
- Large Unity/game projects with git status caching (instant after initial build)
- Web/Node.js projects where git performance is acceptable
- Projects where security isolation is critical
- Any project where 5-minute cache staleness is acceptable

**Use host Claude Code for:**
- Projects requiring real-time git status (no 5min cache acceptable)
- Workflows with very frequent git operations and immediate status updates
- When you can't wait ~2 minutes for initial cache build

With the git status caching solution, large projects have acceptable performance in containers.

## Persistence Strategy

The container uses a **single volume** mounted at `/home/dev` to persist all user-level state and configuration.

### What Gets Persisted

With a single `dev-home` volume, the following persist across container restarts:

- **Claude Configuration**: `/home/dev/.claude/`
  - Conversation history
  - OAuth credentials or API key
  - Settings and preferences
  - User memory (CLAUDE.md)
  - File edit history

- **GitHub CLI**: `/home/dev/.config/gh/`
  - Authentication tokens
  - Git credentials

- **Shell History**: `/home/dev/.zsh_history`
  - Command history across sessions

- **Claude Code Installation**: `/home/dev/.local/`
  - Native binary and versions
  - Updates persist automatically

- **npm Global Packages**: `/home/dev/.npm-global/`
  - claude-powerline

- **System Tools**: Installed via Alpine packages
  - ast-grep (native Alpine package from edge/community)

### Volume Restoration System

On first run with a fresh volume, the container automatically restores essential components:

1. **Claude Code installation** - Copied from `/opt/claude-installation/.local/`
2. **npm global packages** - Copied from `/opt/claude-installation/.npm-global/`
3. **Configuration templates** - Copied from `/opt/claude-templates/`

**Performance:**
- First run: ~3 seconds (one-time restoration)
- Subsequent runs: Instant (uses persisted installation)

**Updates:**
Claude Code updates (`claude update`) modify files in `/home/dev/.local/share/claude/`, which persist in the volume. No re-restoration needed after updates.

### Settings Merge System

The container automatically merges new template settings with user customizations on container updates.

**How it works:**
- Template `settings.json` includes `templateVersion` field (e.g., `"templateVersion": 1`)
- On container start, entrypoint compares template version vs user's version
- If template is newer, merges settings using `jq`: template provides new keys, user values take precedence
- User customizations are never overwritten

**Merge behavior:**
```bash
# User has old settings (version 0 or missing)
# Template has new settings (version 1)
# Result: New template keys added, user's existing values preserved
```

**Example:**
```json
// User's settings (before merge)
{
  "customUserSetting": "my value",
  "disabledTools": ["NotebookEdit"]
}

// After container update with new template (version 1)
{
  "templateVersion": 1,
  "customUserSetting": "my value",
  "disabledTools": ["NotebookEdit"],
  "hooks": { ... },           // New from template
  "statusLine": { ... },      // New from template
  "alwaysThinkingEnabled": true  // New from template
}
```

**Performance:**
- Merge runs on every container start
- ~10ms execution time (negligible)
- Only merges when template version changes

**For maintainers:**
When pushing new settings changes:
1. Edit `claude-config/settings.json`
2. Increment `templateVersion` (e.g., `1` → `2`)
3. Build and release container
4. Users automatically get new settings on next start
5. Their customizations are preserved

### Enable Persistence

Use a single named volume for all user data:

```bash
# Create volume (once)
container volume create dev-home  # or: docker volume create dev-home

# Mount the volume
container run -v dev-home:/home/dev ...
docker run -v dev-home:/home/dev ...
```

### Access Persisted Data

```bash
# Inside container, everything is in your home directory
ls -la ~/
ls -la ~/.claude/projects/        # Conversation history
ls -la ~/.config/gh/              # GitHub CLI config
cat ~/.zsh_history                 # Shell history

# View a specific conversation (JSONL format)
cat ~/.claude/projects/[project-hash]/[session-id].jsonl
```

## Authentication

The container supports two authentication methods. All credentials persist automatically when using the `dev-home` volume.

### OAuth Subscription Authentication

**How it works:**
- Start container WITHOUT `CLAUDE_API_KEY` environment variable
- Run `claude` and follow browser-based OAuth login flow
- Credentials stored in `/home/dev/.claude/.credentials.json` (mode 600)
- Access tokens refresh automatically when expired
- Persists across container restarts with volume mount

**Setup:**
```bash
# Create persistent volume (once)
container volume create dev-home

# Start container (no CLAUDE_API_KEY)
container run -it --rm \
  -m 4G \
  -c 4 \
  -v dev-home:/home/dev \
  -v "$(pwd)":/workspace \
  -e HOST_USER=Alex \
  claude-code-container:latest

# Inside container, run interactive login
claude
```

**Technical details:**
- OAuth tokens (sk-ant-oat01-*) are NOT valid for direct API calls
- Only works for interactive sessions (`claude` command)
- Does NOT work with print mode (`claude -p`)
- Credentials format: `{claudeAiOauth: {accessToken, refreshToken, expiresAt, subscriptionType}}`

### API Key Authentication

**How it works:**
- Pass `CLAUDE_API_KEY` environment variable at container start
- Entrypoint writes key to `/home/dev/.claude/.api-key` (mode 600)
- Injects `apiKeyHelper` into `settings.json` to use the key file
- Key removed from environment after secure storage
- Works for both interactive and print mode

**Setup:**
```bash
container run -it --rm \
  -m 4G \
  -c 4 \
  -v "$(pwd)":/workspace \
  -e CLAUDE_API_KEY="sk-ant-api03-..." \
  -e HOST_USER=Alex \
  claude-code-container:latest
```

**Technical details:**
- API keys (sk-ant-api03-*) are valid for direct API calls
- Required for print mode (`claude -p`)
- Required for automation/CI/CD
- When `CLAUDE_API_KEY` is set, `apiKeyHelper` overrides native OAuth credential lookup

### Implementation Details

**Conditional Authentication Logic (entrypoint.sh):**
1. If `CLAUDE_API_KEY` is set:
   - Write to `/home/dev/.claude/.api-key` (mode 600)
   - Inject `apiKeyHelper: "cat /home/dev/.claude/.api-key ..."` into settings.json
   - Remove from environment
2. If `CLAUDE_API_KEY` is NOT set:
   - No `apiKeyHelper` in settings.json
   - Claude Code uses native credential lookup from `.credentials.json`
   - Allows OAuth subscription authentication to work

**Firewall Requirements:**
- OAuth: Requires `claude.ai` in allowlist (for login flow and token refresh)
- API Key: Requires `api.anthropic.com` in allowlist
- Both domains currently whitelisted in `init-firewall.sh`

**Permission Fix:**
- Entrypoint runs `chown -R node:node /home/dev/.claude /home/dev/.config` at startup
- Fixes volume mount ownership (defaults to root)
- Ensures Claude Code and gh CLI can write to their config directories

**Both Agents Share Authentication:**
- **Claude Code**: Reads API key via `apiKeyHelper` from `~/.claude/.api-key`
- **Pi**: Wrapper script at `/usr/local/bin/pi` auto-loads key from `~/.claude/.api-key`
- No additional configuration needed - both agents work with the same API key automatically

### GitHub CLI Authentication

GitHub CLI (`gh`) authentication automatically persists when using the single volume approach.

**How it works:**
- GitHub CLI stores tokens in `/home/dev/.config/gh/hosts.yml` (mode 600)
- With `dev-home:/home/dev` volume, credentials persist across container restarts
- No additional configuration needed

**First-time setup:**
```bash
# Start container with persistent volume
container run -it --rm \
  -m 4G \
  -c 4 \
  -v dev-home:/home/dev \
  -v "$(pwd)":/workspace \
  -e HOST_USER=Alex \
  claude-code-container:latest

# Inside container, authenticate with GitHub
gh auth login

# Follow the prompts:
# - Choose: GitHub.com
# - Protocol: HTTPS (recommended) or SSH
# - Authenticate: Login with a web browser
# - Copy the one-time code and complete in browser
```

**Verify persistence:**
```bash
# Exit and restart container
exit

# Start container again with same volume
container run -it --rm \
  -m 4G \
  -c 4 \
  -v dev-home:/home/dev \
  -v "$(pwd)":/workspace \
  -e HOST_USER=Alex \
  claude-code-container:latest

# Check authentication status (should still be logged in)
gh auth status
```

**Security notes:**
- Tokens stored with mode 600 (owner read/write only)
- Tokens scoped based on permissions granted during `gh auth login`
- Can be revoked at: https://github.com/settings/tokens
- Volume persists on host filesystem

## Shell Helper Functions

For convenient daily usage, add these functions to your `~/.zshrc` or `~/.bashrc`:

**Apple Container (Mac):**
```bash
ccupdate() {
    container system start
    container image pull ghcr.io/erepublik-labs/claude-code-container:latest
}

cc() {
  container system start
  container run -it --rm \
    --name claude-$(basename "$PWD") \
    -m 4G \
    -c 4 \
    -v claude-home:/home/dev \
    -v "$PWD:/workspace" \
    -w /workspace \
    -e HOST_USER="$USER" \
    ghcr.io/erepublik-labs/claude-code-container:latest
}
```

**Docker:**
```bash
ccupdate() {
    docker pull ghcr.io/erepublik-labs/claude-code-container:latest
}

cc() {
  docker run -it --rm \
    --name claude-$(basename "$PWD") \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    -m 4G \
    --cpus=4 \
    -v claude-home:/home/dev \
    -v "$PWD:/workspace" \
    -w /workspace \
    -e HOST_USER="$USER" \
    ghcr.io/erepublik-labs/claude-code-container:latest
}
```

**Windows (PowerShell 7+):**

First, set the `ANTHROPIC_API_KEY` environment variable. Choose one method:

```powershell
# Option 1: Set for current user (persists across sessions, recommended)
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-api03-...", "User")

# Option 2: Set system-wide (requires admin, available to all users)
# Run PowerShell as Administrator, then:
[Environment]::SetEnvironmentVariable("ANTHROPIC_API_KEY", "sk-ant-api03-...", "Machine")

# Option 3: Set temporarily for current session only (lost when terminal closes)
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."
```

After setting with Option 1 or 2, restart your terminal for changes to take effect. Verify with:
```powershell
echo $env:ANTHROPIC_API_KEY
```

Next, create a PowerShell profile if you don't have one:
```powershell
if (!(Test-Path -Path $PROFILE)) {
  New-Item -ItemType File -Path $PROFILE -Force
}
```

Then add these functions to your profile (`notepad $PROFILE`):
```powershell
Function ccupdate {
  docker pull ghcr.io/erepublik-labs/claude-code-container:latest
}

Function cc {
  docker run -it --rm `
    --name claude-$(Split-Path -Leaf $PWD) `
    --cap-add=NET_ADMIN `
    --cap-add=NET_RAW `
    -m 4G `
    --cpus=4 `
    -v claude-home:/home/dev `
    -v "${PWD}:/workspace" `
    -w /workspace `
    -e CLAUDE_API_KEY="$env:ANTHROPIC_API_KEY" `
    -e HOST_USER="$env:USERNAME" `
    ghcr.io/erepublik-labs/claude-code-container:latest
}
```

**Usage:**
- `cc` - Start Claude Code in current directory
- `ccupdate` - Update to latest container image

## Common Commands

### Container Management

```bash
# Rebuild and restart container
# The firewall initializes automatically on container startup

# Check firewall initialization logs
cat /tmp/firewall-init.log

# View firewall status (if initialization complete)
cat /tmp/firewall-status
```

### Testing Network Access

```bash
# Test blocked domain (should fail)
curl --connect-timeout 5 https://example.com

# Test allowed domains (should succeed)
curl --connect-timeout 5 https://api.github.com/zen
curl --connect-timeout 5 https://registry.npmjs.org
curl --connect-timeout 5 https://api.anthropic.com

# View DNS resolution
dig +short api.github.com
```

### Development Tools

Installed tools available:
- `fzf` - fuzzy finder for interactive selection
- `jq` - JSON processor
- `gh` - GitHub CLI
- `ssh` - SSH client for remote connections
- `dig` - DNS lookup
- `nano` - text editor (default)

## Release Process

This project uses CalVer versioning: `YYYY.M.PATCH` (e.g., `2025.11.21`).

**IMPORTANT: Tags must NOT include a `v` prefix.**

### Creating a Release

```bash
# 1. Ensure working tree is clean
git status

# 2. Commit any changes
git add <files>
git commit -m "description"
git push

# 3. Create release (NO 'v' prefix!)
gh release create 2025.11.21 \
  --title "2025.11.21" \
  --notes "Release notes here"
```

**Workflow trigger pattern:** `20[0-9][0-9].[1-9].*` and `20[0-9][0-9].1[0-2].*`
- ✅ Correct: `2025.11.21`, `2025.12.1`
- ❌ Wrong: `v2025.11.21`, `v2025.12.1`

The GitHub Actions workflow automatically builds and publishes the container image when a correctly-formatted tag is pushed.

## Modifying Network Allowlist

To add a new allowed domain:

1. Edit `init-firewall.sh`
2. Add domain to the `for domain in` loop (around line 67-75)
3. Rebuild container to apply changes

Example:
```bash
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "your-new-domain.com"; do  # Add here
```

For IP ranges instead of domains:
```bash
# Edit init-firewall.sh and add after domain resolution section (around line 100):
echo "Adding custom range"
ipset add allowed-domains "203.0.113.0/24"

# Then rebuild container to apply changes
```

## MCP Servers

Claude Code natively supports MCP (Model Context Protocol) configuration at the project level. The container's role is minimal:

### Stdio MCP Servers

Local MCP servers (run via npx) work automatically with no container configuration needed:
- Examples: sequential-thinking, filesystem, puppeteer
- Installed on-demand when first used
- Run with dev user permissions (non-root)

### HTTP MCP Servers

Remote MCP servers require their domains to be added to the firewall allowlist:

1. Edit `scripts/init-firewall.sh` and add domain to the allowlist (around line 67-72):
```bash
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "mcp.context7.ai"; do  # Add HTTP MCP server domain here
```

2. Rebuild container to apply changes

**Note:** Claude Code handles MCP configuration (servers, environment variables, etc.) natively. See [Claude Code MCP documentation](https://docs.anthropic.com/claude/docs/mcp) for configuration details

## Security Considerations

### API Key Security

The container implements secure API key handling to prevent exposure in the environment:

**How it works:**
1. Pass `CLAUDE_API_KEY` as an environment variable when starting the container
2. The entrypoint script writes the key to `/home/dev/.claude/.api-key` (chmod 600)
3. The `apiKeyHelper` in settings.json reads from this secure file
4. The key is immediately removed from the environment before Claude Code starts

**Result:** The API key never appears in:
- `docker inspect` or `container inspect` output
- Process listings (`ps aux`)
- Environment variable dumps (`printenv`)
- Container logs

**Usage:**
```bash
# Pass API key at container startup
container run -e CLAUDE_API_KEY="your-key-here" ...
docker run -e CLAUDE_API_KEY="your-key-here" ...

# The key will be stored securely and removed from environment automatically
```

**Implementation details:**
- API key stored in: `/home/dev/.claude/.api-key`
- File permissions: `600` (owner read/write only)
- apiKeyHelper command: `cat /home/dev/.claude/.api-key 2>/dev/null || echo $CLAUDE_API_KEY`
- Fallback to environment variable for backward compatibility

**Note:** The API key is only in the environment briefly during container initialization. Once Claude Code starts, the key exists only in the secure file inside the container.

### Firewall Design Principles

- **Fail-secure**: Default DROP policy on INPUT, OUTPUT, FORWARD
- **Explicit allowlist**: Only specified domains/IPs permitted
- **DNS before DROP**: DNS queries allowed before restrictions
- **Established connections**: Return traffic for approved connections allowed
- **Docker DNS preserved**: Internal DNS resolution maintained
- **Host network access**: Local subnet auto-detected and allowed

### Security Verification

The firewall includes built-in verification:
- Negative test: Blocks access to example.com
- Positive test: Confirms GitHub API access
- Script exits with error code if verification fails

### CI/CD Security

The CI/CD pipeline implements comprehensive supply chain security features:

**Automated Vulnerability Scanning:**
- Trivy scanner for CVE detection (Alpine packages, npm dependencies)
- Scans run on every release after image build
- CRITICAL and HIGH CVEs block releases (exit-code: 1)
- Results saved as JSON artifacts (90-day retention)

**Software Bill of Materials (SBOM):**
- Generated with Syft in SPDX-JSON format
- Uploaded as workflow artifacts (90-day retention)
- Lists all packages with versions (Alpine + npm)
- Provides transparency for compliance and auditing

**Security Reports:**
- Trivy JSON results uploaded as artifacts (90-day retention)
- SBOM uploaded as artifacts (90-day retention)
- All scan results available in workflow artifacts

**Workflow Permissions:**
```yaml
permissions:
  contents: read       # Read repository
  packages: write      # Push to GHCR
```

**GitHub Free Plan Limitations:**

The following security features require a paid GitHub plan or public repository and are not currently available:
- Build provenance attestation (requires GitHub Enterprise or public repo)
- Image signing with Cosign (requires paid plan or public repo)
- SARIF upload to Security tab (requires GitHub Advanced Security)
- SBOM attachment to releases (permission errors on private repos)

**Testing Security Features:**

Local Trivy scan:
```bash
trivy image --severity CRITICAL,HIGH,MEDIUM \
  ghcr.io/erepublik-labs/claude-code-container:latest
```

Local SBOM generation:
```bash
syft ghcr.io/erepublik-labs/claude-code-container:latest -o spdx-json
```

**Vulnerability Management:**
- CRITICAL vulnerabilities block releases
- Accepted vulnerabilities documented in `.trivyignore` with explanations
- Security fixes released as soon as possible (emergency releases for CRITICAL)
- See [SECURITY.md](SECURITY.md) for full security policy

### Common Pitfalls

1. **Adding domain after default DROP**: Ensure new allowlist rules are added BEFORE the final REJECT rule
2. **DNS resolution timing**: Domains are resolved at firewall init time; IP changes require re-running init script
3. **IPv6 filtering**: GitHub API returns both IPv4 and IPv6 ranges; script filters out IPv6 automatically
4. **Duplicate entries**: ipset uses `-exist` flag to handle duplicate IPs gracefully
5. **Docker DNS rules**: Must be preserved before flushing iptables or container DNS breaks

## Terminal Resize

The container uses `gosu` instead of `su` in the entrypoint to ensure proper signal forwarding. This allows SIGWINCH (terminal resize) signals to reach Claude Code when you resize your terminal window.

If you experience terminal resize issues:

```bash
# Ensure you're running with -it flags for interactive TTY
docker run -it ...
container run -it ...

# Optional: Add --init flag for additional signal handling
docker run --init -it ...
container run --init -it ...
```

The `gosu` tool is installed via apt and provides better signal handling than `su` for containerized applications.

## Troubleshooting

### Cannot reach allowed domain

```bash
# Check firewall initialization logs
cat /tmp/firewall-init.log

# Verify DNS resolution (if you can exec into the container)
dig +short <domain>

# If needed, rebuild container to re-initialize firewall
```

### Container DNS not working

```bash
# Check firewall initialization logs for DNS setup
cat /tmp/firewall-init.log | grep -i dns

# Rebuild container to re-initialize DNS and firewall
```

### Out of memory errors

Increase memory allocation by setting NODE_OPTIONS environment variable:
```bash
# For 4GB container (default)
docker run -m 4G --cpus=4 -e NODE_OPTIONS="--max-old-space-size=3072" ...
container run -m 4G -c 4 -e NODE_OPTIONS="--max-old-space-size=3072" ...

# For 8GB container
docker run -m 8G --cpus=8 -e NODE_OPTIONS="--max-old-space-size=6144" ...
container run -m 8G -c 8 -e NODE_OPTIONS="--max-old-space-size=6144" ...

# Or rebuild with different limit in Dockerfile (line 7)
ENV NODE_OPTIONS="--max-old-space-size=3072"
```

### Firewall script fails

Common issues:
- **GitHub API rate limiting**: Wait and retry
- **DNS resolution failure**: Check host DNS settings
- **Missing capabilities (Docker)**: Ensure `--cap-add=NET_ADMIN --cap-add=NET_RAW` flags are used
- **Architecture mismatch (Apple Container)**: Apple Silicon automatically builds ARM64 images

**Note**: Previous versions had issues with missing iptables extension modules and IPv6 filtering. These have been fixed:
- Both `iptables-legacy` and `iptables` packages now installed (provides match extensions)
- IPv6 CIDR ranges automatically filtered during initialization
- Duplicate IP entries handled gracefully with `-exist` flag

## File Structure

```
.
├── Dockerfile                      # Container image definition
├── scripts/
│   ├── entrypoint.sh              # Container entrypoint script
│   ├── init-firewall.sh           # Firewall initialization script
│   ├── git-wrapper.sh             # Git wrapper that enables caching
│   └── git-status-fast.sh         # Git status caching implementation
├── claude-config/                  # Default Claude Code configuration
│   ├── CLAUDE.md                  # User instructions template
│   ├── settings.json              # Claude settings
│   ├── claude-powerline.json      # Powerline configuration
│   └── agents/                    # Specialized agent configurations
├── .documentation/                 # Upstream container tool documentation
│   └── container-main/            # Apple's container project docs (reference)
└── .original-files/               # Backup of original configurations
```

## Design Philosophy

This environment balances security and functionality:

- **Security**: Strict network allowlist prevents unauthorized data exfiltration
- **Functionality**: Allows all services required for Claude Code development
- **Transparency**: Clear firewall rules, verification, and error messages
- **Maintainability**: Centralized domain list, automated CIDR aggregation
- **Reproducibility**: Fully declarative container configuration

When adding features, prioritize:
1. Explicit allowlisting over broad access
2. Verification tests for new network access
3. Error messages that aid debugging
4. Documentation of security implications
- use the files from @.documentation/ for documentation source, never edit or write any files in there
- use the files in @.original-files/ as the initial project state, only use it for comparision with the changes that are made in the project. Never write or edit in this location
- keep in mind that this must work with Apple container and Docker
- try to simplify, goal is speed and performance, never overengineer things
- don't push changes to git without confirmation first!
