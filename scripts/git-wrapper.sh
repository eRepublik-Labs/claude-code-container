#!/bin/bash
# ABOUTME: Git wrapper that uses fast cached status for large repos
# ABOUTME: Automatically detects repos >30k files and uses caching

if [ "$1" = "status" ]; then
    # Check if we're in a git repo
    if ! /usr/bin/.git-original rev-parse --git-dir >/dev/null 2>&1; then
        /usr/bin/.git-original "$@"
        exit $?
    fi

    # Count tracked files (with timeout to avoid hanging on first check)
    FILE_COUNT=$(timeout 0.5s /usr/bin/.git-original ls-files 2>/dev/null | wc -l)

    # If timeout or count > 30000, use cache. Otherwise use normal git.
    if [ -z "$FILE_COUNT" ] || [ "$FILE_COUNT" -gt 30000 ]; then
        shift
        /usr/local/bin/git-status-fast.sh "$@"
    else
        /usr/bin/.git-original status "$@"
    fi
else
    /usr/bin/.git-original "$@"
fi
