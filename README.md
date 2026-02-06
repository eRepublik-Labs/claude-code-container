# Claude Code Secure Container

Hardened container environment for Claude Code with strict network firewall controls.

## What This Is

A secure, isolated environment for running Claude Code with:
- **Strict Network Firewall**: Only pre-approved domains accessible (GitHub, npm, Anthropic API, claude.ai)
- **Zero Trust**: Default-deny policy with explicit service approval
- **Multi-Runtime**: Works with Docker and Apple's container tool
- **Ready to Use**: Pre-configured settings and optimized tools

## Quick Start (5 Minutes)

### 1. Install Container Runtime

**macOS with Apple Silicon**:
```bash
# Download from https://github.com/apple/container/releases
# Install package, then:
container system start
```

**Docker (all platforms)**:
```bash
brew install docker  # macOS
# or apt-get install docker.io  # Linux
```

### 2. Get the Image

**Pull from registry** (recommended):
```bash
# Docker (Linux/Windows/Mac)
docker pull ghcr.io/erepublik-labs/claude-code-container:latest

# Apple Container (Mac)
container image pull ghcr.io/erepublik-labs/claude-code-container:latest

# Image also downloads automatically on first 'run' if not present
```

**Or build locally**:
```bash
git clone https://github.com/eRepublik-Labs/claude-code-container.git
cd claude-code-container

# Mac: use 'container'
container build -t ghcr.io/erepublik-labs/claude-code-container:latest .

# Linux/Windows: use 'docker'
docker build -t ghcr.io/erepublik-labs/claude-code-container:latest .
```

> **Note**: This container uses Alpine Linux (~330MB) with native Claude Code binary for optimal size and performance.

### 3. Choose Authentication Method

**Option A: Subscription Login** (Claude Pro/Team/Max - easiest for daily use)

```bash
# Create persistent volume (stores Claude auth, GitHub CLI auth, shell history)
container volume create dev-home  # or: docker volume create dev-home

# Start container (Mac/Apple silicon)
container run -it --rm \
  -m 4G \
  -c 4 \
  -v dev-home:/home/dev \
  -v "$(pwd)":/workspace \
  ghcr.io/erepublik-labs/claude-code-container:latest

# Start container (Docker - add capabilities)
docker run -it --rm \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -m 4G \
  --cpus=4 \
  -v dev-home:/home/dev \
  -v "$(pwd)":/workspace \
  ghcr.io/erepublik-labs/claude-code-container:latest

# First time: Claude Code will prompt you to login
# Follow the prompts to authenticate with your subscription
# All credentials and history persist in the dev-home volume
```

**Option B: API Key** (for automation, print mode, CI/CD)

```bash
# Get API key from https://console.anthropic.com

# Mac/Apple silicon
container run -it --rm \
  -m 4G \
  -c 4 \
  -v "$(pwd)":/workspace \
  -e CLAUDE_API_KEY="sk-ant-api03-..." \
  ghcr.io/erepublik-labs/claude-code-container:latest

# Docker (add capabilities)
docker run -it --rm \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  -m 4G \
  --cpus=4 \
  -v "$(pwd)":/workspace \
  -e CLAUDE_API_KEY="sk-ant-api03-..." \
  ghcr.io/erepublik-labs/claude-code-container:latest
```

> **Note**: Docker requires `--cap-add=NET_ADMIN` and `--cap-add=NET_RAW` for iptables firewall. Apple Container doesn't need these flags (capabilities available by default). Apple Container automatically builds ARM64 images on Apple Silicon.

## Helper Functions (Recommended)

Add to your `~/.zshrc` or `~/.bashrc` for convenient container management. These helpers simplify daily usage significantly.

**For Apple Container (Mac):**

```bash
# Update to latest image
ccupdate() {
  container system start
  container image pull ghcr.io/erepublik-labs/claude-code-container:latest
}

# Start container in current directory (with persistent volume)
cc() {
  container system start
  container run -it --rm \
    --name claude-$(basename "$PWD") \
    -m 4G \
    -c 4 \
    -v claude-home:/home/dev \
    -v "$PWD:/workspace" \
    -w /workspace \
      ghcr.io/erepublik-labs/claude-code-container:latest
}

# Or for API key auth (no persistence)
cc() {
  container system start
  container run -it --rm \
    --name claude-$(basename "$PWD") \
    -m 4G \
    -c 4 \
    -v "$PWD:/workspace" \
    -w /workspace \
    -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
      ghcr.io/erepublik-labs/claude-code-container:latest
}
```

**For Docker:**

```bash
# Update to latest image
ccupdate() {
  docker pull ghcr.io/erepublik-labs/claude-code-container:latest
}

# Start container in current directory (with persistent volume)
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
      ghcr.io/erepublik-labs/claude-code-container:latest
}

# Or for API key auth (no persistence)
cc() {
  docker run -it --rm \
    --name claude-$(basename "$PWD") \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    -m 4G \
    --cpus=4 \
    -v "$PWD:/workspace" \
    -w /workspace \
    -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
      ghcr.io/erepublik-labs/claude-code-container:latest
}
```

**For Windows (PowerShell 7+):**

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
# Update to latest image
Function ccupdate {
  docker pull ghcr.io/erepublik-labs/claude-code-container:latest
}

# Start container in current directory (with persistent volume)
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
    ghcr.io/erepublik-labs/claude-code-container:latest
}
```

**Usage:**
- `cc` - Start container in current directory
- `ccupdate` - Pull latest image

**What persists with `claude-home` volume:**
- Claude authentication (OAuth or API key)
- GitHub CLI authentication (`gh auth login`)
- Conversation history
- Shell command history
- All user configuration

## Image Versions

This project uses **CalVer** (Calendar Versioning) with format: `YYYY.M.PATCH`

**Available tags:**
- `latest` - Most recent release (auto-updated)
- `2026.2.0` - Specific CalVer release

**Examples:**
```bash
# Docker - pull specific version
docker pull ghcr.io/erepublik-labs/claude-code-container:latest
docker pull ghcr.io/erepublik-labs/claude-code-container:2026.2.0

# Apple Container - pull specific version
container image pull ghcr.io/erepublik-labs/claude-code-container:latest
container image pull ghcr.io/erepublik-labs/claude-code-container:2026.2.0
```

See [releases](https://github.com/eRepublik-Labs/claude-code-container/releases) for version history.

## Update Notifications

The container automatically checks for new versions and displays notifications when updates are available.

**To disable:**
```bash
# Add to container run command
-e SKIP_UPDATE_CHECK=1
```

## Documentation

- **[Authentication Guide](docs/authentication.md)** - Detailed setup for OAuth and API key methods
- **[Memory & Persistence](docs/memory-and-persistence.md)** - How Claude remembers across sessions
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[CLAUDE.md](CLAUDE.md)** - Technical implementation details and architecture

## Security

### Supply Chain Security

Every release includes:

**Vulnerability Scanning**
- **Trivy** - Blocks releases on CRITICAL/HIGH CVEs

**Software Bill of Materials (SBOM)**
- Complete package inventory in SPDX format (generated by Syft)
- Includes Alpine packages and npm dependencies
- Available in workflow artifacts (90-day retention)

**Accessing Security Reports**
1. Navigate to [Actions page](../../actions)
2. Click on the release workflow run
3. Download `security-reports-<version>` artifact
4. Contains: Trivy scan results and SBOM

For detailed security information, see [SECURITY.md](SECURITY.md).

### Network Security
- **Allowlist-based firewall** using iptables-legacy blocks all non-approved domains
- **Permitted services**: GitHub, npm, Anthropic API, claude.ai, Statsig, GHCR, Google Cloud Storage, local network
- **Built-in verification** tests ensure firewall policies are enforced
- **Works on both Docker and Apple Container** with proper configuration
- **Test verified**: Blocks Facebook, Google, Twitter, and all other non-allowlisted domains

### Container Security
- Alpine Linux base for minimal attack surface (~330MB)
- Build dependencies removed after use
- API keys secured in files (chmod 600), never in environment
- No cached layers during build

### Command Safety Guard
A PreToolUse hook (`git-safety-guard.py`) automatically blocks destructive commands before execution:
- **Git data loss**: `git checkout --`, `git restore`, `git reset --hard`, `git clean -f`
- **Force operations**: `git push --force` (allows `--force-with-lease`), `git branch -D`
- **Filesystem**: `rm -rf` (except `/tmp`, `/var/tmp`, `$TMPDIR`)
- **Stash destruction**: `git stash drop`, `git stash clear`

**Dependencies**: Python 3 (installed via Alpine packages)

Safe operations like creating branches, unstaging files, and dry runs are allowed.

## Key Features

### File Suggestion

Custom file picker that follows symlinks and respects `.gitignore`:
- Uses `rg --files --follow --hidden` for file discovery
- Fuzzy filtering via `fzf`
- Returns up to 15 results per query

### Performance

**Git Status Caching** for large repositories (>30k files):
- Automatically detects large repos and caches git status results
- First call: Shows "Building cache in background" message (~2 minutes to build)
- Subsequent calls: ~0.06s (instant)
- Cache refreshes every 5 minutes in background
- Works transparently - all git commands use the wrapper automatically

### Memory & Persistence

Claude Code has multiple memory systems. Using a single volume (`-v dev-home:/home/dev`) persists all user-level state:

**What persists with `dev-home` volume:**
- ✅ **Claude Code installation** - Binary and updates
- ✅ **npm global packages** - claude-powerline
- ✅ **Conversation history** - All your past conversations
- ✅ **User memory** (`~/.claude/CLAUDE.md`) - Your personal preferences
- ✅ **File edit history** - Undo/redo across sessions
- ✅ **Claude authentication** - OAuth credentials or API key
- ✅ **GitHub CLI auth** (`gh auth login`) - Git credentials
- ✅ **Shell history** - Command history across sessions
- ✅ **Settings and configuration** - All user preferences

**First-time volume setup:**
On first run with a fresh volume, the container automatically restores:
- Claude Code installation from `/opt/claude-installation/` (~3 seconds, one-time)
- npm global packages (claude-powerline)
- Default configuration templates

Subsequent runs skip restoration (instant startup).

**Auto-updates with persistent volumes:**
The container automatically syncs certain files on every startup to ensure you get new features:
- ✅ `settings.json` - Always synced from template
- ✅ `claude-powerline.json` - Always synced from template
- ✅ `claude-powerline` npm package - Auto-updated when template version is newer
- ✅ Hook scripts - New hooks merged without overwriting customizations

This means container updates automatically bring new status line features, settings, and hooks without losing your authentication or conversation history.

**First-time setup:**
```bash
# Start container (automatically launches Claude Code and prompts for OAuth login)
cc

# After authenticating, run GitHub CLI setup:
!gh auth login   # Use ! prefix to run shell commands in Claude Code
```

See [Memory & Persistence Guide](docs/memory-and-persistence.md) for complete details on memory hierarchy, best practices, and advanced usage.

## Configuration

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `CLAUDE_API_KEY` | API key for API key authentication | No* | - |
| `CONTAINER_NAME` | Custom name for task list persistence | No | Container hostname |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Enable multi-agent teams (research preview) | No | `1` |
| `NODE_OPTIONS` | Node.js memory limit | No | `--max-old-space-size=3072` |

*Required for API key authentication, optional for OAuth subscription

**Task List Persistence**: The container sets `CLAUDE_CODE_TASK_LIST_ID` to the container name (from `CONTAINER_NAME` or hostname). This allows Claude Code's task list to persist across sessions when using the same container name. The helper functions above use `--name claude-$(basename "$PWD")` to automatically name containers by project directory.

### Memory Configuration

Default: 4GB container, 3GB Node.js heap

To increase:
```bash
# 8GB container example (Apple Container)
container run -m 8G -c 8 -e NODE_OPTIONS="--max-old-space-size=6144" ...

# 8GB container example (Docker)
docker run -m 8G --cpus=8 -e NODE_OPTIONS="--max-old-space-size=6144" ...
```

### Adding Domains to Firewall

To allow additional domains:

1. Edit `scripts/init-firewall.sh`
2. Add domain to the allowlist (around line 67-75)
3. Rebuild container: `container build -t ghcr.io/erepublik-labs/claude-code-container:latest .`

Example:
```bash
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "your-domain.com"; do  # Add here
```

## Common Issues

**Firewall initialization failed**
- Check `/tmp/firewall-init.log` inside container
- GitHub API rate limiting: wait 60 minutes

**Permission denied errors**
- Automatically fixed by entrypoint
- If persists: recreate volume

**Out of memory**
- Increase container memory with `-m` flag
- Adjust Node heap with `NODE_OPTIONS`

See [detailed troubleshooting guide](docs/troubleshooting.md) for more issues and solutions.

## Contributing

Contributions welcome! Please:
1. Read [CLAUDE.md](CLAUDE.md) for technical details
2. Test changes with both Docker and Apple Container
3. Update documentation for user-facing changes
4. Follow the existing code style

### Creating Releases

This project uses CalVer versioning: `YYYY.M.PATCH`

**IMPORTANT: Tags must NOT include a `v` prefix or leading zeros in the month.**

```bash
# Create release (NO 'v' prefix, NO leading zero on month!)
gh release create 2026.2.0 \
  --title "2026.2.0" \
  --notes "Release notes"
```

**Correct format:** `2026.2.0`, `2026.12.1`
**Wrong format:** ~~`v2026.1.6`~~, ~~`2026.01.6`~~

The CI/CD workflow triggers on tags matching patterns `20[0-9][0-9].[1-9].*` and `20[0-9][0-9].1[0-2].*`

## Support

- **Issues**: [GitHub Issues](https://github.com/eRepublik-Labs/claude-code-container/issues)
- **Discussions**: [GitHub Discussions](https://github.com/eRepublik-Labs/claude-code-container/discussions)

## License

MIT License - see [LICENSE](LICENSE) for details
