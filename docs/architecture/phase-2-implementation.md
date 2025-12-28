# Phase 2 Implementation Plan

**Version**: 1.1
**Status**: Active (Phase 2a Complete)
**Last Updated**: 2025-12-28

## Overview

Phase 2 implements core skill discovery functionality with technical risk mitigations powered by claude-flow integration.

## Goals

1. **Core search** - Fast, relevant skill discovery
2. **GitHub indexing** - Primary skill source with 50,000+ skills
3. **Ranking** - Quality-based result ordering
4. **Caching** - Fresh results with efficient invalidation

## Linear Issues

### Core Features (Original)

| Priority | Issue | Title | Status | Risk Mitigation |
|----------|-------|-------|--------|-----------------|
| P0 | SMI-627 | Core search implementation | In Progress | Neural patterns, memory caching |
| P0 | SMI-628 | GitHub skill indexing | ✅ Done | Swarm coordination, rate limiting |
| P1 | SMI-629 | Ranking algorithm | Todo | Neural prediction |
| P1 | SMI-630 | Cache invalidation | Todo | Memory TTL |
| P1 | SMI-631 | E2E tests | Todo | - |
| P2 | SMI-632 | Performance benchmarks | Todo | Bottleneck analysis |
| P2 | SMI-633 | VS Code extension | Todo | - |
| Process | SMI-634 | Swarm improvements | Todo | - |

### Technical Enhancements (Added from Phase 2a Retro)

| Priority | Issue | Title | Dependencies |
|----------|-------|-------|--------------|
| P1 | SMI-642 | Vector embeddings for semantic search | SMI-627 |
| P1 | SMI-643 | Swarm coordination for parallel indexing | SMI-628 ✅ |
| P1 | SMI-644 | Tiered cache layer with TTL | SMI-627 |
| P2 | SMI-645 | GitHub webhook support | SMI-628 ✅ |
| P2 | SMI-646 | Skill dependency graph | SMI-628 ✅ |

### Process Improvements (Added from Phase 2a Retro)

| Issue | Title | Purpose |
|-------|-------|---------|
| SMI-638 | Session checkpointing to memory | Prevent data loss on session stall |
| SMI-639 | Incremental typecheck verification | Catch errors early |
| SMI-640 | Linear updates during development | Real-time progress tracking |
| SMI-641 | Session ID storage for recovery | Enable context restoration |

## Technical Risk Mitigations

### Risk 1: Search Latency

**Target**: <100ms p50, <500ms p99

**Mitigation Strategy**:

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  User Query     │────▶│  Memory Cache    │────▶│  Return Cached  │
└─────────────────┘     │  (TTL: 1 hour)   │     │  Results        │
                        └────────┬─────────┘     └─────────────────┘
                                 │ miss
                                 ▼
                        ┌──────────────────┐     ┌─────────────────┐
                        │  SQLite FTS5     │────▶│  Neural Rank    │
                        │  + Embeddings    │     │  & Cache Store  │
                        └──────────────────┘     └─────────────────┘
```

**Implementation**:

```javascript
// packages/core/src/services/SearchService.ts

async search(query: string): Promise<SearchResponse> {
  // 1. Check memory cache
  const cached = await mcp__claude-flow__memory_usage({
    action: "retrieve",
    namespace: "skillsmith",
    key: `search/${hash(query)}`
  });

  if (cached.value && !isExpired(cached)) {
    return cached.value;
  }

  // 2. Execute search
  const results = await this.executeSearch(query);

  // 3. Apply neural ranking
  const ranked = await mcp__claude-flow__neural_patterns({
    action: "predict",
    operation: "rank",
    metadata: { query, results }
  });

  // 4. Cache results
  await mcp__claude-flow__memory_usage({
    action: "store",
    namespace: "skillsmith",
    key: `search/${hash(query)}`,
    value: ranked,
    ttl: 3600
  });

  return ranked;
}
```

### Risk 2: GitHub API Rate Limiting

**Constraint**: 5,000 requests/hour (authenticated)

**Mitigation Strategy**:

```
┌─────────────────────────────────────────────────────────────┐
│                    Indexing Swarm                            │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐     │
│  │ Agent 1 │   │ Agent 2 │   │ Agent 3 │   │ Agent 4 │     │
│  │ Repos   │   │ Repos   │   │ Repos   │   │ Repos   │     │
│  │ A-F     │   │ G-L     │   │ M-R     │   │ S-Z     │     │
│  └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘     │
│       │             │             │             │           │
│       └─────────────┴──────┬──────┴─────────────┘           │
│                            │                                 │
│                     ┌──────▼──────┐                         │
│                     │ Rate Limiter│                         │
│                     │ 150ms delay │                         │
│                     └──────┬──────┘                         │
│                            │                                 │
│                     ┌──────▼──────┐                         │
│                     │  SQLite DB  │                         │
│                     └─────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

**Implementation**:

```javascript
// packages/core/src/indexer/GitHubIndexer.ts

async indexAll(): Promise<void> {
  // Initialize swarm
  const swarm = await mcp__claude-flow__swarm_init({
    topology: "mesh",
    maxAgents: 4,
    strategy: "balanced"
  });

  // Partition work
  const partitions = this.partitionRepos(['A-F', 'G-L', 'M-R', 'S-Z']);

  // Orchestrate parallel indexing
  await mcp__claude-flow__task_orchestrate({
    task: "Index GitHub skill repositories",
    strategy: "parallel",
    dependencies: partitions.map(p => ({
      task: `Index repos ${p.range}`,
      data: p.repos
    }))
  });
}
```

### Risk 3: Cache Invalidation

**Challenge**: Balance freshness vs. performance

**Mitigation Strategy**:

| Cache Type | TTL | Invalidation Trigger |
|------------|-----|---------------------|
| Search results | 1 hour | Query change, index update |
| Skill details | 24 hours | GitHub webhook, manual refresh |
| Popular queries | 4 hours | Usage analytics |

**Implementation**:

```javascript
// Tiered TTL based on query popularity
const getTTL = async (query: string): Promise<number> => {
  const analytics = await mcp__claude-flow__memory_usage({
    action: "retrieve",
    namespace: "skillsmith",
    key: "analytics/popular-queries"
  });

  if (analytics.value?.includes(query)) {
    return 4 * 3600; // 4 hours for popular
  }
  return 3600; // 1 hour default
};
```

### Risk 4: Security Scan Bottlenecks

**Mitigation Strategy**:

```javascript
// Distribute scans across agents
async scanBatch(skills: string[]): Promise<ScanReport[]> {
  await mcp__claude-flow__load_balance({
    tasks: skills.map(id => ({
      type: "security_scan",
      skillId: id,
      priority: "medium"
    }))
  });
}
```

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Code                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    Skillsmith MCP Server                   │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐│  │
│  │  │   search    │  │  get_skill  │  │ install/uninstall   ││  │
│  │  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘│  │
│  │         │                │                     │           │  │
│  │  ┌──────▼────────────────▼─────────────────────▼─────────┐│  │
│  │  │                   @skillsmith/core                     ││  │
│  │  │  ┌──────────┐  ┌───────────┐  ┌───────────────────┐  ││  │
│  │  │  │ Search   │  │ Skill     │  │ Security          │  ││  │
│  │  │  │ Service  │  │ Repository│  │ Scanner           │  ││  │
│  │  │  └────┬─────┘  └─────┬─────┘  └─────────┬─────────┘  ││  │
│  │  │       │              │                   │            ││  │
│  │  │  ┌────▼──────────────▼───────────────────▼──────────┐ ││  │
│  │  │  │              SQLite + FTS5 + Embeddings          │ ││  │
│  │  │  └──────────────────────────────────────────────────┘ ││  │
│  │  └────────────────────────────────────────────────────────┘│  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌───────────────────────────▼───────────────────────────────┐  │
│  │                   claude-flow MCP Server                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │  │
│  │  │ memory   │  │ neural   │  │ swarm    │  │ perf      │  │  │
│  │  │ _usage   │  │ _patterns│  │ _init    │  │ _report   │  │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └───────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Query
    │
    ▼
┌─────────────────┐
│ Memory Cache    │──hit──▶ Return Cached
│ Check           │
└────────┬────────┘
         │ miss
         ▼
┌─────────────────┐
│ FTS5 Full-Text  │
│ Search          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Embedding       │
│ Similarity      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Hybrid Ranking  │
│ + Neural Boost  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Cache Store     │
│ + Return        │
└─────────────────┘
```

## Implementation Phases

### Phase 2a: Foundation (P0 Issues)

**Duration**: First sprint

1. **SMI-627: Core Search**
   - Implement hybrid search (FTS5 + embeddings)
   - Add memory caching layer
   - Integrate with existing SearchService

2. **SMI-628: GitHub Indexing**
   - Create GitHubIndexer service
   - Implement rate-aware fetching
   - Set up incremental updates

**Deliverables**:
- Working search with caching
- Initial skill database (1,000+ skills)
- Performance baseline established

### Phase 2b: Optimization (P1 Issues)

**Duration**: Second sprint

1. **SMI-629: Ranking Algorithm**
   - Implement quality scoring
   - Add neural pattern integration
   - A/B test ranking changes

2. **SMI-630: Cache Invalidation**
   - Implement TTL-based expiration
   - Add event-driven invalidation
   - Background refresh for popular queries

3. **SMI-631: E2E Tests**
   - Claude Code integration tests
   - Install/uninstall lifecycle
   - Search accuracy tests

**Deliverables**:
- Improved search relevance
- Reliable cache behavior
- E2E test suite

### Phase 2c: Scale (P2 Issues)

**Duration**: Third sprint

1. **SMI-632: Performance Benchmarks**
   - Latency targets (<100ms p50)
   - Throughput testing
   - Bottleneck identification

2. **SMI-633: VS Code Extension**
   - Sidebar UI
   - One-click install
   - Codebase recommendations

**Deliverables**:
- Performance targets met
- VS Code extension alpha

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Search latency p50 | <100ms | Performance benchmarks |
| Search latency p99 | <500ms | Performance benchmarks |
| Skills indexed | 10,000+ | Database count |
| Cache hit rate | >70% | Memory analytics |
| Install success rate | >95% | MCP tool metrics |

## Dependencies

- claude-flow MCP server (optional but recommended)
- GitHub API access (authenticated)
- SQLite with FTS5 extension
- onnxruntime for embeddings

## Phase 2a Completion Summary

**SMI-628: GitHub Skill Indexing** - Completed December 28, 2025

### Deliverables

| File | Purpose | Lines |
|------|---------|-------|
| `packages/core/src/indexer/SkillParser.ts` | YAML frontmatter parsing | ~300 |
| `packages/core/src/indexer/GitHubIndexer.ts` | GitHub API integration | ~500 |
| `packages/core/src/indexer/index.ts` | Module exports | ~20 |
| `packages/core/src/repositories/IndexerRepository.ts` | Database operations | ~350 |
| `packages/core/tests/GitHubIndexer.test.ts` | Test suite | ~500 |

### Key Implementation Details

- **Rate Limiting**: 150ms minimum delay between API calls
- **Retry Logic**: Exponential backoff up to 30s, 3 max retries
- **Change Detection**: SHA-based for incremental updates
- **Quality Scoring**: 0-1 normalized based on metadata completeness
- **Trust Tiers**: verified, community, experimental, unknown

### Tests

| Suite | Tests | Status |
|-------|-------|--------|
| SkillParser | 12 | ✅ Pass |
| GitHubIndexer | 8 | ✅ Pass |
| IndexerRepository | 12 | ✅ Pass |
| Integration | 1 | ⏭️ Skip (requires token) |
| **Total** | **33** | ✅ All Pass |

### Learnings Applied

Issues SMI-638 through SMI-646 were created based on Phase 2a learnings:
- Session stall recovery needs improvement
- Incremental verification catches errors earlier
- Linear integration during development improves tracking

See [Phase 2a Retrospective](../retros/phase-2a-github-indexing.md) for full details.

---

## References

- [ADR-003: Claude-flow Integration](../adr/003-claude-flow-integration.md)
- [Engineering Standards](./standards.md)
- [Phase 1 Retrospective](../retros/phase-1-ci-testing.md)
- [Phase 2a Retrospective](../retros/phase-2a-github-indexing.md)
