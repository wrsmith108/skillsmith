# Wave 8 Code Review: Post-Wave 7 Changes

**Date**: January 10, 2026
**Reviewer**: Code Review Swarm
**Commits Reviewed**: 7e956cc, 8cbd3c2, 4b5cde7 (+ b039ca9, 8a89c3b)
**Files Changed**: 12 files, +1,457 lines

---

## Executive Summary

This code review covers changes made after Wave 7, including:
- TrustTier type unification (7e956cc)
- Recommend CLI command (8cbd3c2, SMI-1299)
- Tree-sitter WASM research document (4b5cde7, SMI-1347)
- Process improvements (8a89c3b, SMI-1342 to SMI-1346)
- TypeScript cache fix (b039ca9, SMI-1348)

**Overall Assessment**: The implementation code is solid, but the recommend command tests require significant rework. Security posture is good with no vulnerabilities identified.

---

## Review Scores

| Component | Score | Risk | Status |
|-----------|-------|------|--------|
| Recommend CLI Command | 6.5/10 | Medium | Issues Logged |
| TrustTier Type Unification | 8/10 | Low | Approved |
| Research Document (SMI-1347) | 8.5/10 | N/A | Approved |
| Security Assessment | N/A | Low | Passed |
| Process Improvements | 9/10 | Low | Approved |

---

## Critical Issues

### 1. Placeholder Tests in recommend.test.ts (SMI-1353)

**Severity**: Critical
**File**: `packages/cli/tests/recommend.test.ts`

All 50+ tests follow this anti-pattern that passes regardless of actual behavior:

```typescript
it('should auto-detect installed skills', async () => {
  try {
    const cmd = createRecommendCommand()
    expect(cmd).toBeDefined()  // Only checks command exists
  } catch (error) {
    expect(error).toBeDefined()  // PASSES even on failure!
  }
})
```

**Impact**: Zero effective test coverage despite 756 lines of "tests"

**Linear Issue**: [SMI-1353](https://linear.app/smith-horn-group/issue/SMI-1353)

---

## Major Issues

### 2. Unimplemented --no-overlap Option (SMI-1358)

**Severity**: Major
**File**: `packages/cli/src/commands/recommend.ts`

The `--no-overlap` option is declared and parsed but never used in the `runRecommend` function.

**Linear Issue**: [SMI-1358](https://linear.app/smith-horn-group/issue/SMI-1358)

### 3. Duplicate Utility Functions (SMI-1359)

**Severity**: Major
**Files**: Multiple MCP server tools

`mapTrustTierFromDb` and `getTrustBadge` functions are duplicated across:
- search.ts
- recommend.ts
- suggest.ts

**Linear Issue**: [SMI-1359](https://linear.app/smith-horn-group/issue/SMI-1359)

---

## Minor Issues

### 4. Stale Documentation Comment (SMI-1360)

**File**: `packages/mcp-server/src/tools/search.ts`, lines 10-11

Comment references old tier names (`standard`, `unverified`) instead of current (`experimental`, `unknown`).

**Linear Issue**: [SMI-1360](https://linear.app/smith-horn-group/issue/SMI-1360)

### 5. Weak Type for Command Options

**File**: `packages/cli/src/commands/recommend.ts`, line 315

```typescript
opts: Record<string, string | boolean | string[] | undefined>
```

Should use a typed interface for better type safety.

### 6. Hardcoded similarity_score: -1

**File**: `packages/cli/src/commands/recommend.ts`, line 264

Uses magic number -1 for unavailable similarity score. Consider using `null` or optional type.

---

## Security Assessment

### Risk Level: LOW

| Category | Status | Notes |
|----------|--------|-------|
| Input Validation | PASS | Zod schemas + custom validators |
| SQL Injection | PASS | Repository pattern, no raw SQL |
| Command Injection | PASS | No shell execution with user input |
| Path Traversal | LOW RISK | Delegated to CodebaseAnalyzer |
| Sensitive Data | PASS | Proper error sanitization |
| Rate Limiting | PASS | Implemented in suggest tool |

### Positive Security Practices

1. Defense in depth with multiple validation layers
2. Home directories masked in error output
3. TypeScript + Zod for compile-time and runtime validation
4. API credentials handled through abstraction layers
5. Telemetry uses anonymized `distinctId`

---

## TrustTier Unification Assessment

### Type Consistency: PASS

All files now use unified values: `verified`, `community`, `experimental`, `unknown`

### Breaking Changes: LOW RISK

- API consumers filtering by old values (`standard`, `unverified`) will get no results
- Database migration may be required if old values exist
- MCP schema correctly documents valid enum values

---

## Research Document Assessment (SMI-1347)

### Score: 8.5/10

**Strengths**:
- Comprehensive with 15 cited sources
- Clear actionable recommendations
- Real-world implementation references
- Well-structured with summary tables

**Areas for Improvement**:
- Missing security considerations (CSP for WASM)
- Bundle size estimates should pin specific versions
- Lezer comparison could include decision framework

---

## Recommendations

### High Priority

1. **Rewrite recommend tests** (SMI-1353) - Critical for production readiness
2. **Fix or remove --no-overlap** (SMI-1358) - Feature gap
3. **Consolidate duplicate functions** (SMI-1359) - Maintainability

### Medium Priority

4. Add typed options interface for Commander actions
5. Add API timeout configuration to recommend command
6. Add security section to WASM research before browser implementation

### Low Priority

7. Fix stale documentation comment (SMI-1360)
8. Consider `null` instead of magic `-1` for missing values
9. Add connection reuse for API client

---

## Issues Created

| Issue ID | Title | Priority | Est. Tokens |
|----------|-------|----------|-------------|
| SMI-1353 | Rewrite recommend command tests | Critical | 15,000 |
| SMI-1358 | Implement or remove --no-overlap option | High | 5,000 |
| SMI-1359 | Consolidate duplicate TrustTier utilities | Medium | 6,000 |
| SMI-1360 | Fix stale TrustTier documentation | Low | 500 |

**Total Estimated Effort**: ~26,500 tokens

---

## Positive Observations

1. **Clean Code**: Recommend command follows established CLI patterns
2. **Error Handling**: Proper use of `sanitizeError()` throughout
3. **Documentation**: Research document is actionable and well-sourced
4. **Process Improvements**: Pre-commit/pre-push hooks are comprehensive
5. **Type Safety**: TrustTier unification complete and consistent

---

## Conclusion

The core implementation code is solid with good architecture and security practices. The main concern is the recommend command test file which provides false confidence with placeholder assertions. This should be addressed before the feature is considered production-ready.

The TrustTier unification and research document are approved as-is. Process improvements from Wave A+B are excellent additions to the development workflow.

---

**Review Author**: Code Review Swarm
**Review Status**: Complete
**Follow-up Required**: SMI-1353 (Critical)
