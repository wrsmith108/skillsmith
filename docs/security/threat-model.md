# Skillsmith Threat Model

**SMI-1022**: Formal STRIDE-based threat modeling for Skillsmith.

**Version**: 1.0
**Status**: Active
**Last Updated**: 2026-01-04

---

## Overview

This document applies the STRIDE methodology to identify, categorize, and mitigate security threats in Skillsmith. STRIDE stands for:

- **S**poofing - Identity attacks
- **T**ampering - Data modification attacks
- **R**epudiation - Deniability attacks
- **I**nformation Disclosure - Data leakage attacks
- **D**enial of Service - Availability attacks
- **E**levation of Privilege - Authorization attacks

---

## System Context

### Trust Boundaries

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              UNTRUSTED                                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │  External URLs  │  │  GitHub API     │  │  User-Provided Skill Files  │  │
│  └────────┬────────┘  └────────┬────────┘  └──────────────┬──────────────┘  │
│           │                    │                          │                  │
│    ═══════╪════════════════════╪══════════════════════════╪═════════════    │
│    TRUST BOUNDARY              │                          │                  │
│    ═══════╪════════════════════╪══════════════════════════╪═════════════    │
│           ▼                    ▼                          ▼                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                        Skillsmith Core                               │    │
│  │  ┌─────────────┐  ┌────────────────┐  ┌──────────────────────────┐  │    │
│  │  │ URL Validate│  │ Source Adapters│  │ Security Scanner         │  │    │
│  │  │ (SSRF)      │  │ (Rate Limited) │  │ (Content Analysis)       │  │    │
│  │  └─────────────┘  └────────────────┘  └──────────────────────────┘  │    │
│  │  ┌─────────────────────────────────────────────────────────────────┐│    │
│  │  │                  SQLite Database (Parameterized)                ││    │
│  │  └─────────────────────────────────────────────────────────────────┘│    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│           │                                                                  │
│    ═══════╪═════════════════════════════════════════════════════════════    │
│    TRUST BOUNDARY                                                            │
│    ═══════╪═════════════════════════════════════════════════════════════    │
│           ▼                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    MCP Client (Claude Code)                          │    │
│  │                         TRUSTED                                      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Skill Discovery**: GitHub API → Source Adapter → Parser → Database
2. **Skill Search**: User Query → SearchService → Database → Results
3. **Skill Install**: Database → Filesystem → Claude Code Skills Directory
4. **URL Fetch**: External URL → URL Validator → HTTP Client → Content Parser

---

## STRIDE Analysis

### S - Spoofing

| Threat ID | Description | Asset | Mitigation | Status |
|-----------|-------------|-------|------------|--------|
| S-001 | Attacker impersonates trusted skill author | Skill trust tier | Trust tier verification, author signing | ⚠️ Partial |
| S-002 | Attacker creates fake GitHub repository | Skill source | GitHub API authentication, repository verification | ✅ Mitigated |
| S-003 | MCP client spoofing | MCP communication | stdio transport (local only) | ✅ Mitigated |

#### S-001: Author Impersonation

**Risk**: Medium
**Impact**: Users may install malicious skills believing they're from trusted authors.

**Current Mitigations**:
- Trust tier system (verified, community, experimental, unknown)
- Quality scoring based on repository metrics

**Recommended Improvements**:
- Add cryptographic signing for verified skills
- Implement author verification via GitHub OAuth

#### S-002: Fake Repository

**Risk**: Low
**Impact**: Malicious content indexed as legitimate skill.

**Mitigations**:
- GitHub API authentication required
- Repository metadata validation
- Star count and activity requirements for higher trust tiers

---

### T - Tampering

| Threat ID | Description | Asset | Mitigation | Status |
|-----------|-------------|-------|------------|--------|
| T-001 | SQL injection in search queries | Database | Parameterized queries | ✅ Mitigated |
| T-002 | Skill content modification in transit | Skill files | HTTPS enforcement | ✅ Mitigated |
| T-003 | Local database tampering | SQLite file | Filesystem permissions | ✅ Mitigated |
| T-004 | Cache poisoning | Search cache | TTL-based expiration, cache validation | ✅ Mitigated |

#### T-001: SQL Injection

**Risk**: Critical (if unmitigated)
**Impact**: Full database compromise.

**Mitigations**:
- All queries use parameterized statements via better-sqlite3
- Input validation with Zod schemas
- No dynamic SQL construction

**Verification**: See `packages/core/tests/security/sql-injection.test.ts`

#### T-004: Cache Poisoning

**Risk**: Medium
**Impact**: Stale or malicious data served from cache.

**Mitigations**:
- TTL-based cache expiration (default: 60 seconds)
- SHA-256 content hashing for validation
- Cache invalidation on skill updates

---

### R - Repudiation

| Threat ID | Description | Asset | Mitigation | Status |
|-----------|-------------|-------|------------|--------|
| R-001 | Deny malicious skill installation | Install actions | Audit logging | ✅ Mitigated |
| R-002 | Deny security scan bypass | Security events | Audit logging with metadata | ✅ Mitigated |
| R-003 | Deny rate limit configuration changes | Config changes | Audit logging with actor | ✅ Mitigated |

#### R-001: Installation Denial

**Risk**: Medium
**Impact**: Unable to trace source of malicious skill installation.

**Mitigations**:
- AuditLogger captures all `skill_install` events
- Metadata includes: skill_id, source, trust_tier, timestamp
- Retention policy: 90 days default, configurable to 3650 days

**Verification**:
- Runbook: `docs/runbooks/audit-log-retention.md`
- E2E tests: `packages/core/tests/e2e/security/security.e2e.test.ts` (Audit Log Integrity suite)

---

### I - Information Disclosure

| Threat ID | Description | Asset | Mitigation | Status |
|-----------|-------------|-------|------------|--------|
| I-001 | SSRF leaking internal network data | Network topology | URL validation, IP blocking | ✅ Mitigated |
| I-002 | Path traversal exposing filesystem | Local files | Path validation, root containment | ✅ Mitigated |
| I-003 | Error messages leaking internals | System info | Error sanitization | ✅ Mitigated |
| I-004 | Audit logs exposing secrets | Credentials | Log sanitization | ✅ Mitigated |

#### I-001: SSRF

**Risk**: High
**Impact**: Access to internal network services, cloud metadata endpoints.

**Mitigations**:
- Block private IPv4 ranges (10.x, 172.16-31.x, 192.168.x)
- Block private IPv6 ranges (fe80::, fc00::, ff00::)
- Block localhost variants (127.x, ::1, localhost)
- Block IPv4-mapped IPv6 (::ffff:x.x.x.x)
- Protocol whitelist (http/https only)

**Verification**:
- Unit tests: `packages/core/tests/RawUrlSourceAdapter.security.test.ts`
- E2E tests: `packages/core/tests/e2e/security/security.e2e.test.ts` (SSRF Prevention suite)

#### I-002: Path Traversal

**Risk**: High
**Impact**: Access to arbitrary files on filesystem.

**Mitigations**:
- All paths resolved with `path.resolve()`
- Containment validation (must be under root directory)
- Rejection of `..` sequences before resolution

**Verification**:
- Unit tests: `packages/core/src/security/__tests__/pathValidation.test.ts`
- E2E tests: `packages/core/tests/e2e/security/security.e2e.test.ts` (Path Traversal Prevention suite)

---

### D - Denial of Service

| Threat ID | Description | Asset | Mitigation | Status |
|-----------|-------------|-------|------------|--------|
| D-001 | API rate limit exhaustion | External APIs | Token bucket rate limiting | ✅ Mitigated |
| D-002 | Search query flooding | CPU/Database | Rate limiting, query timeout | ✅ Mitigated |
| D-003 | Memory exhaustion via cache | Memory | LRU eviction, size limits | ✅ Mitigated |
| D-004 | Memory exhaustion via rate limiter | Memory | MAX_UNIQUE_KEYS limit (10,000) | ✅ Mitigated |
| D-005 | ReDoS via regex patterns | CPU | Regex timeout, input length limits | ⚠️ Partial |

#### D-001: API Rate Limit Exhaustion

**Risk**: Medium
**Impact**: GitHub API quota depleted, service degradation.

**Mitigations**:
- Token bucket algorithm with configurable rates
- Request queuing with timeout
- Per-adapter rate limiting
- Metrics monitoring

**Verification**:
- E2E tests: `packages/core/tests/e2e/security/security.e2e.test.ts` (Rate Limiting suite)

**Configuration**:
```typescript
RATE_LIMIT_PRESETS.standard: { maxTokens: 100, refillRate: 10/sec }
RATE_LIMIT_PRESETS.strict: { maxTokens: 10, refillRate: 1/sec }
```

#### D-004: Rate Limiter Memory Exhaustion

**Risk**: Medium
**Impact**: Server crash due to unbounded memory growth.

**Mitigations**:
- MAX_UNIQUE_KEYS = 10,000 (hard limit)
- LRU eviction for metrics
- TTL-based cleanup (1 hour)
- Periodic cleanup (5 minutes)

---

### E - Elevation of Privilege

| Threat ID | Description | Asset | Mitigation | Status |
|-----------|-------------|-------|------------|--------|
| E-001 | Unknown skill executed as verified | Trust tier | Trust tier validation | ✅ Mitigated |
| E-002 | Malicious code in skill file | User system | Security scanner, content analysis | ✅ Mitigated |
| E-003 | Command injection via skill | Shell access | No shell execution in core | ✅ Mitigated |
| E-004 | Prototype pollution | Object hierarchy | Object.freeze, input validation | ✅ Mitigated |

#### E-002: Malicious Skill Content

**Risk**: High
**Impact**: Arbitrary code execution on user's system.

**Mitigations**:
- SecurityScanner analyzes skill content pre-install
- Detection of shell commands, network access, file operations
- Risk score calculation with thresholds
- Quarantine for high-risk skills

**Detection Patterns**:
- `eval()`, `Function()` calls
- Shell execution patterns (`exec`, `spawn`)
- Network requests (`fetch`, `http`)
- File system access (`fs.`)
- Environment variable access

---

## Risk Matrix

| Risk Level | Likelihood | Impact | Threats |
|------------|------------|--------|---------|
| Critical | High | High | - |
| High | High | Medium | S-001, D-005 |
| High | Medium | High | I-001, I-002, E-002 |
| Medium | Medium | Medium | T-004, R-001, D-001, D-004 |
| Low | Low | Medium | S-002 |

---

## Compliance Mapping

| Requirement | STRIDE Threats | Mitigations |
|-------------|---------------|-------------|
| OWASP A01 - Broken Access Control | E-001, E-002 | Trust tiers, security scanner |
| OWASP A03 - Injection | T-001, I-001 | Parameterized queries, URL validation |
| OWASP A04 - Insecure Design | All | Defense in depth architecture |
| OWASP A09 - Security Logging | R-001, R-002 | AuditLogger, retention policy |

---

## Review Schedule

| Activity | Frequency | Owner |
|----------|-----------|-------|
| Threat model review | Quarterly | Security Specialist |
| Penetration testing | Annually | External auditor |
| Dependency audit | Weekly (CI) | Automated |
| Security test suite | Per commit | CI/CD |

---

## Remediation Roadmap

SMI-1032: Timeline for addressing partially mitigated threats.

### High Priority

| Threat ID | Description | Remediation | Effort | Target |
|-----------|-------------|-------------|--------|--------|
| S-001 | Author Impersonation | Implement cryptographic signing for verified skills | High | Q2 2026 |
| D-005 | ReDoS via regex | Add regex timeout wrapper, input length limits | Medium | Q1 2026 |

### S-001 Implementation Plan

1. **Phase 1**: Define signing key infrastructure (2 weeks)
   - Generate signing keypair for Skillsmith
   - Document key management procedures
   - Create key rotation policy

2. **Phase 2**: Implement signature verification (3 weeks)
   - Add signature field to skill metadata
   - Implement verification in install flow
   - Add UI indicator for signed skills

3. **Phase 3**: Author enrollment (ongoing)
   - Create author verification via GitHub OAuth
   - Build self-service signing portal
   - Document signing process for authors

**Blockers**: Requires GitHub App (SMI-878)

### D-005 Implementation Plan

1. **Phase 1**: Audit existing regex patterns (1 week)
   - Identify all regex in codebase
   - Test for catastrophic backtracking
   - Document findings

2. **Phase 2**: Add safeguards (1 week)
   - Implement regex timeout wrapper (RE2 or safe-regex)
   - Add input length limits (max 10KB)
   - Add fuzz testing for regex

**Dependencies**: None

---

## References

- [Security Standards Index](index.md)
- [Rate Limiting Documentation](index.md#7-rate-limiting)
- [Audit Log Runbook](../runbooks/audit-log-retention.md)
- [STRIDE Methodology](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [OWASP Top 10](https://owasp.org/Top10/)

---

*Last Reviewed: 2026-01-04 | Reviewer: Hive Mind Orchestrator*
