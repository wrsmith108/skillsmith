# ADR-017: Quota Enforcement System

**Status**: Accepted
**Date**: 2026-01-11
**Deciders**: Skillsmith Team
**Related Issues**: SMI-1090, SMI-1091, SMI-1367, SMI-1368

## Context

Phase 7 introduced usage-based monetization alongside the existing feature-based tiering. This requires a quota enforcement system that:

1. **Tracks API call usage** per customer per billing period
2. **Enforces hard limits** at tier boundaries (no grace periods)
3. **Provides warning notifications** at 80%, 90%, and 100% thresholds
4. **Integrates with CLI and MCP Server** for consistent user experience
5. **Supports future database-backed storage** for persistence across server restarts

### Tier Structure

| Tier | Price | API Calls/Month | Over-Limit Behavior |
|------|-------|-----------------|---------------------|
| Community | Free | 1,000 | Hard block |
| Individual | $9.99/mo | 10,000 | Hard block |
| Team | $25/user/mo | 100,000 | Hard block |
| Enterprise | $55/user/mo | Unlimited | N/A |

### Design Constraints

- **No grace periods**: Hard block immediately at limit (business decision)
- **Stateless MCP server**: Default in-memory storage resets on restart (production should use database)
- **Optional dependency**: MCP server must work without `@skillsmith/enterprise` installed
- **Warning thresholds**: 80%, 90%, 100% (consistent across all tiers)

## Decision

### 1. Quota Middleware Architecture

Quota enforcement is implemented as middleware in `@skillsmith/mcp-server`:

```
┌─────────────────────────────────────────────────────────────┐
│                     MCP Server Request                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   License Middleware                         │
│  - Validates SKILLSMITH_LICENSE_KEY JWT                      │
│  - Determines tier (community/individual/team/enterprise)    │
│  - Returns LicenseInfo object                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Quota Middleware                          │
│  - Checks remaining quota for customer                       │
│  - Increments usage counter                                  │
│  - Returns QuotaCheckResult                                  │
│  - Blocks if quota exceeded                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Tool Execution                            │
│  - Executes if quota allows                                  │
│  - Includes quota metadata in response                       │
└─────────────────────────────────────────────────────────────┘
```

### 2. Key Interfaces

```typescript
// Quota check result returned by middleware
interface QuotaCheckResult {
  allowed: boolean;           // Whether tool call is allowed
  remaining: number;          // Remaining calls (-1 for unlimited)
  limit: number;              // Tier limit (-1 for unlimited)
  percentUsed: number;        // 0-100+
  warningLevel: 0 | 80 | 90 | 100;
  resetAt: Date;              // When quota resets
  message?: string;           // Warning/error message
  upgradeUrl?: string;        // Upgrade URL if at limit
}

// Quota metadata included in MCP responses
interface QuotaMetadata {
  remaining: number;
  limit: number;
  resetAt: string;           // ISO 8601 format
  warning?: string;
}

// Storage interface for quota tracking
interface QuotaStorage {
  getUsage(customerId: string): Promise<{
    used: number;
    periodStart: Date;
    periodEnd: Date;
  }>;
  incrementUsage(customerId: string, cost: number): Promise<void>;
  initializePeriod(customerId: string, limit: number): Promise<void>;
}
```

### 3. Quota Constants Location

Quota constants are defined in two locations (see SMI-1367 for rationale):

| Location | Purpose |
|----------|---------|
| `packages/enterprise/src/license/quotas.ts` | Source of truth, comprehensive configuration |
| `packages/mcp-server/src/middleware/quota.ts` | Runtime enforcement (duplicated for optional peer dependency) |

**Why duplication?** The MCP server must function without `@skillsmith/enterprise` installed. Since enterprise is an optional peer dependency, importing quota constants from enterprise would cause runtime failures for community users.

### 4. Warning Threshold System

| Threshold | Severity | UI Behavior | Email |
|-----------|----------|-------------|-------|
| 80% | Info | Yellow progress bar | No |
| 90% | Warning | Yellow warning box + upgrade CTA | Yes |
| 100% | Error | Red error, hard block | Yes |

### 5. CLI Integration

The CLI displays quota information in two contexts:

**Startup Header:**
```
Skillsmith CLI v1.0.0
License: Individual (expires: 2026-12-31)
API Quota: 1,234/10,000 calls used
```

**Inline Warnings (after commands):**
```
⚠️  API Quota Warning
You've used 92% of your monthly quota (9,200 / 10,000 calls)
Upgrade at: https://skillsmith.app/upgrade
```

**Quota Command:**
```bash
$ skillsmith quota
┌─────────────────────────────────────────────┐
│ Skillsmith Usage - Individual Tier          │
├─────────────────────────────────────────────┤
│ API Calls: 1,234 / 10,000 (12.3%)          │
│ [████░░░░░░░░░░░░░░░░░░░░░░░░░░] 12%       │
│ Resets: February 1, 2026                    │
└─────────────────────────────────────────────┘
```

### 6. MCP Response Metadata

All MCP tool responses include quota information in `_meta`:

```json
{
  "result": { ... },
  "_meta": {
    "quota": {
      "remaining": 8766,
      "limit": 10000,
      "resetAt": "2026-02-01T00:00:00Z",
      "warning": "80% of API quota used (1,234 calls remaining)"
    }
  }
}
```

### 7. Quota Exceeded Response

When quota is exceeded, tools return a structured error:

```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Monthly API quota exceeded (10,000/10,000 calls)",
    "upgradeUrl": "https://skillsmith.app/upgrade?reason=quota_exceeded&tier=individual",
    "resetAt": "2026-02-01T00:00:00Z"
  }
}
```

## Architecture

### File Structure

```
packages/enterprise/src/license/
├── quotas.ts              # Source of truth for quota constants
├── types.ts               # LicenseTier, FeatureFlag types
├── FeatureFlags.ts        # Feature flag definitions
├── TierMapping.ts         # Feature-to-tier mapping
└── LicenseValidator.ts    # JWT validation

packages/mcp-server/src/middleware/
├── license.ts             # License validation middleware
├── quota.ts               # Quota enforcement middleware (NEW)
├── errorFormatter.ts      # Error response formatting
├── degradation.ts         # Graceful degradation
└── index.ts               # Middleware exports

packages/cli/src/utils/
└── license.ts             # CLI license display with quota
```

### Type Hierarchy

```typescript
// Four-tier structure (updated from three-tier)
type LicenseTier = 'community' | 'individual' | 'team' | 'enterprise';

// Feature inheritance chain
// individual: basic_analytics, email_support
// team:       individual features + team_workspaces, private_skills, usage_analytics, priority_support
// enterprise: team features + sso_saml, rbac, audit_logging, siem_export, compliance_reports,
//             private_registry, custom_integrations, advanced_analytics
```

## Consequences

### Positive

- **Clear monetization path**: Usage-based pricing is industry standard and predictable
- **Fair for light users**: Community tier provides meaningful access (1,000 calls/month)
- **Upgrade incentive**: Warning system guides users to appropriate tier
- **Enterprise value**: Unlimited usage removes friction for large deployments
- **Extensible storage**: Interface-based storage allows future database backends
- **Consistent UX**: Same warning thresholds across CLI and MCP server

### Negative

- **Quota constant duplication**: Constants duplicated between enterprise and mcp-server packages (see SMI-1367)
- **In-memory default**: Default storage resets on server restart (production requires database)
- **Hard blocks**: No grace period may frustrate users at limit boundary
- **Billing period sync**: Monthly reset doesn't align with all billing systems

### Neutral

- Requires customer ID tracking for multi-tenant scenarios
- Enterprise customers still need license keys (even though quota is unlimited)
- Quota tracking separate from feature gating (two middleware layers)

## Alternatives Considered

### Alternative 1: Feature-Only Monetization (No Quotas)

- **Pros**: Simpler implementation, no usage tracking needed
- **Cons**: Doesn't monetize heavy API users, no natural upgrade path
- **Why rejected**: Feature bifurcation alone doesn't capture value from high-volume users

### Alternative 2: Soft Limits with Overage Billing

- **Pros**: No service disruption, automatic scaling
- **Cons**: Surprise bills, complex billing integration, potential runaway costs
- **Why rejected**: Surprise billing creates poor customer experience

### Alternative 3: Rate Limiting (Requests Per Second)

- **Pros**: Prevents abuse, no monthly tracking needed
- **Cons**: Doesn't differentiate tiers well, penalizes legitimate burst usage
- **Why rejected**: Monthly quota better matches SaaS pricing models

### Alternative 4: Grace Period Before Hard Block

- **Pros**: More forgiving for users at boundary
- **Cons**: Complicates billing, harder to enforce, potential abuse
- **Why rejected**: Business decision to keep limits firm and predictable

## Implementation Notes

### Known Issues

1. **SMI-1367**: Quota constants duplicated between packages (accepted trade-off for optional peer dependency)
2. **SMI-1368**: Inconsistent error return patterns (null vs {valid: false}) - documented as intentional security design (SMI-1130)

### Future Enhancements

1. **Database storage**: Replace in-memory storage with SQLite/PostgreSQL for persistence
2. **Quota dashboard**: Web UI for viewing usage history and trends
3. **Per-tool costs**: Different API calls may have different costs (e.g., search = 1, embedding = 5)
4. **Team quota pooling**: Team tier shares quota across all team members
5. **Overage alerts**: Email notifications before and after quota exhaustion

## References

- [ADR-013: Open Core Licensing](./013-open-core-licensing.md) - License model and tier structure
- [ADR-014: Enterprise Package Architecture](./014-enterprise-package-architecture.md) - Enterprise package design
- [packages/enterprise/src/license/quotas.ts](../../packages/enterprise/src/license/quotas.ts) - Quota constants
- [packages/mcp-server/src/middleware/quota.ts](../../packages/mcp-server/src/middleware/quota.ts) - Quota middleware
- [packages/cli/src/utils/license.ts](../../packages/cli/src/utils/license.ts) - CLI quota display
- Linear Issues: SMI-1090, SMI-1091, SMI-1367, SMI-1368
