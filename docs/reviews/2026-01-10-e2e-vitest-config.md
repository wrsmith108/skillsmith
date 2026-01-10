# Code Review: E2E Vitest Config Fix (SMI-1315)

**Date**: 2026-01-10
**Reviewer**: Claude Code Review Agent
**Related Issues**: SMI-1315, SMI-1312
**Files Changed**: 4 files

## Summary

Fixed E2E test discovery in CI. The E2E test runners were using the main `vitest.config.ts` which has exclude patterns blocking `*.e2e.test.ts` files, causing zero tests to be discovered.

## Root Cause

The main `vitest.config.ts` (line 23) has:
```typescript
exclude: [
  'tests/e2e/**',
  'tests/api/**',
  '**/*.e2e.test.ts',  // <-- This excluded ALL E2E tests
],
```

The E2E test runners (`run-cli-tests.ts`, `run-mcp-tests.ts`) didn't specify a config file, so they used the main config with these exclusions.

## Files Reviewed

| File | Lines Changed | Status |
|------|---------------|--------|
| `scripts/e2e/run-cli-tests.ts` | +2/-1 | PASS |
| `scripts/e2e/run-mcp-tests.ts` | +2/-1 | PASS |
| `vitest-e2e.config.ts` | +28 (new) | PASS |
| `.gitignore` | -3 | PASS |

## Changes Made

### 1. E2E Test Runners
Added `--config=vitest-e2e.config.ts` to both CLI and MCP test runners:

```typescript
// Before
const vitestProcess = spawn('npx', ['vitest', 'run', ...])

// After
const vitestProcess = spawn('npx', [
  'vitest', 'run',
  '--config=vitest-e2e.config.ts',  // SMI-1315
  ...
])
```

### 2. E2E-Specific Vitest Config
Created `vitest-e2e.config.ts` with include patterns for all E2E tests:

```typescript
include: [
  'tests/e2e/**/*.test.ts',
  'packages/cli/tests/e2e/**/*.test.ts',
  'packages/cli/tests/e2e/**/*.e2e.test.ts',
  'packages/mcp-server/tests/e2e/**/*.test.ts',
  'packages/mcp-server/tests/e2e/**/*.e2e.test.ts',
],
```

### 3. Removed from .gitignore
The file was previously gitignored with comment "optional, not needed for CI" - this was incorrect.

## Review Categories

### Backward Compatibility
- **Status**: PASS
- **Notes**: No breaking changes. Main test suite unaffected.

### Best Practices
- **Status**: PASS
- **Notes**: Separation of config for unit tests vs E2E tests.

### Documentation
- **Status**: PASS
- **Notes**: JSDoc comments explain the purpose.

## Test Results

**Before fix**: 0 tests discovered, exit code 1
**After fix**: 60 tests discovered, 46 passed, 14 skipped, 0 failed

## CI Verification

| Workflow | Status | Duration |
|----------|--------|----------|
| CI | ✅ Passing | 13m3s |
| E2E Tests | ✅ Passing | 13m50s |

## Overall Result

**PASS** - All checks passed, CI green.

## References

- [SMI-1315](https://linear.app/smith-horn-group/issue/SMI-1315) - E2E test discovery fix
- [SMI-1312](https://linear.app/smith-horn-group/issue/SMI-1312) - Exclude E2E from main test run
