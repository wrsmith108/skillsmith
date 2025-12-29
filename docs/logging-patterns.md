# Logging Patterns - Skillsmith

**Version**: 1.0
**Status**: Active
**Owner**: Logging Specialist
**Last Updated**: 2025-12-29

---

## Overview

Skillsmith uses an enhanced structured logging system with audit trail capabilities. The logger provides environment-aware logging, structured JSON output, context injection, and specialized audit and security event tracking.

## Quick Reference

| Feature | Usage |
|---------|-------|
| Basic Logging | `logger.info('message', { context })` |
| Error Logging | `logger.error('message', error, { context })` |
| Audit Events | `logger.auditLog(auditEvent)` |
| Security Events | `logger.securityLog(securityEvent)` |
| Namespaced Logger | `createLogger('namespace')` |
| Log Aggregation | `getLogAggregator().getLogs()` |

---

## 1. Basic Logging

### 1.1 Log Levels

```typescript
enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  AUDIT = 4,
  SECURITY = 5,
}
```

### 1.2 Standard Logging

```typescript
import { logger } from '@skillsmith/core/utils/logger'

// Basic logging
logger.debug('Detailed debug information')
logger.info('Informational message')
logger.warn('Warning message')
logger.error('Error message')

// With context
logger.info('Processing skill', { skillId: 'foo', version: '1.0.0' })

// With error object
logger.error('Failed to fetch skill', new Error('Network error'), {
  skillId: 'foo',
  url: 'https://example.com',
})
```

### 1.3 Namespaced Logger

```typescript
import { createLogger } from '@skillsmith/core/utils/logger'

const log = createLogger('GitLabAdapter')
log.warn('Rate limit exceeded', { remaining: 0, resetAt: Date.now() })
log.error('API request failed', error, { endpoint: '/api/v4/projects' })
```

## 2. Audit Logging

### 2.1 Audit Event Structure

```typescript
interface AuditEvent {
  eventType: AuditEventType
  timestamp: string
  actor: string // user, system, adapter
  resource: string // URL, path, skill_id
  action: string // fetch, read, install, scan
  result: 'success' | 'blocked' | 'error'
  metadata?: Record<string, unknown>
}
```

### 2.2 Audit Event Types

```typescript
type AuditEventType =
  | 'skill.install'
  | 'skill.uninstall'
  | 'skill.fetch'
  | 'skill.scan'
  | 'adapter.request'
  | 'adapter.error'
  | 'cache.hit'
  | 'cache.miss'
  | 'security.violation'
```

### 2.3 Creating Audit Events

```typescript
import { logger, createAuditEvent } from '@skillsmith/core/utils/logger'

// Manual creation
const auditEvent: AuditEvent = {
  eventType: 'skill.install',
  timestamp: new Date().toISOString(),
  actor: 'user',
  resource: 'skill-123',
  action: 'install',
  result: 'success',
  metadata: {
    version: '1.0.0',
    source: 'github',
  },
}
logger.auditLog(auditEvent)

// Using helper function
const event = createAuditEvent(
  'adapter.request',
  'GitLabAdapter',
  'https://gitlab.com/api/v4/projects',
  'fetch',
  'success',
  { statusCode: 200, duration: 150 }
)
logger.auditLog(event)
```

### 2.4 Audit Logging Patterns

```typescript
// Skill installation tracking
logger.auditLog(
  createAuditEvent(
    'skill.install',
    'user',
    skillId,
    'install',
    'success',
    { version, author, source }
  )
)

// Adapter API requests
logger.auditLog(
  createAuditEvent(
    'adapter.request',
    'GitHubAdapter',
    url,
    'fetch',
    'success',
    { method: 'GET', statusCode: 200 }
  )
)

// Cache operations
logger.auditLog(
  createAuditEvent('cache.hit', 'system', cacheKey, 'read', 'success', { ttl: 3600 })
)
```

## 3. Security Logging

### 3.1 Security Event Structure

```typescript
interface SecurityEvent {
  eventType: SecurityEventType
  timestamp: string
  severity: 'low' | 'medium' | 'high' | 'critical'
  resource: string
  action: string
  details: string
  metadata?: Record<string, unknown>
}
```

### 3.2 Security Event Types

```typescript
type SecurityEventType =
  | 'ssrf.blocked'
  | 'path_traversal.blocked'
  | 'validation.failed'
  | 'rate_limit.exceeded'
  | 'malware.detected'
  | 'suspicious.pattern'
```

### 3.3 Creating Security Events

```typescript
import { logger, createSecurityEvent } from '@skillsmith/core/utils/logger'

// SSRF prevention
logger.securityLog(
  createSecurityEvent(
    'ssrf.blocked',
    'high',
    'http://169.254.169.254/metadata',
    'fetch',
    'Blocked SSRF attempt to AWS metadata endpoint',
    { adapter: 'GitHubAdapter', ip: '1.2.3.4' }
  )
)

// Path traversal prevention
logger.securityLog(
  createSecurityEvent(
    'path_traversal.blocked',
    'critical',
    '../../etc/passwd',
    'read',
    'Blocked path traversal attempt',
    { requestedPath: '../../etc/passwd' }
  )
)

// Malware detection
logger.securityLog(
  createSecurityEvent(
    'malware.detected',
    'critical',
    'skill-malicious',
    'scan',
    'Detected obfuscated code pattern',
    { pattern: 'eval(atob(...))', riskScore: 0.95 }
  )
)
```

## 4. Structured JSON Logging

### 4.1 Enabling JSON Output

```bash
# Enable JSON format
export LOG_FORMAT=json

# Run application
npm run mcp
```

### 4.2 JSON Log Format

```json
{
  "level": "ERROR",
  "timestamp": "2025-12-29T18:00:00.000Z",
  "namespace": "GitHubAdapter",
  "message": "API request failed",
  "context": {
    "endpoint": "/repos/user/repo",
    "statusCode": 404
  },
  "error": {
    "message": "Not Found",
    "stack": "Error: Not Found\n    at ..."
  }
}
```

### 4.3 Audit Event JSON

```json
{
  "eventType": "skill.install",
  "timestamp": "2025-12-29T18:00:00.000Z",
  "actor": "user",
  "resource": "skill-123",
  "action": "install",
  "result": "success",
  "metadata": {
    "version": "1.0.0",
    "source": "github"
  }
}
```

### 4.4 Security Event JSON

```json
{
  "eventType": "ssrf.blocked",
  "timestamp": "2025-12-29T18:00:00.000Z",
  "severity": "high",
  "resource": "http://169.254.169.254/metadata",
  "action": "fetch",
  "details": "Blocked SSRF attempt to AWS metadata endpoint",
  "metadata": {
    "adapter": "GitHubAdapter"
  }
}
```

## 5. Log Aggregation

### 5.1 Accessing Aggregated Logs

```typescript
import { getLogAggregator } from '@skillsmith/core/utils/logger'

const aggregator = getLogAggregator()

// Get all logs
const allLogs = aggregator.getLogs()

// Get audit events
const auditEvents = aggregator.getAuditEvents()

// Get security events
const securityEvents = aggregator.getSecurityEvents()
```

### 5.2 Custom Log Aggregator

```typescript
import { setLogAggregator, type LogAggregator } from '@skillsmith/core/utils/logger'

class DatabaseLogAggregator implements LogAggregator {
  async add(entry: LogEntry): Promise<void> {
    await db.insert('logs', entry)
  }

  async addAudit(event: AuditEvent): Promise<void> {
    await db.insert('audit_logs', event)
  }

  async addSecurity(event: SecurityEvent): Promise<void> {
    await db.insert('security_events', event)
  }

  async flush(): Promise<void> {
    // Flush to database
  }

  // ... other methods
}

// Set custom aggregator
setLogAggregator(new DatabaseLogAggregator())
```

### 5.3 Memory Management

The default in-memory aggregator limits stored logs to 10,000 entries per type to prevent memory leaks:

```typescript
// Default aggregator with 10,000 entry limit
const aggregator = new MemoryLogAggregator(10000)

// Custom size
const smallAggregator = new MemoryLogAggregator(1000)
```

## 6. Environment Variables

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `NODE_ENV` | `test`, `development`, `production` | - | Suppresses warn/info/debug in test mode |
| `DEBUG` | `true`, `false` | `false` | Enable info and debug output |
| `LOG_FORMAT` | `json`, `text` | `text` | Output format |
| `LOG_LEVEL` | `0-5` | `2` (WARN) | Minimum log level |
| `AUDIT_LOG` | `true`, `false` | `false` | Enable audit log output |

## 7. Best Practices

### 7.1 Context-Rich Logging

```typescript
// ❌ Bad: No context
logger.error('Request failed')

// ✅ Good: Rich context
logger.error('Adapter request failed', error, {
  adapter: 'GitHubAdapter',
  endpoint: '/repos/user/repo',
  statusCode: 404,
  duration: 150,
})
```

### 7.2 Audit Trail Coverage

```typescript
// Track all state-changing operations
async function installSkill(skillId: string): Promise<void> {
  try {
    await performInstall(skillId)

    logger.auditLog(
      createAuditEvent('skill.install', 'user', skillId, 'install', 'success')
    )
  } catch (error) {
    logger.auditLog(
      createAuditEvent('skill.install', 'user', skillId, 'install', 'error', {
        error: error.message,
      })
    )
    throw error
  }
}
```

### 7.3 Security Event Severity

```typescript
// Critical: Immediate action required
logger.securityLog(
  createSecurityEvent(
    'malware.detected',
    'critical', // Blocks operation
    skillId,
    'scan',
    'Detected malicious code'
  )
)

// High: Requires attention
logger.securityLog(
  createSecurityEvent(
    'ssrf.blocked',
    'high', // Blocks operation
    url,
    'fetch',
    'Blocked SSRF attempt'
  )
)

// Medium: Monitor
logger.securityLog(
  createSecurityEvent(
    'validation.failed',
    'medium', // May allow operation with warning
    input,
    'validate',
    'Input validation failed'
  )
)

// Low: Informational
logger.securityLog(
  createSecurityEvent(
    'rate_limit.exceeded',
    'low', // Rate limiting, not malicious
    endpoint,
    'request',
    'Rate limit exceeded'
  )
)
```

### 7.4 Performance Considerations

```typescript
// Use silent logger in performance-critical paths
import { silentLogger } from '@skillsmith/core/utils/logger'

function hotPath() {
  silentLogger.debug('This won't impact performance')
}

// Or check log level before expensive operations
if (process.env.DEBUG) {
  const expensiveData = computeExpensiveDebugInfo()
  logger.debug('Debug info', { data: expensiveData })
}
```

## 8. Integration Examples

### 8.1 Source Adapter Logging

```typescript
class GitHubAdapter {
  private log = createLogger('GitHubAdapter')

  async fetchSkill(url: string): Promise<Skill> {
    this.log.info('Fetching skill', { url })

    const auditStart = Date.now()
    try {
      const skill = await this.doFetch(url)

      this.log.auditLog(
        createAuditEvent('adapter.request', 'GitHubAdapter', url, 'fetch', 'success', {
          duration: Date.now() - auditStart,
          skillId: skill.id,
        })
      )

      return skill
    } catch (error) {
      this.log.error('Fetch failed', error, { url })
      this.log.auditLog(
        createAuditEvent('adapter.request', 'GitHubAdapter', url, 'fetch', 'error', {
          error: error.message,
        })
      )
      throw error
    }
  }
}
```

### 8.2 Security Scanner Integration

```typescript
class SecurityScanner {
  private log = createLogger('SecurityScanner')

  async scanSkill(skillId: string, content: string): Promise<ScanResult> {
    const result = await this.performScan(content)

    if (result.malicious) {
      this.log.securityLog(
        createSecurityEvent(
          'malware.detected',
          'critical',
          skillId,
          'scan',
          `Detected ${result.patterns.length} malicious patterns`,
          {
            patterns: result.patterns,
            riskScore: result.riskScore,
          }
        )
      )
    }

    this.log.auditLog(
      createAuditEvent('skill.scan', 'SecurityScanner', skillId, 'scan', 'success', {
        malicious: result.malicious,
        riskScore: result.riskScore,
      })
    )

    return result
  }
}
```

### 8.3 MCP Tool Logging

```typescript
async function searchSkills(query: string): Promise<Skill[]> {
  logger.info('Searching skills', { query })

  try {
    const results = await repository.search(query)

    logger.auditLog(
      createAuditEvent('skill.fetch', 'mcp-tool', query, 'search', 'success', {
        resultCount: results.length,
      })
    )

    return results
  } catch (error) {
    logger.error('Search failed', error, { query })
    logger.auditLog(
      createAuditEvent('skill.fetch', 'mcp-tool', query, 'search', 'error', {
        error: error.message,
      })
    )
    throw error
  }
}
```

## 9. Testing

### 9.1 Using Silent Logger in Tests

```typescript
import { silentLogger } from '@skillsmith/core/utils/logger'

describe('MyComponent', () => {
  it('should work', () => {
    const component = new MyComponent(silentLogger)
    // No log output during test
  })
})
```

### 9.2 Inspecting Aggregated Logs in Tests

```typescript
import { getLogAggregator } from '@skillsmith/core/utils/logger'

describe('Audit Logging', () => {
  beforeEach(() => {
    const aggregator = getLogAggregator()
    if ('clear' in aggregator) {
      ;(aggregator as any).clear()
    }
  })

  it('should log install events', async () => {
    await installSkill('skill-123')

    const aggregator = getLogAggregator()
    const auditEvents = aggregator.getAuditEvents()

    expect(auditEvents).toHaveLength(1)
    expect(auditEvents[0]).toMatchObject({
      eventType: 'skill.install',
      resource: 'skill-123',
      result: 'success',
    })
  })
})
```

## 10. Migration from Old Logger

### 10.1 Breaking Changes

The logger API has changed to support context injection:

```typescript
// Old API
logger.warn('message', arg1, arg2)

// New API
logger.warn('message', { arg1, arg2 })

// Old API
logger.error('message', arg1, arg2)

// New API
logger.error('message', error, { context })
```

### 10.2 Migration Steps

1. Update logger imports:

```typescript
// Old
import { logger } from './utils/logger'

// New (same import, enhanced API)
import { logger } from '@skillsmith/core/utils/logger'
```

2. Update warn/info/debug calls:

```typescript
// Old
logger.warn('Rate limit', remaining, resetAt)

// New
logger.warn('Rate limit exceeded', { remaining, resetAt })
```

3. Update error calls:

```typescript
// Old
logger.error('Failed', error)

// New
logger.error('Operation failed', error, { context: 'details' })
```

4. Add audit logging for state changes:

```typescript
logger.auditLog(
  createAuditEvent('skill.install', 'user', skillId, 'install', 'success')
)
```

5. Add security logging for protection events:

```typescript
logger.securityLog(
  createSecurityEvent('ssrf.blocked', 'high', url, 'fetch', 'Blocked SSRF')
)
```

---

## Related Documentation

- [Security Standards](./security/index.md)
- [Engineering Standards](./architecture/standards.md)
- [Audit Database Schema](./security/index.md#3-audit-logging)
