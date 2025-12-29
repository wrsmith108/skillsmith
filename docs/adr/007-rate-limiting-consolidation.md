# ADR-007: Rate Limiting Consolidation

**Status**: Accepted
**Date**: 2025-12-29
**Deciders**: Security Specialist
**Issue**: SMI-730

## Context

Skillsmith needs rate limiting to prevent abuse and DoS attacks across multiple surfaces:

1. **MCP Tool Endpoints**: Prevent excessive search/install/uninstall requests
2. **Source Adapters**: Prevent overwhelming external APIs (GitHub, GitLab, raw URLs)
3. **Security Scanner**: Prevent resource exhaustion from scanning operations
4. **Future APIs**: RESTful API endpoints (planned)

Currently, source adapters have basic rate limiting via `BaseSourceAdapter.waitForRateLimit()`, but it's a simple window-based approach with limitations:
- No burst capacity
- Window-based (binary: allow/deny)
- Not shared across adapters
- No per-IP or per-user tracking

## Decision

We will implement a **centralized Token Bucket Rate Limiter** with the following design:

### 1. Token Bucket Algorithm

**Why Token Bucket over other algorithms?**

| Algorithm | Pros | Cons | Our Use Case |
|-----------|------|------|--------------|
| **Fixed Window** | Simple, low memory | Burst at window boundaries | ❌ Can't handle bursts smoothly |
| **Sliding Window** | Smooth, accurate | Higher memory usage | ⚠️ Overkill for our scale |
| **Leaky Bucket** | Smooth output rate | No burst capacity | ❌ Too restrictive for API calls |
| **Token Bucket** | ✅ Allows bursts<br>✅ Smooth long-term rate<br>✅ Flexible | Slightly complex | ✅ **Perfect fit** |

Token bucket allows:
- **Burst traffic**: Users can make quick bursts of requests (up to `maxTokens`)
- **Steady long-term rate**: Tokens refill at constant rate (`refillRate`)
- **Fair queueing**: Requests consume tokens proportionally (e.g., expensive operations cost more)

### 2. Implementation Details

#### Core Configuration

```typescript
interface RateLimitConfig {
  maxTokens: number      // Bucket capacity (burst size)
  refillRate: number     // Tokens added per second
  windowMs: number       // Window for cleanup/TTL
  keyPrefix?: string     // Storage namespace
  debug?: boolean        // Enable logging
}
```

#### Token Bucket State

```typescript
interface TokenBucket {
  tokens: number         // Current tokens available
  lastRefill: number     // Last refill timestamp
  firstRequest: number   // Window start timestamp
}
```

#### Algorithm Flow

```
1. Get current bucket for key
2. Calculate elapsed time since lastRefill
3. Add tokens: min(maxTokens, current + elapsed * refillRate)
4. Check if tokens >= cost
5. If yes: Consume tokens, save state, return allowed
6. If no: Calculate retry time, return denied
```

### 3. Storage Interface

We define a pluggable storage interface:

```typescript
interface RateLimitStorage {
  get(key: string): Promise<TokenBucket | null>
  set(key: string, value: TokenBucket, ttlMs: number): Promise<void>
  delete(key: string): Promise<void>
  clear?(): Promise<void>
}
```

**Initial Implementation**: In-memory with periodic cleanup
**Future**: Redis adapter for distributed rate limiting

### 4. Presets

We provide presets for common use cases:

| Preset | Max Tokens | Refill Rate | Use Case |
|--------|------------|-------------|----------|
| `STRICT` | 10 | 0.167/sec (10/min) | Install operations |
| `STANDARD` | 30 | 0.5/sec (30/min) | Search, adapters |
| `RELAXED` | 60 | 1/sec (60/min) | Authenticated users |
| `GENEROUS` | 120 | 2/sec (120/min) | Internal tools |
| `HIGH_THROUGHPUT` | 300 | 5/sec (300/min) | Background jobs |

### 5. Integration Points

#### MCP Server Middleware

```typescript
// Per-tool rate limiting
const searchLimiter = createRateLimiterFromPreset('STANDARD')
const installLimiter = createRateLimiterFromPreset('STRICT')

// In tool handler
const result = await searchLimiter.checkLimit(`ip:${clientIp}`)
if (!result.allowed) {
  throw new Error(`Rate limited. Retry after ${result.retryAfterMs}ms`)
}
```

#### Source Adapters

```typescript
// Replace BaseSourceAdapter.waitForRateLimit()
protected async fetchWithRateLimit(url: string): Promise<Response> {
  const result = await this.rateLimiter.checkLimit(`adapter:${this.id}`)
  if (!result.allowed) {
    await delay(result.retryAfterMs!)
  }
  return fetch(url)
}
```

### 6. Error Handling

**Graceful Degradation**: On storage errors, allow requests (fail-open)

```typescript
try {
  return await checkLimit(key)
} catch (error) {
  log.error('Rate limiter error', error)
  return { allowed: true, ... } // Allow on error
}
```

### 7. Future Enhancements

1. **Redis Storage**: For distributed systems
2. **Dynamic Limits**: Adjust based on user tier
3. **Metrics**: Prometheus-compatible counters
4. **IP Detection**: Extract from MCP client metadata
5. **Cost-Based**: Expensive operations cost more tokens

## Consequences

### Positive

- ✅ **Flexible**: Token bucket handles bursts gracefully
- ✅ **Pluggable Storage**: Easy to add Redis later
- ✅ **Unified**: One rate limiter for all surfaces
- ✅ **Configurable**: Presets + custom configs
- ✅ **Observable**: State inspection, metrics-ready
- ✅ **Graceful**: Fails open on errors

### Negative

- ⚠️ **Memory**: In-memory storage doesn't scale across processes
- ⚠️ **Complexity**: More complex than fixed window
- ⚠️ **Clock Drift**: Relies on server time (mitigated by using `Date.now()`)

### Risks

| Risk | Mitigation |
|------|------------|
| Memory leak from abandoned buckets | Periodic cleanup every 60s |
| Storage errors blocking requests | Fail-open: allow on error |
| Clock skew causing inaccurate rates | Use monotonic timestamps |
| Too restrictive limits | Start with generous defaults, monitor |

## Implementation Checklist

- [x] Create `RateLimiter.ts` module
- [x] Implement `InMemoryRateLimitStorage`
- [x] Add presets (`STRICT`, `STANDARD`, etc.)
- [x] Write comprehensive tests
- [ ] Add MCP middleware (future)
- [ ] Integrate with source adapters (future)
- [ ] Add metrics/monitoring (future)
- [ ] Document in security index

## References

- [Token Bucket Algorithm - Wikipedia](https://en.wikipedia.org/wiki/Token_bucket)
- [Rate Limiting Patterns - Stripe](https://stripe.com/docs/rate-limits)
- [Redis Rate Limiting](https://redis.io/commands/incr#pattern-rate-limiter)
- SMI-730: Rate Limiting Implementation
- [docs/security/index.md](../security/index.md) - Line 46 mentions rate limiting
- [packages/core/src/sources/BaseSourceAdapter.ts](../../packages/core/src/sources/BaseSourceAdapter.ts) - Current rate limiting

## Related ADRs

- ADR-002: Docker/glibc Requirement
- ADR-006: Security Hardening (planned)

---

*This ADR documents the centralized rate limiting architecture for Skillsmith.*
