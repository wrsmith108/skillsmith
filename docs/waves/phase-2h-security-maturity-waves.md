# Phase 2h: Consolidated Hive Mind Waves

**Status**: Ready for Execution
**Executor**: Hive Mind Orchestrator
**Last Updated**: 2026-01-04

---

## Overview

Consolidated waves prioritized from Critical/High down, grouping issues that can be executed together by hive mind. Waves requiring manual steps are deferred.

---

## Wave 4: Critical Code Quality ✅ COMPLETE

**Priority**: P1-P2 (High)
**Estimated Effort**: Medium
**Dependencies**: None
**Completed**: 2026-01-03

### Objectives

Fix critical code quality issues from code review findings.

### Issues

| Issue | Title | Priority | Status |
|-------|-------|----------|--------|
| SMI-879 | [HIGH] Code Duplication in GitHub Fetch Functions | P2 | ✅ Done |
| SMI-880 | [HIGH] No Retry Logic for Transient Network Failures | P2 | ✅ Done |
| SMI-881 | [HIGH] Insufficient Error Propagation | P2 | ✅ Done |
| SMI-983 | Fix flaky ROIDashboardService.refreshMetrics test | P3 | ✅ Done |

### Code Review Sub-Issues (Created & Completed)

| Issue | Title | Priority | Status |
|-------|-------|----------|--------|
| SMI-1024 | Fix browser UTF-8 decoding in decodeBase64Content | P0 | ✅ Done |
| SMI-1025 | Remove unreachable RetryExhaustedError dead code | P1 | ✅ Done |
| SMI-1026 | Add unit tests for shared.ts source utilities | P1 | ✅ Done |
| SMI-1027 | Add tests for fetchWithRetry and parseRetryAfter | P1 | ✅ Done |
| SMI-1028 | Align ApiError rate limit code with isRateLimitError | P2 | ✅ Done |
| SMI-1029 | Document double-delay behavior in fetchWithRetry | P2 | ✅ Done |
| SMI-1030 | Apply consistent fake timer usage in tests | P2 | ✅ Done |
| SMI-1031 | Resolve SkillsmithError dual export naming | P2 | ✅ Done |

### Results

- **Tests**: 2,446 → 2,522 (+76 new tests)
- **Files Created**: `shared.ts`, `SkillsmithError.ts`, `retry.ts`, `shared.test.ts`
- **All 12 issues completed**

### Implementation Notes

**Code Duplication (SMI-879)**:
- Extract shared fetch logic into `packages/core/src/utils/github-client.ts`
- Create `GitHubClient` class with common methods
- Update all GitHub fetch functions to use shared client

**Retry Logic (SMI-880)**:
- Add exponential backoff retry wrapper
- Configure: 3 retries, 1s initial delay, 2x backoff
- Handle transient errors: ETIMEDOUT, ECONNRESET, 5xx responses

**Error Propagation (SMI-881)**:
- Wrap errors with context at each layer
- Use custom error classes with cause chaining
- Preserve stack traces

**Flaky Test (SMI-983)**:
- Use fake timers like UsageTracker test fix
- Remove timing dependencies

### Hive Mind Execution

```bash
./claude-flow sparc run orchestrator "Execute Wave 4: Critical Code Quality. Fix issues SMI-879, SMI-880, SMI-881, SMI-983. Focus on GitHub fetch refactoring, retry logic, error propagation, and flaky test fix."
```

---

## Wave 5: CI/DevOps Hardening ✅ COMPLETE

**Priority**: P2-P3 (Medium-High)
**Estimated Effort**: Medium
**Dependencies**: Wave 4 complete
**Completed**: 2026-01-03

### Objectives

Improve CI/CD pipeline reliability and security.

### Issues

| Issue | Title | Priority | Status |
|-------|-------|----------|--------|
| SMI-1021 | Add continuous security scanning in CI | P3 | ✅ Done |
| SMI-993 | Document continue-on-error usage | P3 | ✅ Done |
| SMI-994 | Optimize Dockerfile for production (75→95) | P3 | ✅ Done |
| SMI-995 | ci-doctor: Fix false positives on commented npm ci | P3 | ✅ Done |
| SMI-996 | ci-doctor: Improve continue-on-error detection | P3 | ✅ Done |

### Results

- **Security workflow**: Created `.github/workflows/security.yml` with CodeQL + npm audit
- **Documentation**: Created `docs/ci/continue-on-error-policy.md` and `docs/ci/index.md`
- **Dockerfile**: Multi-stage build, non-root user, health checks, ~50% size reduction
- **ci-doctor**: Fixed comment detection, added categorized continue-on-error analysis

### Implementation Notes

**CI Security Scanning (SMI-1021)**:
```yaml
# .github/workflows/security.yml
security-scan:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Run npm audit
      run: npm audit --audit-level=high
    - name: Run CodeQL
      uses: github/codeql-action/analyze@v3
```

**Dockerfile Optimization (SMI-994)**:
- Multi-stage build
- Non-root user
- Health checks
- Layer optimization

### Hive Mind Execution

```bash
./claude-flow sparc run orchestrator "Execute Wave 5: CI/DevOps Hardening. Fix issues SMI-1021, SMI-993, SMI-994, SMI-995, SMI-996. Add CodeQL scanning, document continue-on-error, optimize Dockerfile, fix ci-doctor false positives."
```

---

## Wave 6: Skill Enhancements ✅ COMPLETE

**Priority**: P3 (Medium)
**Estimated Effort**: Low-Medium
**Dependencies**: None (can run parallel with Wave 5)
**Completed**: 2026-01-03

### Objectives

Add enhancements to CI/DevOps skills.

### Issues

| Issue | Title | Priority | Status |
|-------|-------|----------|--------|
| SMI-997 | flaky-test-detector: Add --min-severity flag | P3 | ✅ Done |
| SMI-998 | flaky-test-detector: Add --exclude pattern | P3 | ✅ Done |
| SMI-999 | docker-optimizer: Add multi-Dockerfile support | P3 | ✅ Done |
| SMI-1000 | version-sync: Add --json output flag | P3 | ✅ Done |

### Results

- **flaky-test-detector**: Added `--min-severity` (low/medium/high/critical) and `--exclude` glob patterns
- **docker-optimizer**: Added `-f`/`--file` and `--all` for multi-Dockerfile analysis
- **version-sync**: Added `--json` output for CI integration

### Implementation Notes

All skill enhancements follow the same pattern:
1. Add CLI flag parsing
2. Update script logic
3. Add tests
4. Update SKILL.md documentation

### Hive Mind Execution

```bash
./claude-flow sparc run orchestrator "Execute Wave 6: Skill Enhancements. Fix issues SMI-997, SMI-998, SMI-999, SMI-1000. Add CLI flags to flaky-test-detector, docker-optimizer, and version-sync skills."
```

---

## Wave 7: Observability & Documentation ✅ COMPLETE

**Priority**: P3 (Medium)
**Estimated Effort**: Medium
**Dependencies**: Wave 4-5 complete (needs stable codebase)
**Completed**: 2026-01-04

### Objectives

Add metrics export and update documentation.

### Issues

| Issue | Title | Priority | Status |
|-------|-------|----------|--------|
| SMI-1018 | Add metrics export for monitoring dashboards | P3 | ✅ Done |
| SMI-1019 | Create runbook for audit log retention policy | P3 | ✅ Done |
| SMI-972 | Update ADR-002 for Node.js 22 upgrade | P3 | ✅ Done (2026-01-03) |

### Results

- **Prometheus exporter**: Created `packages/core/src/telemetry/prometheus.ts`
- **Runbook**: Created `docs/runbooks/audit-log-retention.md`
- **ADR-002**: Already updated on 2026-01-03 for Node.js 22

### Implementation Notes

**Metrics Export (SMI-1018)**:
- Created `exportToPrometheus()` - converts MetricsSnapshot to Prometheus text format
- Created `getPrometheusMetrics()` - convenience function for HTTP handlers
- Created `createPrometheusHandler()` - Express/Koa-compatible HTTP handler
- Exports all MetricsRegistry metrics (counters, histograms, gauges)

**Runbook (SMI-1019)**:
- Documented MIN/MAX retention (1-3650 days)
- Included cleanup procedures and scheduling
- Added monitoring metrics and health checks
- Covered troubleshooting and security considerations

### Hive Mind Execution

```bash
./claude-flow sparc run orchestrator "Execute Wave 7: Observability & Documentation. Fix issues SMI-1018, SMI-1019, SMI-972. Add Prometheus metrics export, create audit log runbook, update ADR-002 for Node.js 22."
```

---

## Wave 8: Security Maturity ✅ COMPLETE

**Priority**: P3 (Medium)
**Estimated Effort**: High
**Dependencies**: Wave 7 complete
**Completed**: 2026-01-04

### Objectives

Establish formal security processes and comprehensive testing.

### Issues

| Issue | Title | Priority | Status |
|-------|-------|----------|--------|
| SMI-1022 | Implement formal threat modeling process | P3 | ✅ Done |
| SMI-1023 | Create security-focused E2E test suite | P3 | ✅ Done |
| SMI-869 | Create search quality test suite | P2 | ✅ Done |

### Results

- **Threat Model**: Created `docs/security/threat-model.md` with STRIDE analysis
- **Security E2E Tests**: Created `packages/core/tests/e2e/security/security.e2e.test.ts`
- **Search Quality Tests**: Created `packages/core/tests/SearchQuality.test.ts`
- **Tests**: 2,522 → 2,571 (+49 new tests)

### Implementation Notes

**Threat Modeling (SMI-1022)**:
- Created comprehensive STRIDE-based threat model
- Documented trust boundaries and data flows
- Mapped all threats to existing mitigations
- Included compliance mapping (OWASP Top 10)

**Security E2E Tests (SMI-1023)**:
- SSRF prevention tests (IPv4/IPv6/localhost)
- Path traversal prevention tests
- Rate limiting tests (sequential and concurrent)
- Audit log integrity tests
- Security scanner integration tests

**Search Quality Tests (SMI-869)**:
- Relevance ranking tests
- Query normalization tests (case, whitespace, special chars)
- Edge case handling (empty, short, long queries)
- Filter combination tests
- Pagination tests
- Performance baseline tests (<50ms)

### Hive Mind Execution

```bash
./claude-flow sparc run orchestrator "Execute Wave 8: Security Maturity. Fix issues SMI-1022, SMI-1023, SMI-869. Create STRIDE threat model, security E2E tests, and search quality tests."
```

---

## Deferred (Manual Steps Required)

These issues require manual intervention and are not suitable for hive mind automation:

| Issue | Title | Reason |
|-------|-------|--------|
| SMI-878 | Create GitHub App for Skill Discovery | Requires GitHub UI, OAuth setup |
| SMI-1020 | Redis backend for distributed rate limiting | Requires Redis infrastructure |
| SMI-922 | Mock GitHub API for Import E2E Tests | May need external service |
| SMI-872 | Create security quarantine report | Requires manual security review |

---

## Canceled (Superseded)

| Issue | Title | Reason |
|-------|-------|--------|
| SMI-991 | [Orchestration] Hive Mind CI/DevOps Skill Implementation | Superseded by Wave 5-6 |
| SMI-1001 | [Orchestration] Wave 1: Critical Security & Test Reliability | Superseded by Wave 4 |
| SMI-1002 | [Orchestration] Wave 2: CI/CD & Infrastructure Hardening | Superseded by Wave 5 |
| SMI-1003 | [Orchestration] Wave 3: CI/DevOps Skill v1.1 Enhancements | Superseded by Wave 6 |

---

## Execution Order

```
Wave 4 (Critical Code Quality) ──┐
                                 ├──► Wave 7 (Observability) ──► Wave 8 (Security Maturity)
Wave 5 (CI/DevOps Hardening) ────┤
                                 │
Wave 6 (Skill Enhancements) ─────┘  (parallel with Wave 5)
```

---

## Summary

| Wave | Issues | Priority | Status |
|------|--------|----------|--------|
| Wave 4 | SMI-879, SMI-880, SMI-881, SMI-983 + 8 sub-issues | P2 | ✅ Complete |
| Wave 5 | SMI-1021, SMI-993, SMI-994, SMI-995, SMI-996 | P3 | ✅ Complete |
| Wave 6 | SMI-997, SMI-998, SMI-999, SMI-1000 | P3 | ✅ Complete |
| Wave 7 | SMI-1018, SMI-1019, SMI-972 | P3 | ✅ Complete |
| Wave 8 | SMI-1022, SMI-1023, SMI-869 | P3 | ✅ Complete |
| Deferred | SMI-878, SMI-1020, SMI-922, SMI-872 | - | Manual |

**Total Active Issues**: 18
**Total Deferred**: 4
**Total Canceled**: 4

---

## Quick Start

```bash
# Execute waves sequentially
./claude-flow sparc run orchestrator "Execute Wave 4" && \
./claude-flow sparc run orchestrator "Execute Wave 5" && \
./claude-flow sparc run orchestrator "Execute Wave 6" && \
./claude-flow sparc run orchestrator "Execute Wave 7" && \
./claude-flow sparc run orchestrator "Execute Wave 8"

# Or execute Wave 4 and 5 in parallel, then 6, then 7, then 8
./claude-flow swarm "Execute Waves 4-5 in parallel from docs/waves/phase-2h-security-maturity-waves.md" --strategy development --mode hierarchical --max-agents 6
```

---

## References

- [Phase 2g Retrospective](../retros/phase-2g-security-code-review-waves.md)
- [Security Standards](../security/index.md)
- [Rate Limiter Implementation](../../packages/core/src/security/RateLimiter.ts)
