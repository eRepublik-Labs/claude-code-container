#!/usr/bin/env python3
# ABOUTME: PreToolUse hook that blocks destructive git and filesystem commands
# ABOUTME: Prevents accidental data loss from rm -rf, git reset --hard, git push --force, etc.
"""
Git/filesystem safety guard for Claude Code.

Blocks destructive commands that can lose uncommitted work or delete files.
This hook runs before Bash commands execute and can deny dangerous operations.

Exit behavior:
  - Exit 0 with JSON {"hookSpecificOutput": {"permissionDecision": "deny", ...}} = block
  - Exit 0 with no output = allow
"""
import json
import re
import sys

# Destructive patterns to block - tuple of (regex, reason)
DESTRUCTIVE_PATTERNS = [
    # Git commands that discard uncommitted changes
    (
        r"git\s+checkout\s+--\s+",
        "git checkout -- discards uncommitted changes permanently. Use 'git stash' first."
    ),
    (
        r"git\s+checkout\s+(?!-b\b)(?!--orphan\b)[^\s]+\s+--\s+",
        "git checkout <ref> -- <path> overwrites working tree. Use 'git stash' first."
    ),
    (
        r"git\s+restore\s+(?!--staged\b)(?!-S\b)",
        "git restore discards uncommitted changes. Use 'git stash' or 'git diff' first."
    ),
    (
        r"git\s+restore\s+.*(?:--worktree|-W\b)",
        "git restore --worktree/-W discards uncommitted changes permanently."
    ),
    # Git reset variants
    (
        r"git\s+reset\s+--hard",
        "git reset --hard destroys uncommitted changes. Use 'git stash' first."
    ),
    (
        r"git\s+reset\s+--merge",
        "git reset --merge can lose uncommitted changes."
    ),
    # Git clean
    (
        r"git\s+clean\s+-[a-z]*f",
        "git clean -f removes untracked files permanently. Review with 'git clean -n' first."
    ),
    # Force operations
    # Note: (?![-a-z]) ensures we only block bare --force, not --force-with-lease or --force-if-includes
    (
        r"git\s+push\s+.*--force(?![-a-z])",
        "Force push can destroy remote history. Use --force-with-lease if necessary."
    ),
    (
        r"git\s+push\s+.*-f\b",
        "Force push (-f) can destroy remote history. Use --force-with-lease if necessary."
    ),
    (
        r"git\s+branch\s+-D\b",
        "git branch -D force-deletes without merge check. Use -d for safety."
    ),
    # Destructive filesystem commands
    # Note: [rR] because both -r and -R mean recursive in GNU coreutils
    # Note: [a-zA-Z] to handle any flag combinations
    # Note: Specific root/home pattern MUST come before generic pattern for correct error message
    # Note: Also catch separate flags (-r -f) and long options (--recursive --force)
    (
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+[/~]|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+[/~]",
        "rm -rf on root or home paths is EXTREMELY DANGEROUS. This command will NOT be executed. Ask the user to run it manually if truly needed."
    ),
    (
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR]",
        "rm -rf is destructive and requires human approval. Explain what you want to delete and why, then ask the user to run the command manually."
    ),
    # Catch rm with separate -r and -f flags (e.g., rm -r -f, rm -f -r, rm -r -i -f)
    (
        r"rm\s+(-[a-zA-Z]+\s+)*-[rR]\s+(-[a-zA-Z]+\s+)*-f|rm\s+(-[a-zA-Z]+\s+)*-f\s+(-[a-zA-Z]+\s+)*-[rR]",
        "rm with separate -r -f flags is destructive and requires human approval."
    ),
    # Catch rm with long options (--recursive, --force)
    (
        r"rm\s+.*--recursive.*--force|rm\s+.*--force.*--recursive",
        "rm --recursive --force is destructive and requires human approval."
    ),
    # Git stash drop/clear without explicit permission
    (
        r"git\s+stash\s+drop",
        "git stash drop permanently deletes stashed changes. List stashes first."
    ),
    (
        r"git\s+stash\s+clear",
        "git stash clear permanently deletes ALL stashed changes."
    ),
]

# Patterns that are safe even if they match above (allowlist)
SAFE_PATTERNS = [
    r"git\s+checkout\s+-b\s+",           # Creating new branch
    r"git\s+checkout\s+--orphan\s+",     # Creating orphan branch
    # Unstaging is safe, BUT NOT if --worktree/-W is also present (that modifies working tree)
    r"git\s+restore\s+--staged\s+(?!.*--worktree)(?!.*-W\b)",  # Unstaging only (safe)
    r"git\s+restore\s+-S\s+(?!.*--worktree)(?!.*-W\b)",        # Unstaging short form (safe)
    r"git\s+clean\s+-n",                 # Dry run
    r"git\s+clean\s+--dry-run",          # Dry run
    # Allow rm -rf on temp directories (designed for ephemeral data)
    # Note: [rR] because both -r and -R mean recursive
    # Note: Must handle BOTH flag orderings: -rf/-Rf AND -fr/-fR
    r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+/tmp/",        # /tmp/... (-rf, -Rf style)
    r"rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+/tmp/",        # /tmp/... (-fr, -fR style)
    r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+/var/tmp/",    # /var/tmp/... (-rf style)
    r"rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+/var/tmp/",    # /var/tmp/... (-fr style)
    r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+\$TMPDIR/",    # $TMPDIR/... (-rf style)
    r"rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+\$TMPDIR/",    # $TMPDIR/... (-fr style)
    r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+\$\{TMPDIR",   # ${TMPDIR}/... (-rf style)
    r"rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+\$\{TMPDIR",   # ${TMPDIR}/... (-fr style)
    r'rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+"\$TMPDIR/',   # "$TMPDIR/..." (-rf style)
    r'rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+"\$TMPDIR/',   # "$TMPDIR/..." (-fr style)
    r'rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+"\$\{TMPDIR',  # "${TMPDIR}/..." (-rf style)
    r'rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+"\$\{TMPDIR',  # "${TMPDIR}/..." (-fr style)
    # Also allow separate flags (-r -f) and long options on temp directories
    r"rm\s+(-[a-zA-Z]+\s+)*-[rR]\s+(-[a-zA-Z]+\s+)*-f\s+/tmp/",      # rm -r -f /tmp/...
    r"rm\s+(-[a-zA-Z]+\s+)*-f\s+(-[a-zA-Z]+\s+)*-[rR]\s+/tmp/",      # rm -f -r /tmp/...
    r"rm\s+(-[a-zA-Z]+\s+)*-[rR]\s+(-[a-zA-Z]+\s+)*-f\s+/var/tmp/",  # rm -r -f /var/tmp/...
    r"rm\s+(-[a-zA-Z]+\s+)*-f\s+(-[a-zA-Z]+\s+)*-[rR]\s+/var/tmp/",  # rm -f -r /var/tmp/...
    r"rm\s+.*--recursive.*--force\s+/tmp/",   # rm --recursive --force /tmp/...
    r"rm\s+.*--force.*--recursive\s+/tmp/",   # rm --force --recursive /tmp/...
    r"rm\s+.*--recursive.*--force\s+/var/tmp/",
    r"rm\s+.*--force.*--recursive\s+/var/tmp/",
]


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        # Can't parse input, allow by default
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    # Use 'or {}' to handle both missing key AND explicit null value
    tool_input = input_data.get("tool_input") or {}
    command = tool_input.get("command", "")

    # Only check Bash commands with valid string command
    # Note: isinstance check prevents TypeError if command is int/list/bool
    if tool_name != "Bash" or not isinstance(command, str) or not command:
        sys.exit(0)

    # Check if command matches any safe pattern first
    for pattern in SAFE_PATTERNS:
        if re.search(pattern, command):
            sys.exit(0)

    # Check if command matches any destructive pattern
    # Note: Case-sensitive matching is intentional - e.g., git branch -D vs -d are different!
    for pattern, reason in DESTRUCTIVE_PATTERNS:
        if re.search(pattern, command):
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        f"BLOCKED by git_safety_guard.py\n\n"
                        f"Reason: {reason}\n\n"
                        f"Command: {command}\n\n"
                        f"If this operation is truly needed, ask the user for explicit "
                        f"permission and have them run the command manually."
                    )
                }
            }
            print(json.dumps(output))
            sys.exit(0)

    # Allow all other commands
    sys.exit(0)


if __name__ == "__main__":
    main()
