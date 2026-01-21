#!/bin/bash
# ABOUTME: Checks GHCR for container updates and injects notifications
# ABOUTME: Runs in background to avoid blocking container startup

set -euo pipefail

# Allow users to disable update checks
if [ "${SKIP_UPDATE_CHECK:-0}" = "1" ]; then
    exit 0
fi

# Configuration
GHCR_REPO="erepublik-labs/claude-code-container"
GHCR_TOKEN_URL="https://ghcr.io/token?scope=repository:${GHCR_REPO}:pull"
GHCR_TAGS_URL="https://ghcr.io/v2/${GHCR_REPO}/tags/list"
TIMEOUT=5

# Get current container version from environment
CURRENT_VERSION="${CONTAINER_VERSION:-unknown}"

# Skip check if version is unknown or dev
if [ "$CURRENT_VERSION" = "unknown" ] || [ "$CURRENT_VERSION" = "dev" ]; then
    exit 0
fi

# Get anonymous token from GHCR
TOKEN=$(curl -sf --max-time "$TIMEOUT" "$GHCR_TOKEN_URL" | jq -r '.token' 2>/dev/null || echo "")
if [ -z "$TOKEN" ]; then
    exit 0
fi

# Query GHCR for available tags
TAGS_JSON=$(curl -sf --max-time "$TIMEOUT" -H "Authorization: Bearer $TOKEN" "$GHCR_TAGS_URL" 2>/dev/null || echo "")
if [ -z "$TAGS_JSON" ]; then
    exit 0
fi

# Extract latest CalVer tag (YYYY.MM.PATCH format), excluding "latest" tag
# Sort tags in reverse order and get the first CalVer match
LATEST_VERSION=$(echo "$TAGS_JSON" | jq -r '.tags[]' | grep -E '^20[0-9]{2}\.[0-9]{1,2}\.[0-9]+$' | sort -V -r | head -n 1 || echo "")

# If no valid version found, silently exit
if [ -z "$LATEST_VERSION" ]; then
    exit 0
fi

# Compare versions (lexicographic comparison works for CalVer YYYY.MM.PATCH)
SETTINGS_FILE="/home/dev/.claude/settings.json"

if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ] && [[ "$LATEST_VERSION" > "$CURRENT_VERSION" ]]; then
    # Update available - fetch release notes and inject notification
    CHANGELOG=""

    # Fetch release notes from image manifest labels (OCI annotations break Docker buildx)
    # Multi-arch images have an index, get first platform's manifest
    INDEX_URL="https://ghcr.io/v2/${GHCR_REPO}/manifests/${LATEST_VERSION}"
    INDEX=$(curl -sf --max-time "$TIMEOUT" -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.oci.image.index.v1+json" "$INDEX_URL" 2>/dev/null || echo "")

    if [ -n "$INDEX" ]; then
        # Get first platform manifest digest
        PLATFORM_DIGEST=$(echo "$INDEX" | jq -r '.manifests[0].digest // ""' 2>/dev/null || echo "")
        if [ -n "$PLATFORM_DIGEST" ]; then
            # Fetch platform-specific manifest
            MANIFEST_URL="https://ghcr.io/v2/${GHCR_REPO}/manifests/${PLATFORM_DIGEST}"
            MANIFEST=$(curl -sf --max-time "$TIMEOUT" -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.oci.image.manifest.v1+json" "$MANIFEST_URL" 2>/dev/null || echo "")

            if [ -n "$MANIFEST" ]; then
                # Extract config digest and fetch config blob to get labels
                CONFIG_DIGEST=$(echo "$MANIFEST" | jq -r '.config.digest // ""' 2>/dev/null || echo "")
                if [ -n "$CONFIG_DIGEST" ]; then
                    CONFIG_URL="https://ghcr.io/v2/${GHCR_REPO}/blobs/${CONFIG_DIGEST}"
                    CONFIG=$(curl -sfL --max-time "$TIMEOUT" -H "Authorization: Bearer $TOKEN" "$CONFIG_URL" 2>/dev/null || echo "")
                    if [ -n "$CONFIG" ]; then
                        CHANGELOG=$(echo "$CONFIG" | jq -r '.config.Labels["com.erepubliklabs.release-notes"] // ""' 2>/dev/null || echo "")
                    fi
                fi
            fi
        fi
    fi

    # Inject companyAnnouncements into Claude Code settings
    if [ -f "$SETTINGS_FILE" ]; then
        # Format announcement message
        if [ -n "$CHANGELOG" ]; then
            # Notes are space-separated from workflow, convert " - " to newlines
            FORMATTED_NOTES=$(echo "$CHANGELOG" | sed 's/ - /\n- /g')
            ANNOUNCEMENT="🔔 Container update available: ${CURRENT_VERSION} → ${LATEST_VERSION}
${FORMATTED_NOTES}"
        else
            ANNOUNCEMENT="🔔 Container update available: ${CURRENT_VERSION} → ${LATEST_VERSION}"
        fi

        # Inject companyAnnouncements into settings.json
        jq --arg msg "$ANNOUNCEMENT" '.companyAnnouncements = [$msg]' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" 2>/dev/null && \
            mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE" && \
            chown dev:dev "$SETTINGS_FILE" || \
            rm -f "${SETTINGS_FILE}.tmp"
    fi
else
    # No update available - clear any existing notifications
    if [ -f "$SETTINGS_FILE" ]; then
        jq 'del(.companyAnnouncements)' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" 2>/dev/null && \
            mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE" && \
            chown dev:dev "$SETTINGS_FILE" || \
            rm -f "${SETTINGS_FILE}.tmp"
    fi
fi

exit 0
