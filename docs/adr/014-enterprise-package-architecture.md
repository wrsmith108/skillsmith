# ADR-014: Enterprise Package Architecture

**Status**: Accepted (Updated 2026-01-11)
**Date**: 2025-01-02 (Original) | 2026-01-11 (Updated for Elastic-2.0 and Quotas)
**Deciders**: Skillsmith Team

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-02 | Original enterprise package architecture |
| 1.1 | 2026-01-11 | Updated for Elastic-2.0 license, added quota enforcement middleware, added Individual tier |

## Context

Phase 6 commercialization requires a proprietary `@skillsmith/enterprise` package that integrates with the source-available core packages while maintaining clear separation between core and proprietary code.

Current `packages/` structure (all Elastic-2.0 as of 2026-01-11):
- `core` - **Elastic-2.0** (database, repositories, services)
- `mcp-server` - **Elastic-2.0** (MCP tools for Claude Code)
- `cli` - **Elastic-2.0** (command-line interface)
- `vscode-extension` - **Elastic-2.0** (VS Code integration)
- `enterprise` - **Elastic-2.0** (proprietary features, not open source)

Enterprise customers require features that are not suitable for open source distribution:
- SSO/SAML authentication with enterprise identity providers
- Role-based access control (RBAC) for multi-user environments
- Enhanced audit logging for compliance requirements
- Private skill registry for internal skill distribution
- License key validation and feature gating

## Decision

### 1. Create `packages/enterprise/` with Proprietary Features

The enterprise package is licensed under Elastic License 2.0 (same as core packages) but contains proprietary features not available in other packages. This enables monetization while keeping the core source-available.

### 2. Enterprise Depends on `@skillsmith/core` as Peer Dependency

```json
{
  "name": "@skillsmith/enterprise",
  "peerDependencies": {
    "@skillsmith/core": "workspace:*",
    "@skillsmith/mcp-server": "workspace:*"
  }
}
```

This ensures:
- Enterprise features extend rather than duplicate core functionality
- Users must have core packages installed
- Version compatibility is enforced at installation time

### 3. Feature Detection via License Key Validation

Enterprise features are gated behind JWT-based license key validation:

```typescript
interface LicenseValidator {
  validate(key: string): Promise<LicenseValidationResult>;
  hasFeature(feature: FeatureFlag): boolean;
  getLicense(): License | null;
}
```

Features are enabled based on license tier and feature flags embedded in the JWT payload.

### 4. Separate npm Publish Process

Enterprise package distribution options:
- **Private npm registry** (Verdaccio, Artifactory, or npm Enterprise)
- **npm organization scope** with restricted access (`@skillsmith-enterprise/`)
- **Direct distribution** via customer portal

The enterprise package will NOT be published to the public npm registry.

### 5. Enterprise Features

| Feature | Description |
|---------|-------------|
| SSO/SAML | Okta, Azure AD, Google Workspace integration |
| RBAC | Role-based access control with policy engine |
| Audit Logging | Enhanced logging with SIEM export (Splunk, Elastic) |
| Private Registry | Internal skill distribution and publishing |
| License Management | JWT-based licensing with offline validation |

## Architecture

```
@skillsmith/enterprise
├── license/          # JWT license validation
│   ├── LicenseValidator.ts
│   ├── LicenseKeyParser.ts
│   ├── OfflineValidator.ts
│   └── KeyRotation.ts
│
├── sso/              # SAML/OIDC providers
│   ├── SSOManager.ts
│   ├── providers/
│   │   ├── OktaProvider.ts
│   │   ├── AzureADProvider.ts
│   │   └── GoogleWorkspaceProvider.ts
│   ├── saml/
│   │   └── SAMLValidator.ts
│   └── oidc/
│       └── OIDCClient.ts
│
├── audit/            # Enhanced audit logging
│   ├── AuditLogger.ts
│   ├── formatters/
│   │   ├── JSONFormatter.ts
│   │   ├── SyslogFormatter.ts
│   │   └── CEFFormatter.ts
│   └── exporters/
│       ├── SIEMExporter.ts
│       └── CloudExporter.ts
│
├── rbac/             # Role-based access control
│   ├── RBACManager.ts
│   ├── PermissionChecker.ts
│   ├── RoleHierarchy.ts
│   └── policies/
│       ├── PolicyEngine.ts
│       └── DefaultPolicies.ts
│
└── registry/         # Private registry client
    ├── PrivateRegistry.ts
    ├── RegistryAuth.ts
    ├── SkillPublisher.ts
    └── RegistrySync.ts
```

## Integration Points

### Middleware Hooks in MCP Server

License validation and quota enforcement are enforced via middleware in `@skillsmith/mcp-server`:

```typescript
// In @skillsmith/mcp-server
import { LicenseValidator } from '@skillsmith/enterprise';
import { createQuotaMiddleware, createLicenseMiddleware } from './middleware';

// License middleware - validates JWT and determines tier
const licenseMiddleware = createLicenseMiddleware();

// Quota middleware - enforces API call limits
const quotaMiddleware = createQuotaMiddleware();

const requestHandler = async (toolName, params) => {
  // 1. Get license info
  const licenseInfo = await licenseMiddleware.getLicenseInfo();

  // 2. Check quota before executing tool
  const quotaResult = await quotaMiddleware.checkAndTrack(toolName, licenseInfo);
  if (!quotaResult.allowed) {
    return quotaMiddleware.buildExceededResponse(quotaResult);
  }

  // 3. Check enterprise feature access
  if (isEnterpriseFeature(toolName)) {
    if (!licenseInfo?.valid || licenseInfo.tier !== 'enterprise') {
      return { error: 'Enterprise license required' };
    }
  }

  // 4. Execute tool and include quota metadata
  const result = await executeTool(toolName, params);
  return {
    ...result,
    _meta: { quota: quotaMiddleware.buildMetadata(quotaResult) }
  };
};
```

### Quota Enforcement (Added 2026-01-11)

The MCP server enforces usage quotas per license tier:

| Tier | API Calls/Month | Enforcement |
|------|-----------------|-------------|
| Community | 1,000 | Hard block at limit |
| Individual | 10,000 | Hard block at limit |
| Team | 100,000 | Hard block at limit |
| Enterprise | Unlimited | No enforcement |

See [ADR-017: Quota Enforcement System](./017-quota-enforcement-system.md) for detailed implementation.

### Enhanced Audit Events Extending Core AuditLogger

Enterprise audit logging extends the core `AuditLogger` interface:

```typescript
// Core provides base interface
import { AuditLogger as CoreAuditLogger } from '@skillsmith/core';

// Enterprise extends with SIEM export
class EnterpriseAuditLogger extends CoreAuditLogger {
  async exportToSIEM(config: SIEMConfig): Promise<void>;
  async exportToCloud(destination: CloudStorageConfig): Promise<void>;
  createEventStream(filter: EventFilter): AsyncIterable<AuditEvent>;
}
```

### SSO Session Management for CLI/VS Code

SSO sessions are shared across CLI and VS Code extension:

```typescript
interface SSOSession {
  userId: string;
  email: string;
  roles: string[];
  provider: 'okta' | 'azure' | 'google';
  expiresAt: Date;
  refreshToken?: string;
}

// Session storage location
// CLI: ~/.skillsmith/session.json
// VS Code: Extension global state
```

## Consequences

### Positive

- **Clear separation of proprietary code** - Enterprise features are isolated in a single package with distinct licensing
- **Core remains source-available** - Elastic License 2.0 maintained for all packages
- **Enterprise features are modular** - Customers can use only the features they need
- **Predictable revenue model** - License-based feature gating enables tiered pricing
- **Compliance-ready** - SIEM integration and audit logging support SOC2/HIPAA requirements

### Negative

- **Build complexity** - Separate build and test pipelines for enterprise package
- **Need separate CI/CD for proprietary code** - Cannot use public GitHub Actions for sensitive code
- **Version coordination across packages** - Enterprise package versions must align with core releases
- **Testing complexity** - Integration tests require both open source and enterprise packages

### Neutral

- Enterprise package published to private registry or customer portal
- Documentation split between public (core) and private (enterprise)
- Support ticketing system needed for enterprise customers

## Alternatives Considered

### Alternative 1: Feature Flags in Core Package

- **Pros**: Single codebase, simpler builds
- **Cons**: Proprietary code in open source repo, license contamination risk
- **Why rejected**: Violates open source principles and creates legal risks

### Alternative 2: Separate Repository for Enterprise

- **Pros**: Complete code isolation
- **Cons**: Duplication of shared code, harder to keep in sync
- **Why rejected**: Workspace references provide better DX while maintaining separation

### Alternative 3: SaaS-Only Model (No Self-Hosted Enterprise)

- **Pros**: Simpler distribution, no license key management
- **Cons**: Many enterprises require self-hosted deployments for security
- **Why rejected**: Limits addressable market

## References

- [ENTERPRISE_PACKAGE.md](../enterprise/ENTERPRISE_PACKAGE.md) - Detailed feature specifications
- [ADR-001: Monorepo Structure](./001-monorepo-structure.md) - Workspace architecture
- [ADR-013: Open Core Licensing](./013-open-core-licensing.md) - License model and tier structure
- [ADR-017: Quota Enforcement System](./017-quota-enforcement-system.md) - Usage quota implementation
- [Elastic License 2.0](https://www.elastic.co/licensing/elastic-license) - Current license
- [JWT RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519) - License key format
- [SAML 2.0 Specification](https://docs.oasis-open.org/security/saml/v2.0/) - SSO protocol
- [OpenID Connect Core](https://openid.net/specs/openid-connect-core-1_0.html) - OIDC integration
