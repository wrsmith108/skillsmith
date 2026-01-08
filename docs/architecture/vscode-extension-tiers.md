# VS Code Extension Commercial Tiers

**Date**: January 2, 2026
**Status**: Approved
**Issue**: SMI-949

---

## Overview

The VS Code extension (`@skillsmith/vscode-extension`) is distributed under Apache-2.0 license with runtime feature detection for commercial tiers.

## Tier Assignment

| Tier | Price | VS Code Extension | Features |
|------|-------|-------------------|----------|
| **Community** | Free | ✅ Included | Core skill discovery, install, search |
| **Team** | $25/user/mo | ✅ Same extension | + Team dashboard, usage analytics |
| **Enterprise** | $69/user/mo | ✅ Same extension | + SSO, private registry, audit |

## Architecture

### Single Extension, Multiple Tiers

```
@skillsmith/vscode-extension (Apache-2.0)
├── Core Features (always available)
│   ├── Skill search
│   ├── Skill install/uninstall
│   ├── Skill recommendations
│   └── MCP server connection
│
└── Tier-Gated Features (runtime detection)
    ├── Team Features
    │   ├── Usage analytics dashboard
    │   └── Team skill sharing
    │
    └── Enterprise Features
        ├── SSO authentication
        ├── Private registry browser
        └── Audit event viewer
```

### License Detection Flow

```typescript
// VS Code extension startup
async function activate(context: ExtensionContext) {
  const license = await detectLicense();

  if (license.tier === 'enterprise') {
    enableEnterpriseFeatures(context);
  } else if (license.tier === 'team') {
    enableTeamFeatures(context);
  }

  // Core features always enabled
  enableCoreFeatures(context);
}

async function detectLicense(): Promise<License> {
  // 1. Check VS Code settings for license key
  const key = vscode.workspace.getConfiguration('skillsmith').get('licenseKey');

  // 2. Validate with license server (or offline cache)
  if (key) {
    return await validateLicense(key);
  }

  // 3. Default to community tier
  return { tier: 'community', valid: true };
}
```

### License Storage

| Storage Location | Purpose |
|------------------|---------|
| VS Code Settings | User-provided license key |
| VS Code SecretStorage | Encrypted license cache |
| Extension GlobalState | License validation timestamp |

```json
// settings.json
{
  "skillsmith.licenseKey": "sk_live_xxxx",
  "skillsmith.offlineMode": false
}
```

## Feature Availability

### Community Tier (Free)

All core MCP tools:
- `search` - Search skill registry
- `get_skill` - View skill details
- `install_skill` - Install to ~/.claude/skills
- `uninstall_skill` - Remove installed skills
- `recommend` - Get skill recommendations
- `validate` - Validate skill structure
- `compare` - Compare skills side-by-side

### Team Tier ($25/user/mo)

Community features plus:
- **Usage Analytics Panel** - View skill usage statistics
- **Team Skill Sharing** - Share skills with team members
- **Priority Support** - In-extension support chat

### Enterprise Tier ($69/user/mo)

Team features plus:
- **SSO Authentication** - Login via Okta/Azure AD/Google
- **Private Registry Browser** - Browse internal skill registry
- **Audit Event Viewer** - View audit logs in VS Code
- **Admin Panel** - Manage team licenses and permissions

## Implementation Notes

### Feature Gating Pattern

```typescript
// Use decorators for clean feature gating
@requiresTier('team')
async showAnalyticsDashboard() {
  // Only executes if team tier or higher
}

@requiresTier('enterprise')
async browsePrivateRegistry() {
  // Only executes if enterprise tier
}

// Decorator implementation
function requiresTier(tier: 'team' | 'enterprise') {
  return function (target: any, key: string, descriptor: PropertyDescriptor) {
    const original = descriptor.value;
    descriptor.value = async function (...args: any[]) {
      const license = await getLicense();
      if (!hasAccess(license, tier)) {
        vscode.window.showWarningMessage(
          `This feature requires ${tier} tier. Upgrade at skillsmith.app/pricing`
        );
        return;
      }
      return original.apply(this, args);
    };
  };
}
```

### Graceful Degradation

When license expires or is invalid:
1. Enterprise/Team features show upgrade prompts
2. Core features continue working
3. 7-day grace period for expired licenses
4. Offline mode uses cached license (24-hour validity)

## Distribution

### Marketplace Listing

The extension is published to:
- **VS Code Marketplace** (primary)
- **Open VSX Registry** (alternative)

### Pricing Display

```
Skillsmith - Skill Discovery for Claude Code
★★★★★ (4.8) | 10,000+ installs

FREE for individual developers
Team & Enterprise plans available at skillsmith.app/pricing
```

## References

- [ADR-005: VS Code MCP Client Architecture](../adr/005-vscode-mcp-client.md)
- [ADR-013: Open Core Licensing Model](../adr/013-open-core-licensing.md)
- [TERMS.md: Service Tiers](../legal/TERMS.md)
- [packages/vscode-extension/](../../packages/vscode-extension/)

---

*Approved: January 2, 2026*
