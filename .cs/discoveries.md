# Discoveries & Notes

## 2026-02-18: Docker build & runtime verification

- Docker build succeeds cleanly on x86_64 (Docker Desktop, linux-kit kernel 6.12.67)
- Claude Code v2.1.45 installed via curl installer during build
- Firewall initializes in background on container start; network tests pass even while init log is still populating (GitHub ranges = 107 CIDRs)
- `example.com` correctly blocked; `api.github.com`, `registry.npmjs.org`, `api.anthropic.com` all reachable
- Settings merge and hook/plugin config load correctly from template
- Git wrapper symlink (`/usr/bin/git -> /usr/local/bin/git-wrapper`) in place
- Running without `-it` works for scripted tests (entrypoint handles non-TTY gracefully)

## 2026-02-18: Plugin clone failures (SSH missing)

- Container has no `openssh-client` — `ssh` binary not found
- Plugins from `hex-plugins` marketplace fail to clone because git defaults to SSH for `github.com` URLs
- Fix: `git config --global url."https://github.com/".insteadOf` rewrites both SSH URL formats (`git@github.com:` and `ssh://git@github.com/`) to HTTPS
- `git config` with same section key overwrites by default — need `--add` for the second `insteadOf` value
- `.gitconfig` must be backed up to `/opt/claude-templates/` and restored in entrypoint, otherwise volume mounts at `/home/dev` hide it

## 2026-02-18: Dead hook reference

- `settings.json` referenced `~/.claude/hooks/skill-activation-prompt.sh` in `UserPromptSubmit` hook
- Script doesn't exist in `claude-config/hooks/` — only `aboutme-validator.sh` is shipped
- Caused "UserPromptSubmit hook error" on every prompt in the container
- Fix: removed the hook entry from settings template
