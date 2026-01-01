# ADR-012: Native Module Version Management Strategy

**Status**: Accepted
**Date**: 2025-12-31
**Deciders**: Skillsmith Team
**Related Issues**: SMI-851
**Supersedes**: Extends ADR-002, ADR-003

## Context

The Phase 4 orchestrator encountered runtime failures due to native module (better-sqlite3) version mismatches:

```
The module 'better_sqlite3.node' was compiled against NODE_MODULE_VERSION 131.
This version of Node.js requires NODE_MODULE_VERSION 127.
```

### Root Cause Analysis

1. **npx cache pollution**: `npx claude-flow@alpha` caches compiled native modules in `~/.npm/_npx/`
2. **Node.js version switching**: Developer switched from Node 23 (MODULE_VERSION 131) to Node 22 (MODULE_VERSION 127) via nvm
3. **Stale binary**: The cached native addon was compiled for a different Node.js version

### Impact

- Phase 4 orchestrator's ReasoningBank feature failed to initialize
- Orchestration continued (non-fatal) but memory persistence was unavailable
- Same issue could affect any developer switching Node versions

## Decision

Implement a multi-layered strategy for native module version management:

### 1. Local Dependency Installation

Install claude-flow as a local devDependency instead of using `npx` with remote version:

```bash
npm install claude-flow@alpha --save-dev
```

This ensures native modules are compiled for the project's Node.js version.

### 2. Node.js Version Pinning

Pin Node.js version at project level:

```bash
# .nvmrc
22
```

```json
// package.json
"engines": {
  "node": ">=22.0.0"
}
```

### 3. Pre-flight Health Check

Verify native modules work before execution:

```bash
# In run.sh
if ! npx claude-flow memory store __health_check__ "$(date +%s)" --namespace health; then
    echo "Error: claude-flow health check failed"
    echo "Try running: npm rebuild better-sqlite3"
    exit 1
fi
```

### 4. Docker Isolation for Orchestration

Add Docker service for orchestrator to ensure consistent environment:

```yaml
# docker-compose.yml
orchestrator:
  build:
    context: .
    dockerfile: Dockerfile
    target: dev
  environment:
    - LINEAR_API_KEY=${LINEAR_API_KEY}
    - SKILLSMITH_PATH=/app
  command: npx tsx scripts/phase4-orchestrator/orchestrator.ts
  profiles:
    - orchestrator
```

### 5. Portable Configuration

Use environment variables with sensible defaults:

```typescript
export const CONFIG = {
  skillsmithPath: process.env.SKILLSMITH_PATH || process.cwd(),
  maxAgentsPerEpic: parseIntSafe(process.env.MAX_AGENTS_PER_EPIC, 6),
  // ...
}
```

## Consequences

### Positive

- Native modules always compiled for correct Node.js version
- Health check catches issues before orchestration starts
- Docker provides consistent execution environment
- Configuration is portable across machines
- Version compatibility warnings prevent silent failures

### Negative

- Additional 177 dependencies in devDependencies (claude-flow)
- Version drift from upstream `@alpha` releases
- Developers must run `npm rebuild` after Node.js upgrades

### Neutral

- Docker orchestrator is optional (can still run locally)
- Existing development workflow unchanged
- CI/CD can use either local or Docker execution

## Alternatives Considered

### Alternative 1: Clear npx cache on each run

```bash
rm -rf ~/.npm/_npx/* && npx claude-flow@alpha ...
```

- Pros: Always fresh installation
- Cons: Slow (downloads on every run), network-dependent
- Why rejected: Unacceptable performance overhead

### Alternative 2: Global installation

```bash
npm install -g claude-flow@alpha
```

- Pros: Single installation, fast execution
- Cons: Version conflicts across projects, requires global write access
- Why rejected: Doesn't solve multi-Node-version scenario

### Alternative 3: Disable ReasoningBank feature

- Pros: Avoids native module entirely
- Cons: Loses memory persistence across sessions
- Why rejected: Feature is valuable for orchestration continuity

### Alternative 4: MCP Server mode (Future consideration)

Connect to claude-flow as a long-running MCP server instead of CLI spawning:

```typescript
const client = await connectToMCPServer('http://localhost:8080');
await client.call('memory_store', { key, value });
```

- Pros: One-time native module load, 10-50x faster
- Cons: Requires architecture change, server lifecycle management
- Status: Documented for P2 implementation in SMI-851

## Implementation Checklist

- [x] Install claude-flow as local devDependency
- [x] Update all scripts to use `npx claude-flow` (not `@alpha`)
- [x] Add `.nvmrc` with Node 22
- [x] Add `engines` field to package.json
- [x] Add pre-flight health check to `run.sh`
- [x] Add version compatibility warning
- [x] Add Docker orchestrator service
- [x] Make config.ts portable with environment variables
- [ ] Configure Dependabot for claude-flow updates (P3)
- [ ] Implement MCP server mode (P2 - future)

## Lessons Learned

### Pattern: Native Module Dependency Management

When integrating packages with native Node.js addons:

1. **Pin Node.js version** - Use `.nvmrc` and `engines` field
2. **Prefer local over global/npx** - Avoids cache pollution
3. **Add health checks** - Verify native modules work before execution
4. **Provide rebuild instructions** - Document `npm rebuild` for Node upgrades
5. **Consider Docker isolation** - Eliminates host environment variability
6. **Fail fast with clear errors** - Don't let corrupted binaries cause cryptic failures

### Anti-patterns Avoided

- ❌ Relying on npx cache for native modules
- ❌ Hardcoding paths in configuration
- ❌ Assuming consistent Node.js version across environments
- ❌ Silent failures on native module load errors

## References

- [ADR-002: Docker with glibc for Native Module Compatibility](002-docker-glibc-requirement.md)
- [ADR-003: Claude-flow Integration](003-claude-flow-integration.md)
- [SMI-851: Claude-Flow Dependency Management Strategy](https://linear.app/smith-horn-group/issue/SMI-851)
- [Node.js Release Schedule](https://nodejs.org/en/about/releases/)
- [NODE_MODULE_VERSION Reference](https://nodejs.org/en/download/releases/)
- [better-sqlite3 Troubleshooting](https://github.com/WiseLibs/better-sqlite3/blob/master/docs/troubleshooting.md)

## Changelog

| Date | Change |
|------|--------|
| 2025-12-31 | Initial decision after SMI-851 investigation and implementation |
