# Audit Log Retention Runbook

**SMI-1019**: Operational runbook for managing audit log retention in Skillsmith.

---

## Overview

Skillsmith's `AuditLogger` stores security-relevant events in SQLite for compliance and forensics. This runbook documents the retention policy and cleanup procedures.

## Retention Policy

### Configuration Limits

| Parameter | Value | Description |
|-----------|-------|-------------|
| `MIN_RETENTION_DAYS` | 1 day | Minimum retention period (security requirement) |
| `MAX_RETENTION_DAYS` | 3650 days (10 years) | Maximum retention period (storage constraint) |
| Default | 90 days | Default retention when not configured |

### Compliance Considerations

- **SOC 2**: Typically requires 90-365 days retention
- **GDPR**: May require deletion within 30 days for user data (audit logs are operational, not user data)
- **PCI DSS**: Requires 1 year retention minimum for cardholder data environments

Adjust `retentionDays` based on your compliance requirements.

---

## Configuration

### Auto-Cleanup on Initialization

Enable automatic cleanup when the AuditLogger is created:

```typescript
import { AuditLogger } from '@skillsmith/core'

const auditLogger = new AuditLogger(db, {
  autoCleanup: true,
  retentionDays: 90  // Delete logs older than 90 days
})
```

### Manual Cleanup

Run cleanup on-demand:

```typescript
// Delete logs older than 30 days
const deleted = auditLogger.cleanupOldLogs(30)
console.log(`Deleted ${deleted} old audit log entries`)
```

---

## Operational Procedures

### 1. Check Current Audit Log Stats

```typescript
const stats = auditLogger.getStats()

console.log(`Total events: ${stats.total_events}`)
console.log(`Oldest event: ${stats.oldest_event}`)
console.log(`Newest event: ${stats.newest_event}`)
console.log(`Blocked events: ${stats.blocked_events}`)
console.log(`Error events: ${stats.error_events}`)
```

### 2. Estimate Storage Requirements

**Rule of Thumb**: Each audit log entry is approximately 500-1000 bytes.

| Volume | Daily Events | 90-Day Storage | 1-Year Storage |
|--------|--------------|----------------|----------------|
| Low | 1,000 | ~45 MB | ~180 MB |
| Medium | 10,000 | ~450 MB | ~1.8 GB |
| High | 100,000 | ~4.5 GB | ~18 GB |

### 3. Export Before Cleanup (Optional)

For compliance, export logs before cleanup:

```typescript
const logsToArchive = auditLogger.query({
  since: new Date('2025-01-01'),
  until: new Date('2025-03-31'),
  limit: 100000
})

const exportJson = JSON.stringify(logsToArchive, null, 2)
// Save to archive storage (S3, GCS, etc.)
```

Or use the built-in export method:

```typescript
const jsonExport = auditLogger.export({
  since: new Date('2025-01-01'),
  until: new Date('2025-03-31')
})
```

### 4. Scheduled Cleanup (Cron Job)

For production systems, schedule regular cleanup:

```typescript
// Example: Daily cleanup cron job
import { createDatabase, AuditLogger } from '@skillsmith/core'

async function dailyCleanup() {
  const db = createDatabase('./skillsmith.db')
  const auditLogger = new AuditLogger(db)

  const deleted = auditLogger.cleanupOldLogs(90)

  console.log(`[${new Date().toISOString()}] Audit cleanup: ${deleted} entries removed`)

  db.close()
}

// Run daily at 2 AM
// crontab: 0 2 * * * node /path/to/cleanup-script.js
```

---

## Error Handling

### Invalid Retention Days

The cleanup method validates input to prevent accidental data loss:

```typescript
// These will throw errors:
auditLogger.cleanupOldLogs(0)    // Error: minimum is 1 day
auditLogger.cleanupOldLogs(-5)   // Error: minimum is 1 day
auditLogger.cleanupOldLogs(5000) // Error: maximum is 3650 days
auditLogger.cleanupOldLogs(1.5)  // Error: must be an integer
```

### Meta-Logging

Cleanup operations are themselves logged to the audit trail:

```json
{
  "event_type": "config_change",
  "actor": "system",
  "resource": "audit_logs",
  "action": "cleanup",
  "result": "success",
  "metadata": {
    "retentionDays": 90,
    "cutoffDate": "2025-10-06T00:00:00.000Z",
    "deletedCount": 1542
  }
}
```

---

## Monitoring

### Metrics to Track

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `audit_log_total_events` | Total events in database | Monitor growth rate |
| `audit_log_oldest_event_age_days` | Age of oldest event | > retention policy |
| `audit_cleanup_deleted_count` | Events deleted per cleanup | Sudden spikes |
| `audit_cleanup_duration_ms` | Cleanup operation time | > 60 seconds |

### Health Check Query

```sql
-- Check audit log health
SELECT
  COUNT(*) as total_events,
  MIN(timestamp) as oldest_event,
  MAX(timestamp) as newest_event,
  julianday('now') - julianday(MIN(timestamp)) as oldest_age_days
FROM audit_logs;
```

---

## Troubleshooting

### Cleanup Taking Too Long

For databases with millions of entries:

1. **Batch the cleanup** by running multiple smaller deletes:
   ```typescript
   // Instead of deleting all at once
   for (let i = 0; i < 10; i++) {
     const deleted = auditLogger.cleanupOldLogs(90)
     if (deleted < 10000) break  // No more to delete
     await new Promise(r => setTimeout(r, 1000))  // Pause between batches
   }
   ```

2. **Run during off-peak hours** to minimize impact

3. **Consider archiving first** if you need the data for compliance

### Database File Growing Despite Cleanup

SQLite doesn't automatically reclaim disk space. Run `VACUUM` periodically:

```typescript
db.exec('VACUUM')
```

**Warning**: VACUUM requires temporary disk space equal to the database size.

---

## Security Considerations

1. **Never set retention below compliance requirements**
2. **Archive before deletion** for audit trail continuity
3. **Restrict cleanup permissions** to authorized operators
4. **Monitor cleanup operations** for anomalies (e.g., unexpected mass deletions)

---

## References

- [AuditLogger API Documentation](../../packages/core/src/security/AuditLogger.ts)
- [Security Index](../security/index.md)
- [SMI-733: Audit Logging System](https://linear.app/skillsmith/issue/SMI-733)
- [SMI-1012: Audit Log Retention Policy](https://linear.app/skillsmith/issue/SMI-1012)
