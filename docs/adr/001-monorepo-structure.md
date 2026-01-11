# ADR-001: Monorepo Structure with npm Workspaces

**Status**: Accepted (Amended 2026-01-02)
**Date**: 2025-12-27
**Deciders**: Skillsmith Team

## Context

Skillsmith needs to deliver multiple packages:
- Core library (database, repositories, services)
- MCP server (Claude Code integration)
- CLI tool (command-line interface)

We needed to decide how to structure the codebase for development efficiency and release management.

## Decision

Use a monorepo with npm workspaces containing three packages:

```
packages/
├── core/        # @skillsmith/core
├── mcp-server/  # @skillsmith/mcp-server
└── cli/         # @skillsmith/cli
```

## Consequences

### Positive
- Shared development environment and tooling
- Atomic commits across packages
- Easy local development with workspace references
- Single CI/CD pipeline

### Negative
- More complex build ordering (core must build before dependents)
- Larger initial clone size
- Need to manage inter-package dependencies carefully

### Neutral
- Each package still published independently to npm
- TypeScript project references handle build ordering

## Alternatives Considered

### Alternative 1: Separate Repositories
- Pros: Independent release cycles, simpler per-repo
- Cons: Harder to coordinate changes, more CI complexity
- Why rejected: Too much overhead for a small team

### Alternative 2: Single Package
- Pros: Simplest structure
- Cons: Forces users to install everything, harder to maintain
- Why rejected: Different use cases need different packages

## Updates

### Update 2026-01-02: Additional Packages

The monorepo has expanded to include additional packages:

```
packages/
├── core/              # @skillsmith/core (Elastic-2.0)
├── mcp-server/        # @skillsmith/mcp-server (Elastic-2.0)
├── cli/               # @skillsmith/cli (Elastic-2.0)
├── vscode-extension/  # @skillsmith/vscode-extension (Elastic-2.0)
└── enterprise/        # @skillsmith/enterprise (Elastic-2.0, proprietary features)
```

> **License Update (January 2026)**: All packages migrated from Apache-2.0 to Elastic License 2.0. See [ADR-013](./013-open-core-licensing.md).

**VS Code Extension** (added Phase 3):
- MCP client for VS Code integration
- See ADR-005 for architecture details

**Enterprise Package** (Phase 7):
- Proprietary features for commercial tiers
- Usage quota enforcement
- See ADR-013 (Open Core Licensing), ADR-014 (Enterprise Architecture), and ADR-017 (Quota Enforcement)

### Package Dependencies

```
enterprise → core (peer)
          → mcp-server (peer)
vscode-extension → mcp-server
mcp-server → core
cli → core
```

## References

- [npm Workspaces](https://docs.npmjs.com/cli/v7/using-npm/workspaces)
- [TypeScript Project References](https://www.typescriptlang.org/docs/handbook/project-references.html)
