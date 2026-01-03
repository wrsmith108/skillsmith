# Audit Logging Architecture

## Overview
Skillsmith uses a tiered audit logging architecture where community features are in @skillsmith/core and enterprise enhancements are in @skillsmith/enterprise.

## Community Tier (Core)
Location: packages/core/src/security/AuditLogger.ts

Features:
- SQLite-based event storage
- Basic event types (url_fetch, file_access, skill_install, security_scan)
- 30-day default retention
- JSON export capability
- Query by event type, timestamp, result

## Enterprise Tier (Enterprise Package)
Location: packages/enterprise/src/audit/ (planned)

Additional Features:
- Enhanced event types (sso_login, rbac_check, license_validation)
- SIEM exporters (Splunk, CloudWatch, Datadog)
- SOC 2 compliant event formatting
- 90-day configurable retention
- Real-time event streaming
- Immutable log storage with integrity verification

## Integration Pattern

```typescript
// Enterprise AuditLogger extends Core
import { AuditLogger as CoreAuditLogger } from '@skillsmith/core';

export class EnterpriseAuditLogger extends CoreAuditLogger {
  // Enhanced exporters
  private siemExporter: SIEMExporter;

  // Additional event types
  logSSOEvent(event: SSOAuditEvent): void;
  logRBACEvent(event: RBACCheckEvent): void;

  // Compliance features
  exportForCompliance(format: 'SOC2' | 'HIPAA'): ComplianceReport;
}
```

## Feature Boundary

| Feature | Community | Enterprise |
|---------|-----------|------------|
| Event logging | ✅ | ✅ |
| SQLite storage | ✅ | ✅ |
| JSON export | ✅ | ✅ |
| 30-day retention | ✅ | ✅ |
| SIEM export | ❌ | ✅ |
| 90-day retention | ❌ | ✅ |
| SOC 2 formatting | ❌ | ✅ |
| Real-time streaming | ❌ | ✅ |
| SSO/RBAC events | ❌ | ✅ |

## References
- ADR-008: Security Hardening Phase
- ENTERPRISE_PACKAGE.md: §4 Audit Logging
- packages/core/src/security/AuditLogger.ts
