# ADR-004: Docker Guard Hook for Daemon Timeout Protection

**Status**: Accepted
**Date**: 2025-12-28
**Deciders**: Skillsmith Team
**Issue**: SMI-719

## Context

Docker daemon can become unresponsive, causing `docker exec` commands to hang indefinitely. This blocks Claude Code sessions and requires manual intervention to kill stuck processes. During Phase 2c development, we observed 32+ stuck Docker processes due to an unresponsive daemon.

## Decision

Implement a pre-command hook that validates Docker daemon health before executing Docker commands:

```
.claude/hooks/docker-guard.json    # Hook configuration
scripts/docker-timeout-check.sh    # Health check script
```

The hook:
1. Runs `docker info` with a 5-second timeout before any `docker exec|compose|build|run|ps` command
2. Blocks the command if Docker is unresponsive
3. Warns if more than 10 stuck Docker processes are detected
4. Cleans up stuck processes on session end

## Consequences

### Positive
- Prevents indefinite hangs when Docker daemon is unresponsive
- Provides actionable error messages with recovery suggestions
- Automatic cleanup of stuck processes
- Non-blocking for healthy Docker environments

### Negative
- Adds 5-second timeout overhead when Docker is truly unresponsive
- Requires hook system to be configured in Claude Code

### Neutral
- Hook only applies to Docker-related commands
- Settings configurable via environment variables (DOCKER_TIMEOUT, MAX_DOCKER_STUCK)

## Alternatives Considered

### Alternative 1: Wrapper Script for All Docker Commands
- Pros: Works without hook system
- Cons: Requires modifying all Docker invocations
- Why rejected: Hooks provide cleaner integration

### Alternative 2: Background Daemon Monitor
- Pros: Proactive detection
- Cons: More complex, resource overhead
- Why rejected: Over-engineered for the problem

## References

- [Claude Code Hooks Documentation](https://docs.claude.ai/claude-code/hooks)
- `.claude/hooks/docker-guard.json`
- `scripts/docker-timeout-check.sh`
