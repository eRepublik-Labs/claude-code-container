#!/bin/bash
# ABOUTME: Fast git status wrapper that caches results to avoid slow VirtioFS operations
# ABOUTME: Returns cached status instantly, or timeout message while building cache in background

CACHE_FILE="/tmp/git-status-cache-$(pwd | md5sum | cut -d' ' -f1)"
CACHE_TIME_FILE="${CACHE_FILE}.time"
CACHE_MAX_AGE=300  # 5 minutes in seconds
TIMEOUT=5  # seconds to wait before giving up

current_time=$(date +%s)

# Check if cache exists and is fresh
if [ -f "$CACHE_FILE" ] && [ -f "$CACHE_TIME_FILE" ]; then
    cache_time=$(cat "$CACHE_TIME_FILE")
    age=$((current_time - cache_time))

    if [ $age -lt $CACHE_MAX_AGE ]; then
        # Cache is fresh, return it immediately
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Cache is stale or doesn't exist
LOCK_FILE="${CACHE_FILE}.lock"

# Check if there's already a background update running
if [ -f "$LOCK_FILE" ]; then
    # Update in progress
    if [ -f "$CACHE_FILE" ]; then
        # Return stale cache while update happens
        cat "$CACHE_FILE"
        exit 0
    else
        # No cache yet, wait up to TIMEOUT seconds
        for i in $(seq 1 $TIMEOUT); do
            sleep 1
            if [ -f "$CACHE_FILE" ]; then
                cat "$CACHE_FILE"
                exit 0
            fi
        done
        # Timeout - still no cache
        echo "Git status is taking too long (large repo on VirtioFS)"
        echo "Building cache in background... next call will be instant"
        echo ""
        echo "Hint: Run 'git status' again in a few minutes for cached results"
        exit 0
    fi
fi

# No cache and no update running - start background update
touch "$LOCK_FILE"

# Fork background process to update cache
(
    /usr/bin/.git-original status "$@" > "$CACHE_FILE.tmp" 2>&1
    mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    echo "$current_time" > "$CACHE_TIME_FILE"
    rm -f "$LOCK_FILE"
) >/dev/null 2>&1 &

# Wait up to TIMEOUT seconds for the cache to be ready
for i in $(seq 1 $TIMEOUT); do
    sleep 1
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
done

# Timeout - cache still building in background
echo "Git status is taking too long (large repo on VirtioFS)"
echo "Building cache in background... next call will be instant"
echo ""
echo "Hint: Run 'git status' again in a few minutes for cached results"
exit 0
