#!/usr/bin/env bash
# ABOUTME: PostToolUse hook that validates ABOUTME headers on code files
# ABOUTME: Warns when new code files lack the required 2-line header

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

# Only process Write tool
if [ "$TOOL_NAME" != "Write" ]; then
    exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Get file extension
FILENAME=$(basename "$FILE_PATH")
EXTENSION="${FILENAME##*.}"

# Define code file extensions that require ABOUTME headers
CODE_EXTENSIONS=(
    "sh" "bash" "zsh"
    "py"
    "js" "ts" "jsx" "tsx" "mjs" "cjs"
    "swift"
    "go"
    "rs"
    "rb"
    "java" "kt" "kts"
    "c" "cpp" "cc" "h" "hpp"
    "cs"
)

# Check if this is a code file
IS_CODE_FILE=0
for ext in "${CODE_EXTENSIONS[@]}"; do
    if [ "$EXTENSION" = "$ext" ]; then
        IS_CODE_FILE=1
        break
    fi
done

# Skip non-code files
if [ $IS_CODE_FILE -eq 0 ]; then
    exit 0
fi

# Skip test files (they don't need ABOUTME)
if [[ "$FILENAME" == *"test"* ]] || [[ "$FILENAME" == *"Test"* ]] || [[ "$FILENAME" == *"spec"* ]] || [[ "$FILENAME" == *"Spec"* ]]; then
    exit 0
fi

# Skip generated files
if [[ "$FILE_PATH" == *"/generated/"* ]] || [[ "$FILE_PATH" == *"/build/"* ]] || [[ "$FILE_PATH" == *"/dist/"* ]]; then
    exit 0
fi

# Check if file exists and has content
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# Read first four lines (to handle shebang + ABOUTME lines)
FIRST_LINES=$(head -4 "$FILE_PATH" 2>/dev/null || true)

# Check for ABOUTME pattern (handles both // and # comment styles)
if ! echo "$FIRST_LINES" | grep -q "ABOUTME:"; then
    # Output warning as additional context
    jq -n --arg file "$FILE_PATH" '{
        "additionalContext": ("⚠️ ABOUTME HEADER MISSING: " + $file + "\nCode files must start with a 2-line ABOUTME header. Example:\n// ABOUTME: Brief description of what this file does\n// ABOUTME: Additional context about its purpose")
    }'
    exit 0
fi

# Count ABOUTME lines (should be 2)
ABOUTME_COUNT=$(echo "$FIRST_LINES" | grep -c "ABOUTME:" || echo "0")
ABOUTME_COUNT=${ABOUTME_COUNT:-0}
if [ "$ABOUTME_COUNT" -lt 2 ]; then
    jq -n --arg file "$FILE_PATH" --arg count "$ABOUTME_COUNT" '{
        "additionalContext": ("⚠️ INCOMPLETE ABOUTME HEADER: " + $file + "\nExpected 2 ABOUTME lines, found " + $count + ". Each code file needs 2 ABOUTME lines.")
    }'
fi

exit 0
