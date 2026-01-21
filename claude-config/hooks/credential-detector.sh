#!/usr/bin/env bash
# ABOUTME: PostToolUse hook that detects potential credential exposure in written files
# ABOUTME: Scans for API keys, tokens, passwords, and secrets using common patterns

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

# Process Write, Edit, MultiEdit tools
case "$TOOL_NAME" in
    Write|Edit|MultiEdit) ;;
    *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Skip known safe directories and files
case "$FILE_PATH" in
    */.git/*) exit 0 ;;
    */.env.example) exit 0 ;;
    */.env.template) exit 0 ;;
    */node_modules/*) exit 0 ;;
    */package-lock.json) exit 0 ;;
    */yarn.lock) exit 0 ;;
    */Podfile.lock) exit 0 ;;
esac

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Patterns that suggest credential exposure
# Using ripgrep for better pattern matching
WARNINGS=""

# AWS Access Key pattern
if rg -q 'AKIA[0-9A-Z]{16}' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}AWS Access Key ID detected\n"
fi

# Generic API key patterns (key=value with long alphanumeric value)
if rg -qi '(api[_-]?key|apikey)\s*[=:]\s*["\x27]?[A-Za-z0-9+/=_-]{20,}' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}Potential API key detected\n"
fi

# Secret/token patterns
if rg -qi '(secret|token|password|credential)\s*[=:]\s*["\x27][^"\x27]{8,}' "$FILE_PATH" 2>/dev/null; then
    # Exclude common false positives
    if ! rg -q '(process\.env|os\.environ|\$\{|getenv|ENV\[)' "$FILE_PATH" 2>/dev/null; then
        WARNINGS="${WARNINGS}Potential secret/token/password detected\n"
    fi
fi

# Private key markers
if rg -q 'PRIVATE KEY-----' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}Private key detected\n"
fi

# GitHub/GitLab tokens
if rg -q '(ghp_|gho_|ghu_|ghs_|ghr_|glpat-)[A-Za-z0-9]{20,}' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}GitHub/GitLab token detected\n"
fi

# Slack tokens
if rg -q 'xox[baprs]-[0-9]{10,}' "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}Slack token detected\n"
fi

# If warnings found, output context
if [ -n "$WARNINGS" ]; then
    jq -n --arg file "$FILE_PATH" --arg warnings "$WARNINGS" '{
        "additionalContext": ("🚨 POTENTIAL CREDENTIAL EXPOSURE in " + $file + ":\n" + $warnings + "\nPlease review and ensure no secrets are being committed. Use environment variables instead.")
    }'
fi

exit 0
