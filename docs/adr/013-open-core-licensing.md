# ADR-013: Open Core Licensing Model

**Status**: Accepted → **Superseded by ADR-013.1 (2026-01-11)**
**Date**: 2026-01-02 (Original) | 2026-01-11 (Updated)
**Deciders**: Skillsmith Team

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-02 | Original three-tier Apache-2.0 model |
| 1.1 | 2026-01-11 | **License change to Elastic License 2.0**, added Individual tier, implemented usage-based quotas |

## Context

Phase 6 established an Open Core licensing model to balance community adoption with sustainable revenue generation. Phase 7 evolved this to Elastic License 2.0 with usage-based quotas. The model addresses the need for:

1. **Community Growth**: Enabling wide adoption through source-available core functionality
2. **Revenue Sustainability**: Generating predictable revenue through commercial tiers with usage quotas
3. **Enterprise Requirements**: Providing advanced features (SSO, RBAC, audit logging, private registries) that enterprises require
4. **Contributor Protection**: Ensuring enterprise contributions don't inadvertently become open source
5. **Managed Service Protection**: Preventing third parties from offering Skillsmith as a hosted service (Elastic License 2.0 restriction)

The **four-tier structure** (updated 2026-01-11) is as follows:
- **Community Tier**: Elastic-2.0 (free, 1,000 API calls/month)
- **Individual Tier**: $9.99/month (10,000 API calls/month) - **NEW**
- **Team Tier**: $25/user/month (100,000 API calls/month)
- **Enterprise Tier**: $55/user/month (unlimited API calls)

See [TERMS.md](../legal/TERMS.md) for complete pricing and licensing terms.

## Decision

### 1. All Packages Licensed Under Elastic License 2.0 (Updated 2026-01-11)

**License Change (January 2026)**: All packages were migrated from Apache-2.0 to Elastic License 2.0 to:
- Prevent cloud providers from offering Skillsmith as a managed service
- Protect license key enforcement mechanisms from circumvention
- Maintain source-available status for transparency and self-hosting

| Package | Purpose | License |
|---------|---------|---------|
| `@skillsmith/core` | Database, repositories, services | **Elastic-2.0** |
| `@skillsmith/mcp-server` | MCP tools (search, install, etc.) | **Elastic-2.0** |
| `@skillsmith/cli` | Command-line interface | **Elastic-2.0** |
| `@skillsmith/vscode-extension` | VS Code integration | **Elastic-2.0** |
| `@skillsmith/enterprise` | Enterprise features | **Elastic-2.0** (proprietary features) |

**Elastic License 2.0 Restrictions:**
1. You may not provide the software to third parties as a hosted or managed service
2. You may not circumvent license key functionality or remove/obscure features protected by license keys

These packages provide all fundamental skill discovery functionality. Self-hosting for internal use is permitted.

### 2. Enterprise Package Is Proprietary

The `@skillsmith/enterprise` package contains proprietary code and is not open source:

| Feature | Description |
|---------|-------------|
| License Validation | JWT-based license keys with offline validation |
| SSO/SAML Integration | Okta, Azure AD, Google Workspace providers |
| Audit Logging | Compliance-ready logging with SIEM export |
| RBAC | Role-based access control with policy engine |
| Private Registry | Enterprise skill registry with sync |

See [ENTERPRISE_PACKAGE.md](../enterprise/ENTERPRISE_PACKAGE.md) for complete feature specifications.

### 3. VS Code Extension Licensing

The VS Code extension (`@skillsmith/vscode-extension`) is licensed under Elastic License 2.0 with the following behavior:

- Core functionality is source-available under Elastic-2.0
- Enterprise features are enabled via license key detection
- Quota enforcement applies based on license tier
- The extension checks for `@skillsmith/enterprise` availability at runtime

```typescript
// License and quota detection pattern
const licenseStatus = await getLicenseStatus();
const quotaStatus = await checkQuotaRemaining();

if (quotaStatus.remaining === 0 && licenseStatus.tier !== 'enterprise') {
  displayUpgradePrompt(quotaStatus);
} else if (licenseStatus.tier === 'enterprise') {
  enableEnterpriseFeatures();
}
```

### 4. Contributor License Agreement (CLA)

A CLA is required for contributions that touch enterprise-related code:

| Contribution Type | CLA Required |
|-------------------|--------------|
| Core packages only | No |
| Enterprise integration points | Yes |
| Enterprise package | Yes |

The CLA ensures:
- Contributors grant necessary rights for commercial licensing
- Skillsmith can include contributions in proprietary builds
- Contributors retain copyright to their contributions

## Consequences

### Positive

- **Clear Revenue Model**: Tiered pricing provides predictable revenue while maintaining community access
- **Community Contribution**: Core packages remain fully open, encouraging community contributions
- **Enterprise Features Protected**: Proprietary enterprise features justify commercial pricing
- **Adoption Path**: Users can start free and upgrade as needs grow
- **Compliance Ready**: Enterprise tier includes audit logging and SSO required by regulated industries
- **Flexibility**: Apache-2.0 allows commercial use of core packages without copyleft restrictions

### Negative

- **CLA Overhead**: Contributors to enterprise integration points must sign CLA before contributions are accepted
- **Build Complexity**: Separate build pipelines needed for open source vs proprietary packages
- **Feature Boundary Maintenance**: Ongoing effort to clearly separate core vs enterprise features
- **Documentation Burden**: Must clearly communicate what features are available in each tier
- **Community Perception**: Some community members may view commercial tiers negatively

### Neutral

- Requires ongoing investment in both open source community and enterprise sales
- Enterprise customers expect support SLAs that differ from community tier
- Versioning must be coordinated across open source and proprietary packages

## Alternatives Considered

### Alternative 1: Full Open Source (AGPL or MIT)

- **Pros**: Maximum community adoption, no licensing complexity, contributor-friendly
- **Cons**: No direct revenue path, enterprise features freely available, difficult to sustain development
- **Why rejected**: Does not provide sustainable funding model for continued development

### Alternative 2: Full Proprietary

- **Pros**: Maximum control, simplified licensing, all features monetizable
- **Cons**: Limited adoption, no community contributions, higher barrier to entry
- **Why rejected**: Limits market adoption and community growth essential for ecosystem

### Alternative 3: Dual Licensing with GPL

- **Pros**: Strong copyleft encourages commercial licensing, established model
- **Cons**: GPL compatibility issues with many enterprise environments, complex for integrators
- **Why rejected**: GPL's copyleft requirements create friction for enterprise adoption and integration with other tools

### Alternative 4: Source Available (BSL/SSPL/Elastic-2.0) ✅ **ADOPTED (2026-01-11)**

- **Pros**: Code visible, protects against cloud exploitation, allows self-hosting
- **Cons**: Not OSI-approved, some community concerns about "open washing"
- **Why adopted (2026-01-11)**: Elastic License 2.0 provides optimal balance:
  - Prevents cloud providers from competing with hosted Skillsmith
  - Allows full self-hosting for internal use
  - Well-understood in the industry (Elastic, MongoDB precedents)
  - Simpler than BSL time-delay mechanism

## Publishing Strategy

The source-available model enables a staged publishing approach:

| Package | Registry | License | Phase |
|---------|----------|---------|-------|
| `@skillsmith/core` | Public npm | **Elastic-2.0** | 5A (immediate) |
| `@skillsmith/mcp-server` | Public npm | **Elastic-2.0** | 5A (immediate) |
| `@skillsmith/cli` | Public npm | **Elastic-2.0** | 5A (immediate) |
| `@skillsmith/vscode-extension` | Public npm | **Elastic-2.0** | 5A (immediate) |
| `@skillsmith/enterprise` | Private npm | **Elastic-2.0** (proprietary features) | 7 (after gating) |

**Key Insight**: All packages use Elastic License 2.0. Enterprise package requires license validation (Phase 5B) and feature gating to be in place first.

## Commercialization Strategy (Updated 2026-01-11)

This ADR uses **hybrid monetization** combining feature bifurcation with usage quotas:

### Usage-Based Quotas (New in Phase 7)

| Tier | Price | API Calls/Month | Over-Limit Behavior |
|------|-------|-----------------|---------------------|
| Community | Free | 1,000 | Hard block, upgrade prompt |
| Individual | $9.99/mo | 10,000 | Hard block, upgrade prompt |
| Team | $25/user/mo | 100,000 | Hard block, upgrade prompt |
| Enterprise | $55/user/mo | Unlimited | N/A |

### Warning Threshold System

| Usage % | UI Behavior |
|---------|-------------|
| 0-79% | Normal operation, dim quota display |
| 80-89% | Yellow warning, "Approaching limit" |
| 90-99% | Yellow warning box, upgrade CTA |
| 100% | Red error, hard block, upgrade required |

### Feature Bifurcation (Unchanged)

Enterprise-only features remain gated by license tier:
- SSO/SAML integration
- Role-based access control (RBAC)
- Audit logging with SIEM export
- Private skill registry

See [ADR-017: Quota Enforcement System](./017-quota-enforcement-system.md) for implementation details.
See [go-to-market-analysis.md](../strategy/go-to-market-analysis.md) for market strategy.

## References

- [TERMS.md](../legal/TERMS.md) - Complete Terms of Service with pricing tiers
- [ENTERPRISE_PACKAGE.md](../enterprise/ENTERPRISE_PACKAGE.md) - Enterprise feature specifications
- [go-to-market-analysis.md](../strategy/go-to-market-analysis.md) - Feature bifurcation strategy
- [Elastic License 2.0](https://www.elastic.co/licensing/elastic-license) - Current license
- [ADR-001: Monorepo Structure](./001-monorepo-structure.md) - Package organization
- [ADR-014: Enterprise Package Architecture](./014-enterprise-package-architecture.md) - Enterprise implementation
- [ADR-017: Quota Enforcement System](./017-quota-enforcement-system.md) - Usage quota implementation
- [Open Core Model Best Practices](https://opensource.guide/legal/)
