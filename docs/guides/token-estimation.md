# Token Estimation Guide

**Version**: 1.0
**Status**: Active
**Reference**: SMI-1344

---

## Overview

Token estimation is a critical planning tool for preventing context overflow and enabling efficient parallel agent assignment. By estimating token budgets before execution, teams can:

- Break large initiatives into manageable waves
- Assign appropriate agent counts per wave
- Prevent mid-task context overflow
- Enable parallel execution without coordination failures

This guide documents the methodology proven effective in Wave 7 (Multi-Language AST Analysis).

---

## Methodology

### 1. Complexity Assessment

Before estimating tokens, assess the complexity of each issue using these factors:

| Factor | Low | Medium | High |
|--------|-----|--------|------|
| Files to create | 1-2 | 3-5 | 6+ |
| Files to modify | 1-3 | 4-8 | 9+ |
| Test coverage needed | Basic unit tests | Comprehensive unit + integration | Full coverage + edge cases |
| Dependencies | None | Internal packages | External packages + APIs |
| Architecture impact | Isolated change | Module-level change | Cross-package change |
| Code review scope | Single file | Multiple files | Architectural review |

### 2. Complexity Categories

Based on the assessment, categorize each issue:

#### Simple (5-8k tokens)
- Single file creation or modification
- Straightforward implementation
- Basic test coverage
- No architectural decisions
- Minimal dependencies

**Examples:**
- Adding a utility function
- Fixing a bug in existing code
- Adding a new test file
- Documentation updates with code examples

#### Medium (8-15k tokens)
- 3-5 files affected
- Multiple components involved
- Comprehensive test coverage required
- Some coordination between modules
- May require refactoring

**Examples:**
- Implementing a new service
- Adding a new MCP tool
- Creating a language adapter
- Refactoring a subsystem

#### Complex (15-25k tokens)
- 6+ files affected
- Cross-package changes
- Full test coverage with edge cases
- Architectural decisions required
- Integration with external systems
- Performance optimization needed

**Examples:**
- Implementing core infrastructure
- Building worker pools with concurrency
- Adding new package to monorepo
- Security hardening across codebase

---

## Token Estimation Formulas

### Per-Component Estimates

Use these baseline estimates and adjust based on complexity:

| Component Type | Base Tokens | Complexity Multiplier |
|----------------|-------------|----------------------|
| Source file (new) | 2,000 | Simple: 1x, Medium: 1.5x, Complex: 2x |
| Source file (modify) | 1,000 | Simple: 1x, Medium: 1.5x, Complex: 2x |
| Test file (new) | 1,500 | Simple: 1x, Medium: 1.5x, Complex: 2x |
| Type definitions | 500 | Simple: 1x, Medium: 1.5x, Complex: 2x |
| Documentation | 500 | Simple: 1x, Medium: 1.5x, Complex: 2x |
| Integration tests | 2,500 | Simple: 1x, Medium: 1.5x, Complex: 2x |

### Quick Estimation Formula

```
Total Tokens = Sum of (Base Tokens x Complexity Multiplier) x 1.2 (buffer)
```

The 1.2 buffer accounts for:
- Code review iterations
- Bug fixes during development
- Unexpected complexity
- Coordination overhead

### Per-Issue Heuristic

For quick planning, use this rule of thumb:

| Issue Complexity | Token Estimate | Recommended Agents |
|------------------|----------------|-------------------|
| Simple | 5-8k | 1 agent |
| Medium | 8-15k | 1-2 agents |
| Complex | 15-25k | 2-3 agents |

---

## Wave Planning Guidelines

### Maximum Wave Size

Based on practical experience, keep waves under **50k tokens** to ensure:
- Sufficient context for agent coordination
- Room for error handling and recovery
- Ability to complete code review in same session

### Wave Composition Rules

1. **Balance complexity**: Mix simple and complex issues to smooth out work distribution
2. **Group by dependencies**: Issues with shared dependencies should be in the same wave
3. **Parallelize adapters**: Similar implementations (e.g., language adapters) parallelize well
4. **Sequence infrastructure**: Core infrastructure must complete before dependent work

### Wave Planning Template

```markdown
## Wave X: [Name]

**Estimated Tokens**: Xk
**Agent Count**: N
**Dependencies**: Wave X-1

| Issue | Description | Complexity | Tokens | Agent |
|-------|-------------|------------|--------|-------|
| SMI-XXX | Description | Simple | 5k | agent-1 |
| SMI-YYY | Description | Medium | 10k | agent-2 |
| SMI-ZZZ | Description | Medium | 12k | agent-3 |

**Total**: Xk tokens
```

---

## Wave 7 Case Study

Wave 7 (Multi-Language AST Analysis) demonstrated effective token-based planning:

### Wave A: Core Infrastructure (~45k tokens)

| Component | Files | Tokens | Rationale |
|-----------|-------|--------|-----------|
| Core infrastructure | 5 source, 3 test | 15k | Complex: foundational architecture |
| TypeScript adapter | 2 source, 1 test | 12k | Medium: first adapter, establishes pattern |
| Python adapter | 2 source, 1 test | 10k | Medium: follows TS pattern |
| Type definitions | 1 source | 3k | Simple: shared types |
| Integration tests | 1 test | 5k | Medium: cross-adapter testing |

**Agent allocation**: 6 agents (hierarchical topology)
**Outcome**: Completed without context overflow

### Wave B: Additional Adapters (~37.5k tokens)

| Component | Files | Tokens | Rationale |
|-----------|-------|--------|-----------|
| Go adapter | 2 source, 1 test | 10k | Medium: new syntax patterns |
| Rust adapter | 2 source, 1 test | 12k | Medium: complex ownership patterns |
| Java adapter | 2 source, 1 test | 12k | Medium: verbose language patterns |
| Factory pattern | 1 source, 1 test | 3.5k | Simple: consolidates adapter creation |

**Agent allocation**: 4 agents (parallel execution)
**Outcome**: Zero conflicts, efficient parallel work

### Wave C: Optimization + Docs (~25k tokens)

| Component | Files | Tokens | Rationale |
|-----------|-------|--------|-----------|
| Incremental parsing | 3 source, 2 test | 12k | Medium: optimization focus |
| Language detection | 1 source, 1 test | 5k | Simple: utility function |
| Metrics integration | 1 source, 1 test | 4k | Simple: telemetry hookup |
| Documentation | 2 docs | 4k | Simple: architecture docs |

**Agent allocation**: 4 agents (mesh topology)
**Outcome**: Full test coverage, clean documentation

### Wave 7 Key Metrics

| Metric | Value |
|--------|-------|
| Total estimated tokens | ~107.5k |
| Actual context usage | ~95k (12% under estimate) |
| Issues completed | 20 |
| Average tokens per issue | 4.75k (lighter than expected due to adapter pattern reuse) |
| Parallel efficiency | 4-6 agents without conflicts |

---

## Best Practices

### Do

- Estimate before execution, not after
- Include buffer (20%) for unexpected complexity
- Group related work to maximize pattern reuse
- Track actual vs estimated for calibration
- Use consistent estimation across team

### Avoid

- Single waves over 50k tokens
- Mixing unrelated work in same wave
- Underestimating infrastructure work
- Skipping the estimation step for "simple" work
- Ignoring test coverage in estimates

### Calibration

After each wave, record:

```markdown
## Wave Calibration

| Issue | Estimated | Actual | Variance |
|-------|-----------|--------|----------|
| SMI-XXX | 10k | 12k | +20% |
| SMI-YYY | 8k | 6k | -25% |

**Average Variance**: +X%
**Calibration Factor**: Adjust future estimates by X%
```

---

## Integration with Linear

When creating Linear issues, include token estimates in the description:

```markdown
## Token Estimate

**Complexity**: Medium
**Estimated Tokens**: 12k
**Recommended Agents**: 1-2

### Breakdown
- Source files (3): 6k
- Test files (2): 4k
- Documentation: 1k
- Buffer (20%): 1k
```

See [Linear Issue Template](../templates/linear-issue-template.md) for the full template.

---

## Related Documentation

- [Wave Completion Checklist](../process/wave-completion-checklist.md)
- [Linear Issue Template](../templates/linear-issue-template.md)
- [Wave 7 Retrospective](../retros/wave-7-multi-language-analysis.md)
- [Swarm Recovery Guide](swarm-recovery.md)

---

*Template version 1.0 - Based on Wave 7 experience and best practices*
