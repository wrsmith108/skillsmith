# Implementation Plan: Coordinated npm Publish Pipeline (SMI-2230)

## Overview

Implement a CI/CD pipeline that ensures coordinated publishing of workspace packages with dependency validation, preventing the incident where `@skillsmith/mcp-server@0.3.18` was published before its dependency `@skillsmith/core@0.4.9` had the required exports.

## Problem Statement

During manual publishing:
1. `mcp-server@0.3.18` was published depending on `core@0.4.8`
2. `core@0.4.8` didn't export `createDatabaseAsync` that mcp-server needed
3. Users got runtime errors until we published `core@0.4.9` then `mcp-server@0.3.19`

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PUBLISH PIPELINE                              │
├─────────────────────────────────────────────────────────────────┤
│  1. VERSION CHECK    │  Validate package.json vs server.json    │
│  2. DEPENDENCY SCAN  │  Detect unpublished workspace deps       │
│  3. TOPOLOGICAL SORT │  Determine publish order                 │
│  4. PRE-PUBLISH TEST │  Run tests in Docker                     │
│  5. PUBLISH          │  npm publish in dependency order         │
│  6. SMOKE TEST       │  npx test of published package           │
│  7. MCP REGISTRY     │  Update MCP Registry listing             │
│  8. ROLLBACK         │  Unpublish on failure (within 72h)       │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Version Sync Validator (`scripts/validate-versions.ts`)

```typescript
interface VersionValidation {
  package: string;
  packageJsonVersion: string;
  serverJsonVersion?: string;
  match: boolean;
}

// Check package.json version matches server.json (for mcp-server)
// Fail CI if mismatch
```

### 2. Dependency Graph Analyzer (`scripts/analyze-deps.ts`)

```typescript
interface DependencyCheck {
  package: string;
  workspaceDeps: string[];
  unpublishedDeps: WorkspaceDep[];
  canPublish: boolean;
}

interface WorkspaceDep {
  name: string;
  localVersion: string;
  publishedVersion: string;
  hasUnpublishedChanges: boolean;
}

// Compare local workspace versions with npm registry
// Detect if workspace dep has changes not yet published
```

### 3. Publish Orchestrator (`scripts/publish-orchestrator.ts`)

```typescript
interface PublishPlan {
  packages: PublishStep[];
  order: string[]; // topological sort
}

interface PublishStep {
  package: string;
  version: string;
  dependencies: string[];
  prePublishChecks: Check[];
  postPublishChecks: Check[];
}

// Execute publish in correct order
// Handle rollback on failure
```

### 4. Smoke Test Runner (`scripts/smoke-test-published.ts`)

```typescript
// After publish, test the package works:
// 1. npx @skillsmith/mcp-server@<version> --version
// 2. Verify imports resolve
// 3. Run basic functionality test
```

### 5. MCP Registry Publisher (`scripts/publish-mcp-registry.ts`)

```typescript
// After npm publish succeeds:
// 1. Run mcp-publisher publish
// 2. Verify registry listing updated
// 3. Check version matches
```

## GitHub Actions Workflow

### `.github/workflows/publish.yml`

```yaml
name: Publish Packages

on:
  workflow_dispatch:
    inputs:
      package:
        description: 'Package to publish (or "all" for coordinated)'
        required: true
        type: choice
        options:
          - '@skillsmith/core'
          - '@skillsmith/mcp-server'
          - '@skillsmith/cli'
          - 'all'
      dry_run:
        description: 'Dry run (no actual publish)'
        type: boolean
        default: true

jobs:
  validate:
    runs-on: ubuntu-latest
    outputs:
      publish_plan: ${{ steps.plan.outputs.plan }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          registry-url: 'https://registry.npmjs.org'

      - name: Validate versions
        run: npm run validate:versions

      - name: Analyze dependencies
        id: plan
        run: npm run analyze:publish-deps -- --package=${{ inputs.package }}

  publish:
    needs: validate
    runs-on: ubuntu-latest
    strategy:
      matrix:
        package: ${{ fromJson(needs.validate.outputs.publish_plan) }}
      max-parallel: 1  # Sequential publish
    steps:
      - uses: actions/checkout@v4

      - name: Pre-publish tests
        run: docker exec skillsmith-dev-1 npm test -w ${{ matrix.package }}

      - name: Publish to npm
        if: ${{ !inputs.dry_run }}
        run: npm publish --access public -w ${{ matrix.package }}
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

      - name: Smoke test
        run: |
          npm cache clean --force
          npx -y ${{ matrix.package }}@latest --version

  mcp-registry:
    needs: publish
    if: contains(needs.validate.outputs.publish_plan, 'mcp-server')
    runs-on: ubuntu-latest
    steps:
      - name: Publish to MCP Registry
        run: |
          cd packages/mcp-server
          mcp-publisher publish
        env:
          MCP_REGISTRY_TOKEN: ${{ secrets.MCP_REGISTRY_TOKEN }}

      - name: Verify registry listing
        run: |
          sleep 30  # Wait for propagation
          VERSION=$(npm view @skillsmith/mcp-server version)
          REGISTRY_VERSION=$(curl -s "https://registry.modelcontextprotocol.io/v0.1/servers?search=skillsmith" | jq -r '.servers[0].packages[0].version')
          [ "$VERSION" = "$REGISTRY_VERSION" ] || exit 1
```

## Implementation Phases

### Phase 1: Version Validation (1 task)
- [ ] Create `scripts/validate-versions.ts`
- [ ] Add to CI as required check
- [ ] Test with intentional mismatch

### Phase 2: Dependency Analysis (2 tasks)
- [ ] Create `scripts/analyze-deps.ts`
- [ ] Implement npm registry version comparison
- [ ] Detect workspace deps with local changes

### Phase 3: Publish Orchestrator (2 tasks)
- [ ] Create `scripts/publish-orchestrator.ts`
- [ ] Implement topological sort for publish order
- [ ] Add rollback capability

### Phase 4: Smoke Tests (1 task)
- [ ] Create `scripts/smoke-test-published.ts`
- [ ] Test basic MCP server startup
- [ ] Verify imports resolve

### Phase 5: MCP Registry Integration (1 task)
- [ ] Add MCP Registry publish step to workflow
- [ ] Add verification of registry listing
- [ ] Add `MCP_REGISTRY_TOKEN` secret

### Phase 6: GitHub Workflow (1 task)
- [ ] Create `.github/workflows/publish.yml`
- [ ] Add manual trigger with package selection
- [ ] Add dry-run mode

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| npm unpublish only works within 72h | Quick detection via smoke tests |
| MCP Registry API changes | Version check the registry schema |
| Circular dependencies | Topological sort will detect |
| Rate limiting on npm | Add delays between publishes |

## Success Metrics

1. Zero broken publishes due to dependency mismatch
2. All publishes go through CI (no manual `npm publish`)
3. MCP Registry always in sync with npm within 5 minutes
4. Rollback succeeds when smoke tests fail

## Dependencies

- npm CLI
- mcp-publisher CLI
- Docker for tests
- GitHub Actions

## Estimated Effort

| Phase | Tasks | Complexity |
|-------|-------|------------|
| Phase 1 | 1 | Low |
| Phase 2 | 2 | Medium |
| Phase 3 | 2 | High |
| Phase 4 | 1 | Low |
| Phase 5 | 1 | Medium |
| Phase 6 | 1 | Medium |
| **Total** | **8** | **~4-6 hours** |
