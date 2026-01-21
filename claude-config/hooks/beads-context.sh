#!/usr/bin/env bash
# ABOUTME: SessionStart hook that surfaces beads context to Claude
# ABOUTME: Shows in-progress work and ready issues for session awareness

set -euo pipefail

# Check if bd is available
if ! command -v bd &> /dev/null; then
    exit 0
fi

# Check if we're in a beads-enabled project
if [ ! -d ".beads" ]; then
    exit 0
fi

# Build context string
CONTEXT=""

# Get in-progress issues (current work)
IN_PROGRESS=$(bd list --status=in_progress 2>/dev/null || true)
if [ -n "$IN_PROGRESS" ] && ! echo "$IN_PROGRESS" | grep -q "No issues found"; then
    CONTEXT="${CONTEXT}## Current Work (in_progress)\n${IN_PROGRESS}\n\n"
fi

# Get ready issues (available work without blockers)
READY=$(bd ready 2>/dev/null || true)
if [ -n "$READY" ] && ! echo "$READY" | grep -q "No ready work found"; then
    CONTEXT="${CONTEXT}## Available Work (ready)\n${READY}\n\n"
fi

# Get blocked count for awareness
BLOCKED_OUTPUT=$(bd blocked 2>/dev/null || true)
BLOCKED_COUNT=$(echo "$BLOCKED_OUTPUT" | grep -c "^beads-" 2>/dev/null || echo "0")
BLOCKED_COUNT=${BLOCKED_COUNT:-0}
if [ "$BLOCKED_COUNT" -gt 0 ] 2>/dev/null; then
    CONTEXT="${CONTEXT}Note: ${BLOCKED_COUNT} issues are blocked by dependencies.\n"
fi

# Only output if we have context to share
if [ -n "$CONTEXT" ]; then
    # Escape for JSON
    CONTEXT_ESCAPED=$(echo -e "$CONTEXT" | jq -Rs .)
    echo "{\"additionalContext\": ${CONTEXT_ESCAPED}}"
fi

exit 0
