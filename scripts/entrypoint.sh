#!/bin/bash
# ABOUTME: Container entrypoint that configures authentication, permissions, and firewall
# ABOUTME: Uses su-exec for process management (Alpine Linux compatible)

set -e

# Timing instrumentation (enable with ENTRYPOINT_TIMING=1)
if [ "$ENTRYPOINT_TIMING" = "1" ]; then
  # Get time in milliseconds using /proc/uptime (Linux) or date (macOS)
  _get_ms() {
    if [ -f /proc/uptime ]; then
      # Linux: read uptime with centisecond precision, convert to ms
      awk '{printf "%.0f", $1 * 1000}' /proc/uptime
    else
      # macOS fallback: use perl for milliseconds
      perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000' 2>/dev/null || echo $(($(date +%s)*1000))
    fi
  }
  TIMING_START=$(_get_ms)
  _timer_start() { SECTION_START=$(_get_ms); }
  _timer_end() {
    local now=$(_get_ms)
    local elapsed=$((now - SECTION_START))
    printf "\033[38;2;86;95;137m  ⏱  %-35s %4dms\033[0m\n" "$1" "$elapsed"
  }
else
  _timer_start() { :; }
  _timer_end() { :; }
fi

# Ensure /home/dev directories have correct ownership for volumes
# This fixes permissions for Claude, gh CLI, and other user config
_timer_start
mkdir -p /home/dev/.claude /home/dev/.config /home/dev/.cache
chown -R dev:dev /home/dev 2>/dev/null || true
_timer_end "Directory setup + chown"

# Restore Claude installation if volume mount hid it
_timer_start
if [ ! -d /home/dev/.local/share/claude ]; then
  echo "Restoring Claude Code installation from template..."
  cp -r /opt/claude-installation/.local /home/dev/
  chown -R dev:dev /home/dev/.local
fi
_timer_end "Claude installation restore"

# Restore npm global packages if volume mount hid them
_timer_start
if [ ! -d /home/dev/.npm-global ]; then
  echo "Restoring npm global packages from template..."
  cp -r /opt/claude-installation/.npm-global /home/dev/
  chown -R dev:dev /home/dev/.npm-global
else
  # Sync claude-powerline if template version is newer
  TEMPLATE_VER=$(cat /opt/claude-installation/.npm-global/lib/node_modules/@owloops/claude-powerline/package.json 2>/dev/null | jq -r '.version' 2>/dev/null || echo "0.0.0")
  CURRENT_VER=$(cat /home/dev/.npm-global/lib/node_modules/@owloops/claude-powerline/package.json 2>/dev/null | jq -r '.version' 2>/dev/null || echo "0.0.0")
  if [ "$TEMPLATE_VER" != "$CURRENT_VER" ]; then
    echo "Updating claude-powerline: $CURRENT_VER -> $TEMPLATE_VER"
    rm -rf /home/dev/.npm-global/lib/node_modules/@owloops/claude-powerline
    mkdir -p /home/dev/.npm-global/lib/node_modules/@owloops
    cp -r /opt/claude-installation/.npm-global/lib/node_modules/@owloops/claude-powerline /home/dev/.npm-global/lib/node_modules/@owloops/
    chown -R dev:dev /home/dev/.npm-global/lib/node_modules/@owloops/claude-powerline
  fi
fi
_timer_end "npm-global restore + version check"

# Restore .claude.json if volume mount hid it
_timer_start
if [ ! -f /home/dev/.claude.json ]; then
  echo "Restoring .claude.json from template..."
  cp /opt/claude-installation/.claude.json /home/dev/.claude.json
  chown dev:dev /home/dev/.claude.json
fi
_timer_end ".claude.json restore"

# Restore plugins if volume mount hid them
_timer_start
if [ -d /opt/claude-installation/plugins ] && [ ! -d /home/dev/.claude/plugins ]; then
  echo "Restoring plugins from template..."
  mkdir -p /home/dev/.claude
  cp -r /opt/claude-installation/plugins /home/dev/.claude/
  chown -R dev:dev /home/dev/.claude/plugins
fi
_timer_end "Plugins restore"

# Restore .gitconfig if volume mount hid it (HTTPS rewrite for GitHub)
_timer_start
if [ ! -f /home/dev/.gitconfig ]; then
  cp /opt/claude-templates/.gitconfig /home/dev/.gitconfig
  chown dev:dev /home/dev/.gitconfig
fi
_timer_end ".gitconfig restore"

# Ensure .bashrc exists with correct PATH
_timer_start
if [ ! -f /home/dev/.bashrc ]; then
  # Create .bashrc with PATH setup
  cat > /home/dev/.bashrc << 'EOF'
# PATH setup (put /usr/local/bin before npm-global for wrappers)
export PATH="$HOME/.local/bin:/usr/local/bin:$HOME/.npm-global/bin:$PATH"
EOF
  chown dev:dev /home/dev/.bashrc
fi
_timer_end ".bashrc setup"

# Copy template settings (always overwrite to ensure consistency)
_timer_start
mkdir -p /home/dev/.claude
cp /opt/claude-templates/settings.json /home/dev/.claude/settings.json
chown dev:dev /home/dev/.claude/settings.json

# Always overwrite powerline config to ensure new segments are available
cp /opt/claude-templates/claude-powerline.json /home/dev/.claude/claude-powerline.json
chown dev:dev /home/dev/.claude/claude-powerline.json
_timer_end "Settings + powerline config"

_timer_start
if [ ! -d /home/dev/.claude/commands ]; then
  mkdir -p /home/dev/.claude
  cp -r /opt/claude-templates/commands /home/dev/.claude/
  chown -R dev:dev /home/dev/.claude/commands
fi
_timer_end "Commands copy"

# Always sync hooks from templates (merge new hooks without overwriting existing)
_timer_start
mkdir -p /home/dev/.claude/hooks
cp -n /opt/claude-templates/hooks/* /home/dev/.claude/hooks/ 2>/dev/null || true
chown -R dev:dev /home/dev/.claude/hooks
chmod +x /home/dev/.claude/hooks/*.sh 2>/dev/null || true
_timer_end "Hooks sync"

# Merge our preferred settings into .claude.json (file should exist from restore above)
_timer_start
if [ -f /home/dev/.claude.json ]; then
  jq '. + {"hasTrustDialogHooksAccepted": true, "hasTrustDialogAccepted": true, "hasCompletedOnboarding": true, "bypassPermissionsModeAccepted": true, "theme": "dark", "installMethod": "native", "autoCompactEnabled": false}' \
    /home/dev/.claude.json > /home/dev/.claude.json.tmp && \
  mv /home/dev/.claude.json.tmp /home/dev/.claude.json
  chown dev:dev /home/dev/.claude.json
fi
_timer_end ".claude.json jq merge"

# Copy CLAUDE.md if not present
_timer_start
if [ ! -f /home/dev/.claude/CLAUDE.md ] && [ -f /opt/claude-templates/CLAUDE.md ]; then
  mkdir -p /home/dev/.claude
  cp /opt/claude-templates/CLAUDE.md /home/dev/.claude/CLAUDE.md
  chown dev:dev /home/dev/.claude/CLAUDE.md
fi
_timer_end "CLAUDE.md copy"

# Securely store CLAUDE_API_KEY in file and remove from environment
_timer_start
if [ -n "$CLAUDE_API_KEY" ]; then
  mkdir -p /home/dev/.claude
  API_KEY_FILE="/home/dev/.claude/.api-key"

  # Write API key to secure file (no trailing newline)
  printf '%s' "$CLAUDE_API_KEY" > "$API_KEY_FILE"
  chown dev:dev "$API_KEY_FILE"
  chmod 600 "$API_KEY_FILE"

  # Inject apiKeyHelper into settings.json to use API key
  SETTINGS_FILE="/home/dev/.claude/settings.json"
  if [ -f "$SETTINGS_FILE" ]; then
    # Create temporary settings with apiKeyHelper (strip whitespace for safety)
    jq '. + {"apiKeyHelper": "cat /home/dev/.claude/.api-key 2>/dev/null | tr -d \"\\n\\r\\t \" || echo $CLAUDE_API_KEY"}' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    chown dev:dev "$SETTINGS_FILE"
  fi

  # Remove API key from environment for security
  unset CLAUDE_API_KEY
fi
_timer_end "API key setup"

# Print total time if timing enabled
if [ "$ENTRYPOINT_TIMING" = "1" ]; then
  TIMING_END=$(_get_ms)
  TOTAL_MS=$((TIMING_END - TIMING_START))
  printf "\033[38;2;122;162;247m  ⏱  %-35s %4dms\033[0m\n" "TOTAL ENTRYPOINT TIME" "$TOTAL_MS"
fi

# Initialize firewall in background
# Tokyo Night colors
ORANGE='\033[38;2;255;158;100m'  # #ff9e64
BLUE='\033[38;2;122;162;247m'    # #7aa2f7
DARK='\033[38;2;86;95;137m'      # #565f89
RESET='\033[0m'

echo -e "${ORANGE}🛡️  Starting firewall initialization...${RESET}"
(
  export PATH="/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
  /usr/local/bin/init-firewall.sh > /tmp/firewall-init.log 2>&1
  if [ $? -eq 0 ]; then
    echo "Firewall initialized successfully" > /tmp/firewall-status
  else
    echo "Firewall initialization failed" > /tmp/firewall-status
  fi
) &
echo -e "${DARK}    ↳ Initializing in background. Check ${BLUE}cat /tmp/firewall-status${DARK} for progress.${RESET}"

# Display container version
if [ -n "$CONTAINER_VERSION" ] && [ "$CONTAINER_VERSION" != "dev" ]; then
  echo -e "${BLUE}📦 Container version: ${ORANGE}${CONTAINER_VERSION}${RESET}"
fi

# Check for container updates (injects companyAnnouncements into settings.json)
# Run synchronously so notification appears before Claude Code starts
if [ -x /usr/local/bin/check-updates.sh ]; then
  timeout 3 /usr/local/bin/check-updates.sh >/dev/null 2>&1 || true
fi

# Set PATH to include git wrapper and Claude binary
# Put /usr/local/bin before npm-global so wrappers take precedence
export PATH="/home/dev/.local/bin:/usr/local/bin:/home/dev/.npm-global/bin:$PATH"
export CLAUDE_PROJECT_DIR=/workspace
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Set task list ID from container name for persistent task tracking across sessions
# Uses CONTAINER_NAME if explicitly set, otherwise falls back to HOSTNAME
export CLAUDE_CODE_TASK_LIST_ID="${CONTAINER_NAME:-$HOSTNAME}"

# If running as root, drop to dev user using su-exec (Alpine's gosu alternative)
if [ "$(id -u)" = "0" ]; then
  cd /workspace
  export HOME=/home/dev
  # Unset CLAUDE_API_KEY for the dev user environment
  unset CLAUDE_API_KEY
  if [ $# -eq 0 ]; then
    exec su-exec dev env -u CLAUDE_API_KEY PATH="/home/dev/.local/bin:/usr/local/bin:/home/dev/.npm-global/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin" CLAUDE_PROJECT_DIR=/workspace CLAUDE_CODE_TASK_LIST_ID="$CLAUDE_CODE_TASK_LIST_ID" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 HOME=/home/dev /bin/bash
  else
    exec su-exec dev env -u CLAUDE_API_KEY PATH="/home/dev/.local/bin:/usr/local/bin:/home/dev/.npm-global/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin" CLAUDE_PROJECT_DIR=/workspace CLAUDE_CODE_TASK_LIST_ID="$CLAUDE_CODE_TASK_LIST_ID" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 HOME=/home/dev "$@"
  fi
else
  # Already dev user, just execute
  cd /workspace
  export PATH="/home/dev/.local/bin:/usr/local/bin:/home/dev/.npm-global/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
  # Unset CLAUDE_API_KEY for current environment
  unset CLAUDE_API_KEY
  if [ $# -eq 0 ]; then
    exec env -u CLAUDE_API_KEY PATH="/home/dev/.local/bin:/usr/local/bin:/home/dev/.npm-global/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin" CLAUDE_PROJECT_DIR=/workspace CLAUDE_CODE_TASK_LIST_ID="$CLAUDE_CODE_TASK_LIST_ID" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 HOME=/home/dev /bin/bash
  else
    exec env -u CLAUDE_API_KEY PATH="/home/dev/.local/bin:/usr/local/bin:/home/dev/.npm-global/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin" CLAUDE_PROJECT_DIR=/workspace CLAUDE_CODE_TASK_LIST_ID="$CLAUDE_CODE_TASK_LIST_ID" CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 HOME=/home/dev "$@"
  fi
fi