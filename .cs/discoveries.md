# Discoveries & Notes

## 2026-02-18: Docker build & runtime verification

- Docker build succeeds cleanly on x86_64 (Docker Desktop, linux-kit kernel 6.12.67)
- Claude Code v2.1.45 installed via curl installer during build
- Firewall initializes in background on container start; network tests pass even while init log is still populating (GitHub ranges = 107 CIDRs)
- `example.com` correctly blocked; `api.github.com`, `registry.npmjs.org`, `api.anthropic.com` all reachable
- Settings merge and hook/plugin config load correctly from template
- Git wrapper symlink (`/usr/bin/git -> /usr/local/bin/git-wrapper`) in place
- Running without `-it` works for scripted tests (entrypoint handles non-TTY gracefully)
