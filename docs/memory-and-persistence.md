# Memory and Persistence Guide

Understanding how Claude Code stores and retrieves information in the container.

## Overview

Claude Code has multiple memory systems that work together to provide context, history, and persistence across sessions. When using the container with volume mounts, all of these persist automatically.

## Memory Architecture

### 1. Conversation History

**Location:** `/home/dev/.claude/projects/[project-hash]/[session-id].jsonl`

**What it stores:**
- Complete conversation transcripts
- Tool calls and results
- User inputs and Claude responses
- Session metadata

**Persistence:**
```bash
# Persists automatically with volume mount
-v claude-auth:/home/dev/.claude
```

**Access:**
```bash
# Inside container
ls ~/.claude/projects/
cat ~/.claude/projects/[project-hash]/[session-id].jsonl
```

### 2. Project Memory (CLAUDE.md)

**Location:** Project root or `./.claude/CLAUDE.md`

**What it stores:**
- Project-specific instructions
- Code conventions
- Architecture decisions
- Team preferences

**Persistence:** Stored in your project directory (workspace volume mount)

**How it works:**
- Automatically loaded when Claude Code starts in a project
- Shared across team (checked into git)
- Takes precedence in the memory hierarchy

**Example:**
```markdown
# CLAUDE.md

## Project Rules
- Always use TypeScript strict mode
- Test coverage must be >80%
- Follow our API naming convention: /api/v1/resource

## Architecture
- We use React with Redux for state management
- API layer uses GraphQL
```

### 3. User Memory

**Location:** `/home/dev/.claude/CLAUDE.md`

**What it stores:**
- Personal preferences across all projects
- Your coding style preferences
- Custom instructions for Claude

**Persistence:**
```bash
# Persists with volume mount
-v claude-auth:/home/dev/.claude
```

**Example:**
```markdown
# Personal Preferences

## My Style
- I prefer functional programming patterns
- Always use descriptive variable names
- Add comments for complex logic

## Testing
- Write tests before implementation (TDD)
```

### 4. File Edit History

**Location:** `/home/dev/.claude/file-history/`

**What it stores:**
- History of file edits made by Claude
- Allows undo/redo operations
- Tracks changes over time

**Persistence:** Automatic with volume mount

### 5. Shell Command History

**Location:** `/home/dev/.claude/shell-snapshots/`

**What it stores:**
- Commands executed via Bash tool
- Output and results
- Execution context

**Persistence:** Automatic with volume mount

### 6. Session Environment

**Location:** `/home/dev/.claude/session-env/`

**What it stores:**
- Session-specific environment variables
- Working directory context
- Runtime state

**Persistence:** Automatic with volume mount

## Memory Hierarchy

Claude Code loads memory in this order (higher precedence first):

1. **Enterprise policy** (`/etc/claude-code/CLAUDE.md`) - System-wide
2. **Project memory** (`./CLAUDE.md`) - Project-specific
3. **User memory** (`~/.claude/CLAUDE.md`) - Personal preferences
4. **Project local** (`./CLAUDE.local.md`) - Git-ignored overrides

> **Note:** Instructions in higher levels override lower levels when they conflict.

## Using Memory Effectively

### Quick Memory Addition with `#`

The fastest way to add something to memory:

```
# Start your message with #
# Remember: We use camelCase for JavaScript functions

# Claude will prompt you to choose which memory file to update
```

### Edit Memory Files with `/memory`

```
/memory
# Opens your system editor to edit CLAUDE.md files
```

### Setting Up Personal Preferences

**Create user memory in container:**
```bash
# Inside container
cat > ~/.claude/CLAUDE.md << 'EOF'
# My Coding Preferences

## Style
- Use TypeScript for all new files
- Prefer async/await over .then()
- Always add JSDoc comments for functions

## Testing
- Write tests alongside implementation
- Mock external dependencies
- Aim for 80%+ coverage
EOF
```

### Project-Specific Memory

**Create project memory (persisted in git):**
```bash
# In your project root
cat > CLAUDE.md << 'EOF'
# Project Instructions

## Architecture
- This is a microservices architecture
- Services communicate via RabbitMQ
- Each service has its own database

## Deployment
- Use Docker Compose for local dev
- Production uses Kubernetes
- CI/CD via GitHub Actions

## Code Style
- Follow our ESLint config
- Use Prettier for formatting
- TypeScript strict mode enabled
EOF
```

## Persistence Setup

### Full Persistence (Recommended)

Persist everything - conversation history, memory, settings:

```bash
# Create volume
container volume create claude-full

# Run with full persistence
container run -it --rm \
  -m 4G \
  -v claude-full:/home/dev/.claude \
  -v "$(pwd)":/workspace \
  ghcr.io/erepublik-labs/claude-code-container:latest
```

**What persists:**
- ✅ Conversation history
- ✅ User memory (`~/.claude/CLAUDE.md`)
- ✅ Settings and preferences
- ✅ File edit history
- ✅ Shell command history
- ✅ OAuth credentials (if using subscription auth)
- ✅ Git configuration (`~/.gitconfig`)

### Minimal Persistence (Workspace Only)

Only persist project files:

```bash
# No volume mount for .claude
container run -it --rm \
  -m 4G \
  -v "$(pwd)":/workspace \
  -e CLAUDE_API_KEY="$ANTHROPIC_API_KEY" \
  ghcr.io/erepublik-labs/claude-code-container:latest
```

**What persists:**
- ✅ Project files in workspace
- ✅ Project CLAUDE.md (in git)
- ❌ Conversation history (lost on restart)
- ❌ User memory (lost on restart)
- ❌ Settings (reset to defaults)

## Memory Best Practices

### 1. Use Project Memory for Team Knowledge

```markdown
# CLAUDE.md

## Database Schema
- Users table: id, email, created_at
- Posts table: id, user_id, title, content, published_at

## API Conventions
- All dates in ISO 8601 format
- Paginate with ?page=1&limit=20
- Error responses follow RFC 7807
```

### 2. Use User Memory for Personal Preferences

```markdown
# ~/.claude/CLAUDE.md

## My Preferences
- I prefer verbose logging during development
- Always explain complex algorithms
- Add performance optimization notes
```

### 3. Keep Memory Files Organized

```markdown
# CLAUDE.md

## Table of Contents
- [Architecture](#architecture)
- [Code Style](#code-style)
- [Testing](#testing)
- [Deployment](#deployment)

## Architecture
...

## Code Style
...
```

### 4. Update Memory When Patterns Change

```bash
# Use /memory command to edit
/memory

# Or use # for quick additions
# Update: We now use Vite instead of Webpack
```

### 5. Use Memory Imports for Large Projects

```markdown
# CLAUDE.md

Main project instructions here...

# Import component-specific docs
@./packages/ui/CLAUDE.md
@./packages/api/CLAUDE.md
```

## Troubleshooting

### Memory Not Persisting

**Problem:** Changes to user memory don't persist across container restarts.

**Solution:** Ensure you're using a volume mount:
```bash
-v claude-auth:/home/dev/.claude
```

### Can't Find Conversation History

**Problem:** Can't locate old conversations.

**Solution:** Check the projects directory:
```bash
# Inside container
ls -la ~/.claude/projects/
# Each directory is a project (based on path hash)
# Each .jsonl file is a conversation session
```

### Memory Files Not Loading

**Problem:** CLAUDE.md instructions not being followed.

**Solution:**
1. Check file location:
   ```bash
   cat CLAUDE.md  # Should be in project root or ./.claude/
   cat ~/.claude/CLAUDE.md  # User preferences
   ```

2. Verify Claude Code is starting in correct directory:
   ```bash
   pwd  # Should be /workspace
   ```

3. Check memory hierarchy - project CLAUDE.md overrides user CLAUDE.md

### File Edit History Lost

**Problem:** Can't undo previous changes.

**Solution:** File history requires volume mount:
```bash
-v claude-full:/home/dev/.claude
```

## Advanced: Memory in CI/CD

For automated environments where you want consistent behavior:

```bash
# Create read-only memory volume
docker volume create claude-ci-memory

# Populate with CI-specific instructions
docker run --rm \
  -v claude-ci-memory:/memory \
  alpine sh -c 'cat > /memory/CLAUDE.md << EOF
# CI Environment Instructions
- Never prompt for user input
- Always use deterministic behavior
- Log all actions verbosely
EOF'

# Use in CI
docker run -it --rm \
  -v claude-ci-memory:/home/dev/.claude:ro \
  -v "$(pwd)":/workspace \
  -e CLAUDE_API_KEY="$CI_API_KEY" \
  ghcr.io/erepublik-labs/claude-code-container:latest
```

## See Also

- [Claude Code Memory Documentation](https://docs.claude.com/en/docs/claude-code/memory.md) - Official memory guide
- [Authentication Guide](authentication.md) - Credential persistence
- [Troubleshooting](troubleshooting.md) - Common issues
