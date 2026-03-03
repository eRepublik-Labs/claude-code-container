# ABOUTME: Alpine Linux container with native Claude Code installation
# ABOUTME: Minimal, fast container using musl libc and native Claude binary

FROM alpine:3.22

# Build arguments
ARG TZ
ARG CLAUDE_CODE_VERSION=latest
ARG CONTAINER_VERSION=dev
ARG RELEASE_NOTES=""

# Environment variables
ENV CONTAINER_VERSION="${CONTAINER_VERSION}"
ENV TZ="$TZ"
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV NODE_OPTIONS="--max-old-space-size=3072"
ENV GIT_OPTIONAL_LOCKS=0
ENV FORCE_COLOR=3
ENV TERM=xterm-256color
ENV COLORTERM=truecolor
# Critical for musl compatibility - use external ripgrep
ENV USE_BUILTIN_RIPGREP=0

# Labels (OCI image spec)
LABEL org.opencontainers.image.description="Secure, isolated container environment for Claude Code development with strict network firewall" \
      com.erepubliklabs.release-notes="${RELEASE_NOTES}"

# Install system packages
RUN apk add --no-cache \
  # Core utilities
  bash \
  curl \
  ca-certificates \
  shadow \
  procps \
  \
  # Claude Code native dependencies (musl-specific)
  libgcc \
  libstdc++ \
  ripgrep \
  gcompat \
  \
  # Development tools
  git \
  github-cli \
  jq \
  yq \
  fd \
  fzf \
  nano \
  tmux \
  openssh-client \
  \
  # Network and firewall
  iptables-legacy \
  iptables \
  ipset \
  iproute2 \
  bind-tools \
  \
  # Process management (Alpine's gosu alternative)
  su-exec && \
  # Pre-populate GitHub SSH host keys (system-wide, survives volume mounts)
  mkdir -p /etc/ssh && \
  ssh-keyscan -t ed25519,ecdsa,rsa github.com >> /etc/ssh/ssh_known_hosts 2>/dev/null && \
  # Configure iptables to use legacy backend (must be after package install)
  # Symlink both /sbin and /usr/sbin to ensure legacy is used regardless of PATH
  ln -sf /sbin/iptables-legacy /sbin/iptables && \
  ln -sf /sbin/ip6tables-legacy /sbin/ip6tables && \
  ln -sf /sbin/iptables-legacy-save /sbin/iptables-save && \
  ln -sf /sbin/iptables-legacy-restore /sbin/iptables-restore && \
  ln -sf /sbin/ip6tables-legacy-save /sbin/ip6tables-save && \
  ln -sf /sbin/ip6tables-legacy-restore /sbin/ip6tables-restore && \
  ln -sf /sbin/iptables-legacy /usr/sbin/iptables && \
  ln -sf /sbin/ip6tables-legacy /usr/sbin/ip6tables && \
  ln -sf /sbin/iptables-legacy-save /usr/sbin/iptables-save && \
  ln -sf /sbin/iptables-legacy-restore /usr/sbin/iptables-restore && \
  ln -sf /sbin/ip6tables-legacy-save /usr/sbin/ip6tables-save && \
  ln -sf /sbin/ip6tables-legacy-restore /usr/sbin/ip6tables-restore

# Install Node.js (Alpine 3.22 includes Node.js 22.x in main repository)
RUN apk add --no-cache \
  nodejs \
  npm

# Build posix_getdents shim for musl/glibc compatibility (anthropics/claude-code#29559)
# Claude Code v2.1.63+ references posix_getdents, a glibc-specific symbol absent from musl
COPY scripts/posix_getdents_fix.c /tmp/posix_getdents_fix.c
RUN apk add --no-cache --virtual .build-deps gcc musl-dev && \
    gcc -shared -fPIC -O2 -o /usr/local/lib/posix_getdents_fix.so /tmp/posix_getdents_fix.c && \
    apk del .build-deps && \
    rm /tmp/posix_getdents_fix.c
ENV LD_PRELOAD=/usr/local/lib/posix_getdents_fix.so

# Create dev user with specific UID/GID for volume compatibility
RUN addgroup -g 1000 dev && \
    adduser -u 1000 -G dev -s /bin/bash -D dev

# Create workspace and config directories
RUN mkdir -p /workspace /home/dev/.claude /home/dev/.claude/agents \
    /home/dev/.claude/commands /home/dev/.claude/hooks && \
    mkdir -p /home/dev/.local/bin && \
    chown -R dev:dev /workspace /home/dev

# Copy default Claude config templates to /opt (not affected by volume mounts)
RUN mkdir -p /opt/claude-templates
COPY claude-config/CLAUDE.md /opt/claude-templates/CLAUDE.md
COPY claude-config/settings.json /opt/claude-templates/settings.json
COPY claude-config/claude-powerline.json /opt/claude-templates/claude-powerline.json
COPY claude-config/commands/ /opt/claude-templates/commands/
COPY claude-config/hooks/ /opt/claude-templates/hooks/

# Copy default Claude config (can be overridden with runtime mount)
COPY --chown=dev:dev claude-config/CLAUDE.md /home/dev/.claude/CLAUDE.md
COPY --chown=dev:dev claude-config/settings.json /home/dev/.claude/
COPY --chown=dev:dev claude-config/claude-powerline.json /home/dev/.claude/
COPY --chown=dev:dev claude-config/commands/ /home/dev/.claude/commands/
COPY --chown=dev:dev claude-config/hooks/ /home/dev/.claude/hooks/
COPY --chown=dev:dev scripts/file-suggestion.sh /home/dev/.claude/file-suggestion.sh

# Make hook scripts, skill hooks, and file-suggestion executable
RUN chmod +x /opt/claude-templates/hooks/*.sh 2>/dev/null || true && \
    chmod +x /opt/claude-templates/hooks/*.py 2>/dev/null || true && \
    chmod +x /home/dev/.claude/hooks/*.sh 2>/dev/null || true && \
    chmod +x /home/dev/.claude/hooks/*.py 2>/dev/null || true && \
    chmod +x /home/dev/.claude/file-suggestion.sh 2>/dev/null || true

# Install Claude Code native binary as dev user
USER dev
WORKDIR /home/dev

# Install Claude Code using the official installer
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION} && \
    echo 'export PATH="$HOME/.local/bin:/usr/local/bin:$HOME/.npm-global/bin:$PATH"' >> /home/dev/.bashrc && \
    echo 'export PATH="$HOME/.local/bin:/usr/local/bin:$HOME/.npm-global/bin:$PATH"' >> /home/dev/.profile

# Note: Update notification is displayed in entrypoint.sh before starting Claude Code

# Copy Claude installation to template location (survives volume mounts)
USER root
RUN mkdir -p /opt/claude-installation && \
    cp -r /home/dev/.local /opt/claude-installation/ && \
    cp /home/dev/.claude.json /opt/claude-installation/.claude.json && \
    cp -r /home/dev/.claude/plugins /opt/claude-installation/ 2>/dev/null || true && \
    chmod -R 755 /opt/claude-installation/plugins 2>/dev/null || true

# Install npm global packages
ENV NPM_CONFIG_PREFIX=/home/dev/.npm-global
ENV PATH=/home/dev/.local/bin:/home/dev/.npm-global/bin:$PATH

# Create npm global directory and ensure proper ownership
RUN mkdir -p /home/dev/.npm-global && \
    chown -R dev:dev /home/dev/.npm-global && \
    npm config set prefix /home/dev/.npm-global

# Switch to root temporarily for npm global installs to avoid permission issues
USER root
# Install npm packages from registry
RUN npm install -g --prefix /home/dev/.npm-global @owloops/claude-powerline && \
    chown -R dev:dev /home/dev/.npm-global

# Copy npm globals to template location
RUN cp -r /home/dev/.npm-global /opt/claude-installation/

# Already root, no need to switch

# Copy scripts and set permissions
COPY scripts/init-firewall.sh /usr/local/bin/
COPY scripts/entrypoint.sh /usr/local/bin/
COPY scripts/git-status-fast.sh /usr/local/bin/
COPY scripts/git-wrapper.sh /usr/local/bin/git-wrapper
COPY scripts/check-updates.sh /usr/local/bin/

# Make scripts executable (755 for shell scripts that need read access)
RUN chmod 755 /usr/local/bin/init-firewall.sh \
    /usr/local/bin/entrypoint.sh \
    /usr/local/bin/git-status-fast.sh \
    /usr/local/bin/git-wrapper \
    /usr/local/bin/check-updates.sh

# Replace system git with wrapper for automatic caching on large repos
# Move to .git-original (not git-* pattern) to avoid git builtin name parsing issues
RUN mv /usr/bin/git /usr/bin/.git-original && \
    ln -sf /usr/local/bin/git-wrapper /usr/bin/git

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
