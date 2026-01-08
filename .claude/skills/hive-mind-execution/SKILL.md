---
name: "Hive Mind Execution"
description: "Execute Linear issues or tasks using hive mind orchestration with parallel agents, code review, and documentation updates. Use for phase execution, epic completion, or complex multi-task work."
---

# Hive Mind Execution Skill

Orchestrates complex task execution using claude-flow hive mind with automatic code review and documentation updates.

## Trigger Phrases

- "execute SMI-xxx with hive mind"
- "run phase X with hive mind"
- "execute this epic"
- "orchestrate these tasks"
- "parallel execution with review"

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    HIVE MIND EXECUTION                          │
├─────────────────────────────────────────────────────────────────┤
│  1. INITIALIZE    │  swarm_init with topology                   │
│  2. PLAN          │  TodoWrite with all tasks batched           │
│  3. EXECUTE       │  Parallel implementation                    │
│  4. REVIEW        │  Code review → docs/reviews/ (MANDATORY)    │
│  5. FIX           │  Address review findings                    │
│  5.5 GOVERNANCE   │  BLOCKING standards audit gate              │
│  6. RETRO         │  PROJECT PHASES ONLY (skip if mid-phase)    │
│  7. DOCUMENT      │  ADR, Linear update, CLAUDE.md              │
│  8. CLEANUP       │  swarm_destroy, mark issues done            │
└─────────────────────────────────────────────────────────────────┘

Key:
- Phase 4: Reviews written to docs/reviews/YYYY-MM-DD-<feature>.md
- Phase 6: Only at end of project phases, not every hive mind wave
- Linear issues: Must include details, links, and labels
```

## Phase 1: Initialize Hive Mind

```javascript
// Initialize swarm with appropriate topology
mcp__claude-flow__swarm_init({
  topology: "hierarchical",  // or "mesh", "ring", "star"
  maxAgents: 6,
  strategy: "balanced"
})
```

**Topology Selection Guide**:

| Topology | Use Case |
|----------|----------|
| `hierarchical` | Complex epics with dependencies |
| `mesh` | Independent parallel tasks |
| `star` | Central coordinator with workers |
| `ring` | Sequential pipeline processing |

## Phase 2: Plan with TodoWrite

**CRITICAL**: Batch ALL todos in a single call:

```javascript
TodoWrite([
  { content: "Task 1 description", status: "in_progress", activeForm: "Working on task 1" },
  { content: "Task 2 description", status: "pending", activeForm: "Working on task 2" },
  { content: "Task 3 description", status: "pending", activeForm: "Working on task 3" },
  // ... all tasks
  { content: "Run code review", status: "pending", activeForm: "Running code review" },
  { content: "Update documentation", status: "pending", activeForm: "Updating documentation" }
])
```

## Phase 3: Parallel Execution

Execute independent tasks in parallel using file operations:

```javascript
// Single message with all parallel operations
[Parallel]:
  Edit("file1.ts", changes)
  Edit("file2.ts", changes)
  Write("new-file.ts", content)
  Bash("npm run typecheck")
```

**Rules**:
- Group independent operations in single message
- Update TodoWrite status as tasks complete
- Mark tasks `completed` immediately when done

## Phase 4: Code Review

**MANDATORY**: Run code review after ANY code changes. Reviews are written to `docs/reviews/`.

### 4.1 Create Code Review Document

Write review to `docs/reviews/YYYY-MM-DD-<feature-or-issue>.md`:

```markdown
# Code Review: [Feature/Issue Name]

**Date**: YYYY-MM-DD
**Reviewer**: Claude Code Review Agent
**Related Issues**: SMI-XXX, SMI-YYY
**Files Changed**: X files

## Summary
[Brief description of changes reviewed]

## Files Reviewed
| File | Lines Changed | Status |
|------|---------------|--------|
| `src/path/file.ts` | +45/-12 | PASS |
| `tests/path/file.test.ts` | +30/-0 | PASS |

## Review Categories

### Security
- **Status**: PASS/WARN/FAIL
- **Findings**: [List any issues]
- **Recommendations**: [List fixes if needed]

### Error Handling
- **Status**: PASS/WARN/FAIL
- **Findings**: [List any issues]

### Backward Compatibility
- **Status**: PASS/WARN/FAIL
- **Breaking Changes**: [List if any]

### Best Practices
- **Status**: PASS/WARN/FAIL
- **Findings**: [List any issues]

### Documentation
- **Status**: PASS/WARN/FAIL
- **Missing Docs**: [List if any]

## Overall Result
- **PASS**: All checks passed, ready for merge
- **WARN**: Minor issues, can proceed with notes
- **FAIL**: Blocking issues must be fixed

## Action Items
| Item | Priority | Assignee |
|------|----------|----------|
| [Fix description] | High/Medium/Low | Developer |

## References
- [Related ADR](../adr/XXX-decision.md)
- [Standards Reference](../architecture/standards.md#section)
```

### 4.2 Spawn Code Review Agent

```javascript
Task({
  description: "Code review changes",
  prompt: `Review the following changes and write results to docs/reviews/:

    1. Security issues (env var handling, secrets exposure)
    2. Error handling completeness
    3. Backward compatibility
    4. Best practices adherence
    5. Documentation completeness

    IMPORTANT:
    - Write the full review to docs/reviews/YYYY-MM-DD-<feature>.md
    - Include links to relevant files and line numbers
    - Provide PASS/WARN/FAIL status for each category
    - List specific action items with priorities`,
  subagent_type: "general-purpose"
})
```

**Review Checklist**:
- [ ] Security: No hardcoded secrets, proper validation
- [ ] Error handling: Graceful failures, clear messages
- [ ] Compatibility: No breaking changes without documentation
- [ ] Best practices: TypeScript strict, proper typing
- [ ] Documentation: Comments where needed, types exported
- [ ] **Review document written to docs/reviews/**

## Phase 5: Fix Review Findings

Address any "Must Fix" items from review:

```javascript
// Fix issues identified in review
Edit("file.ts", old_string, new_string)

// Verify fixes
Bash("npm run typecheck && npm run lint")
```

### 5.1 Run Governance Audit

After addressing review findings, run the governance audit:

```bash
# Run governance standards check
docker exec skillsmith-dev-1 npm run audit:standards
```

This ensures all fixes meet engineering standards before proceeding.

## Phase 5.5: Governance Gate (BLOCKING)

**MANDATORY**: Before retrospective, verify all standards are met. **Workflow STOPS here until PASS.**

```javascript
// Invoke governance skill - BLOCKS until passing
Task({
  description: "Governance code review audit",  // Triggers PostToolUse hook
  prompt: `Run full governance check:
    1. Execute: docker exec skillsmith-dev-1 npm run audit:standards
    2. Verify all standards from standards.md are met
    3. Report PASS/FAIL with specific violations if any

    BLOCKING: Cannot proceed to Phase 6 until all checks PASS.
    If violations found, list specific files and fixes required.`,
  subagent_type: "general-purpose"
})
```

**Gate Requirements** (all must pass):
- [ ] No TypeScript strict mode violations
- [ ] All files under 500 lines
- [ ] 99%+ test coverage maintained
- [ ] No hardcoded secrets
- [ ] Conventional commit format ready

**On Failure**: Fix all violations, then re-run governance audit.

## Phase 6: Retrospective (PROJECT PHASES ONLY)

> **IMPORTANT**: Retrospectives are conducted ONLY at the end of a **project phase**, NOT after every hive mind wave. Skip this phase if you're in the middle of a larger project phase.

### 6.0 Check if Retrospective is Required

```javascript
AskUserQuestion({
  questions: [{
    question: "Is this the end of a project phase (not just a hive mind wave)?",
    header: "Retro Check",
    multiSelect: false,
    options: [
      { label: "Yes - End of phase", description: "This completes a major project milestone (e.g., Phase 2a, Phase 3b)" },
      { label: "No - Continue work", description: "This is just one wave of work within an ongoing phase - skip retro" }
    ]
  }]
})
```

**If "No - Continue work"**: Skip to Phase 7 (Documentation) or Phase 8 (Cleanup).

**If "Yes - End of phase"**: Proceed with retrospective below.

### 6.1 Write Retrospective

Write to `docs/retros/<phase-name>.md` (e.g., `docs/retros/phase-2a-github-indexing.md`):

```markdown
# [Phase/Feature] Retrospective

**Date**: YYYY-MM-DD
**Duration**: [time spent]

## Summary
[Brief description of what was accomplished]

## Metrics
| Metric | Value |
|--------|-------|
| Files Changed | X |
| Lines Added | X |
| Issues Completed | X |

## What Went Well
1. [Success 1]
2. [Success 2]

## What Could Be Improved
1. [Issue 1]
2. [Issue 2]

## Lessons Learned
1. [Lesson 1]
2. [Lesson 2]

## Next Steps
| Item | Priority | Description |
|------|----------|-------------|
| [Item 1] | High/Medium/Low | [Description] |
| [Item 2] | High/Medium/Low | [Description] |
```

### 6.2 Handle Next Steps

**REQUIRED**: After identifying next steps, prompt the user:

```javascript
AskUserQuestion({
  questions: [{
    question: "How would you like to handle the next steps from the retrospective?",
    header: "Next Steps",
    multiSelect: false,
    options: [
      { label: "Add all to Linear", description: "Create Linear issues for all next steps identified" },
      { label: "Select which to add", description: "Review each item and choose which to create as issues" },
      { label: "Skip for now", description: "Don't create any issues - document only" }
    ]
  }]
})
```

**If "Add all to Linear"**: Create detailed issues with proper structure.

### 6.3 Create Detailed Linear Issues

**REQUIRED**: All Linear issues must include:
- **Detailed description** with context and acceptance criteria
- **Links to resources** (code files, docs, ADRs, reviews)
- **Labels** (priority, type, component)

```javascript
// Create detailed issues for each next step
for (const item of nextSteps) {
  const description = `
## Context
${item.context || 'Identified during retrospective for ' + phaseName}

## Acceptance Criteria
${item.acceptanceCriteria || '- [ ] Criteria to be defined'}

## Technical Details
${item.technicalDetails || 'See related resources below'}

## Resources
- [Retrospective](docs/retros/${phaseName}.md)
- [Code Review](docs/reviews/${reviewDate}-${feature}.md)
${item.relatedADR ? `- [ADR](docs/adr/${item.relatedADR}.md)` : ''}
${item.relatedFiles ? item.relatedFiles.map(f => `- [${f}](${f})`).join('\n') : ''}

## Labels
- Priority: ${item.priority}
- Type: ${item.type || 'enhancement'}
- Component: ${item.component || 'core'}
`;

  // Use Linear GraphQL mutation for full control
  Bash(`varlock run -- npx tsx ~/.claude/skills/linear/skills/linear/scripts/linear-ops.ts create-issue \
    --title "${item.title}" \
    --description "${description}" \
    --priority ${item.priority} \
    --labels "${item.labels?.join(',') || 'enhancement'}"`)
}
```

**Issue Template Fields**:

| Field | Required | Example |
|-------|----------|---------|
| Title | Yes | "Implement caching layer for search results" |
| Description | Yes | Context, acceptance criteria, technical details |
| Priority | Yes | urgent, high, medium, low |
| Labels | Yes | enhancement, bug, security, performance |
| Component | Recommended | core, mcp-server, cli |
| Related Issues | If applicable | SMI-123, SMI-456 |
| Resources | Yes | Links to retro, review, ADRs, code files |

**If "Select which to add"**:

```javascript
AskUserQuestion({
  questions: [{
    question: "Which next steps should be added to Linear?",
    header: "Select Items",
    multiSelect: true,
    options: nextSteps.map(item => ({
      label: item.title,
      description: `${item.priority} priority - ${item.description}`
    }))
  }]
})
// Then create issues for selected items using the detailed template above
```

### 6.4 Link Issues to Retrospective

After creating issues, update the retrospective with issue links:

```javascript
// Append issue links to retrospective
Edit("docs/retros/<phase>.md",
  "## Next Steps",
  `## Next Steps

### Created Issues
| Issue | Title | Priority | Status |
|-------|-------|----------|--------|
| [SMI-XXX](https://linear.app/team/SMI-XXX) | ${item.title} | ${item.priority} | Created |

### Original Next Steps`
)
```

## Phase 7: Documentation Updates

### 7.1 Create/Update ADR (if architectural decision)

```markdown
# ADR-0XX: [Title]

**Status**: Accepted
**Date**: YYYY-MM-DD
**Related Issues**: SMI-XXX

## Context
[Problem that motivated the decision]

## Decision
[What we decided and why]

## Consequences
### Positive
### Negative
### Neutral

## Lessons Learned
[Pattern for future reference]
```

### 7.2 Update ADR Index

```javascript
Edit("docs/adr/index.md",
  "| [ADR-011]...",
  "| [ADR-011]...\n| [ADR-012](012-new-adr.md) | Title | Accepted | DATE |"
)
```

### 7.3 Create Linear Project Update

```javascript
// GraphQL mutation for project update
mutation {
  projectUpdateCreate(input: {
    projectId: "PROJECT_ID",
    body: "## Summary\n\n### Completed\n- Item 1\n- Item 2"
  }) {
    success
    projectUpdate { url }
  }
}
```

### 7.4 Update CLAUDE.md (High-Level Only)

**Policy**: CLAUDE.md should remain high-level. Push details to skills/ADRs.

**What belongs in CLAUDE.md**:
- New command (1 line) + link to skill/doc
- Brief pointer to new capability (1-2 sentences max)

**What does NOT belong**:
- Detailed usage instructions → Skill
- Decision rationale → ADR
- Configuration options → `.env.schema` or skill
- Environment variables → `.env.schema` (security risk in markdown)
- Examples beyond 1-2 lines → Skill

**Template for CLAUDE.md updates**:

```markdown
### [Feature Name]

Brief description. See [Skill Name](path/to/SKILL.md) for details.
```

**Security**: Never document env var values in markdown. Reference `.env.schema` instead.

## Phase 8: Cleanup

```javascript
// Destroy swarm
mcp__claude-flow__swarm_destroy({ swarmId: "swarm_xxx" })

// Mark Linear issue done
Bash("npm run linear:done ENG-XXX")
```

## Quick Start Template

For executing a Linear issue with hive mind:

```
1. Read the Linear issue: ENG-XXX
2. Initialize hive mind: swarm_init({ topology: "hierarchical" })
3. Create todos: TodoWrite with all tasks from issue
4. Execute in parallel where possible
5. Run code review with Task agent
6. Fix any "Must Fix" items
7. Write retrospective with lessons learned and next steps
8. Prompt user: Add all / Select / Skip next steps for Linear
9. Create ADR if architectural decision
10. Create Linear project update
11. Update CLAUDE.md if new patterns
12. Cleanup: swarm_destroy, linear:done
```

## Example: Execute ENG-123

```
User: execute ENG-123 with hive mind

Claude:
1. [Read ENG-123 to understand tasks]
2. [swarm_init with hierarchical topology]
3. [TodoWrite with 8 tasks from issue]
4. [Parallel edits to relevant files]
5. [Task agent for code review]
6. [Fix any review findings]
7. [Write retrospective to docs/retros/]
8. [Ask user: "How would you like to handle the 3 next steps?"]
   User selects: "Add all to Linear"
9. [Create 3 Linear issues for next steps]
10. [Create ADR if needed]
11. [Create Linear project update]
12. [Update CLAUDE.md if new patterns]
13. [swarm_destroy, linear:done ENG-123]
```

## Best Practices

### DO
- Batch all todos in single TodoWrite call
- Execute independent tasks in parallel
- Run code review after implementation
- Document lessons learned in ADR
- Update Linear with project status
- **ALWAYS run code review before any commit/push**

### DON'T
- Create todos one at a time
- Execute sequentially when parallel is possible
- Skip code review
- Leave documentation stale
- Forget to mark issues done
- **NEVER commit or push without completing code review first**

## ⚠️ MANDATORY: Code Review Before Push

**CRITICAL REQUIREMENT**: Always run a code review before committing or pushing any changes.

### Code Review Gate

Before ANY commit or push operation, you MUST:

1. **Run typecheck**: `docker exec skillsmith-dev-1 npm run typecheck`
2. **Run tests**: `docker exec skillsmith-dev-1 npm test`
3. **Execute code review** using the [GitHub Code Review Skill](../github-code-review/SKILL.md)

### Code Review Checklist

```javascript
// REQUIRED before commit/push
Task({
  description: "Code review before push",
  prompt: `Perform comprehensive code review:

    ## Security
    - [ ] No hardcoded secrets or API keys
    - [ ] Proper input validation
    - [ ] No SQL injection vulnerabilities
    - [ ] SSRF/path traversal prevention

    ## Quality
    - [ ] All tests pass
    - [ ] TypeScript strict compliance
    - [ ] Error handling complete
    - [ ] No breaking changes without documentation

    ## Documentation
    - [ ] Public APIs documented
    - [ ] ADR created for architectural decisions
    - [ ] Linear issues updated

    Provide: PASS, WARN (with items), or FAIL (with blockers)`,
  subagent_type: "general-purpose"
})
```

### Review Status Requirements

| Status | Can Push? | Action Required |
|--------|-----------|-----------------|
| PASS | ✅ Yes | Proceed with commit/push |
| WARN | ⚠️ Conditional | Fix warnings or document as known issues |
| FAIL | ❌ No | Must fix blockers before push |

### Quick Review Command

```bash
# Run quick pre-push checks
docker exec skillsmith-dev-1 npm run typecheck && \
docker exec skillsmith-dev-1 npm test && \
echo "✅ Ready for code review"
```

See [GitHub Code Review Skill](../github-code-review/SKILL.md) for detailed review patterns.

## Configuration

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `LINEAR_API_KEY` | Linear API access for updates |
| `LINEAR_PROJECT_ID` | Target project for updates |

### Dependencies

- claude-flow (local devDependency)
- Linear API access
- Docker (for consistent execution)

## Hive Mind Orchestrator Commands

### Docker Execution (Recommended)

```bash
docker compose --profile orchestrator up

# With options
docker compose --profile orchestrator run --rm orchestrator \
  npx tsx scripts/phase4-orchestrator/orchestrator.ts --dry-run
```

### Local Execution

```bash
cd scripts/phase4-orchestrator
./run.sh              # Full execution
./run.sh --dry-run    # Preview without changes
./run.sh --start-from 2  # Resume from epic 2
```

> **Note**: Local execution requires Node.js 22+. Run `npm rebuild` after Node version changes.

### Environment Variables

Environment variables are defined in `.env.schema` and managed via Varlock.
See `skillsmith/.env.schema` for available variables.

**Never document env var values in markdown files.**

## Related Skills

- [Governance](../governance/SKILL.md) - Standards enforcement
- [Swarm Orchestration](../swarm-orchestration/SKILL.md) - Advanced swarm patterns
- [Worktree Manager](../worktree-manager/SKILL.md) - Parallel development

## References

- [ADR-012: Native Module Version Management](../../../docs/adr/012-native-module-version-management.md)
- [claude-flow Documentation](https://github.com/ruvnet/claude-flow)
- [Linear API](https://developers.linear.app/docs/graphql/working-with-the-graphql-api)
