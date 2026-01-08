# ADR-016: Vercel API Proxy for Custom Domain

**Status:** Accepted
**Date:** 2026-01-08
**Deciders:** William Smith
**Technical Story:** SMI-1182 (Configure api.skillsmith.app domain)

## Context

Skillsmith needs a custom domain (`api.skillsmith.app`) for the API to:
- Provide a professional, branded API endpoint
- Enable future migration flexibility (not tied to Supabase URL)
- Support CORS configuration centrally

### Options Considered

| Option | Cost | Pros | Cons |
|--------|------|------|------|
| **A: Supabase Custom Domains** | $10/mo | Native integration | Requires Pro plan add-on |
| **B: Vercel API Proxy** | $0 | Free, edge caching, flexible | Additional hop, slight latency |
| **C: Cloudflare Workers** | $0 | Free, powerful | Additional infrastructure to manage |
| **D: Direct Supabase URL** | $0 | Simplest | Unprofessional URL, vendor lock-in |

## Decision

**Use Vercel as an API proxy (Option B).**

Route `api.skillsmith.app` through Vercel Edge, which proxies requests to Supabase Edge Functions and PostgREST API.

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     Client      │────▶│  Vercel Edge    │────▶│    Supabase     │
│                 │     │ api.skillsmith  │     │  Edge Functions │
│  npm package    │     │     .app        │     │   + PostgREST   │
│  CLI            │     │                 │     │                 │
│  MCP server     │     │  - Rewrites     │     │  vrcnzpmndtro   │
└─────────────────┘     │  - CORS headers │     │  qxxoqkzy       │
                        │  - Health check │     │  .supabase.co   │
                        └─────────────────┘     └─────────────────┘
```

### Routing Rules

| Path | Destination |
|------|-------------|
| `/functions/v1/*` | Supabase Edge Functions |
| `/rest/v1/*` | Supabase PostgREST API |
| `/health` | Local Vercel health check |

## Consequences

### Positive

- **$0/month** vs $10/month for Supabase custom domains
- **Edge caching** available for GET requests (future optimization)
- **Vendor flexibility** - can swap Supabase without changing client URLs
- **Centralized CORS** - headers managed in one place
- **Health endpoint** - independent of Supabase availability

### Negative

- **Additional network hop** - ~10-50ms latency added
- **Vercel dependency** - adds another service to the stack
- **Debugging complexity** - errors may originate from either layer

### Mitigations

| Risk | Mitigation |
|------|------------|
| Latency | Vercel Edge is fast; measure and optimize if needed |
| Debugging | Health endpoint helps isolate issues |
| Vendor lock-in | Proxy is simple; can migrate to Cloudflare Workers if needed |

## Implementation

### Files Created

```
apps/api-proxy/
├── vercel.json       # Rewrite rules and headers
├── api/health.ts     # Health check endpoint
├── package.json      # Project configuration
└── README.md         # Documentation
```

### Deployment

```bash
cd apps/api-proxy
vercel --prod
vercel domains add api.skillsmith.app
```

### DNS Configuration (Cloudflare)

| Type | Name | Target | Proxy |
|------|------|--------|-------|
| CNAME | `api` | `cname.vercel-dns.com` | ON |

## Alternatives Rejected

### Supabase Custom Domains (Option A)
- Requires $10/month Pro plan add-on
- No additional benefits over Vercel proxy for our use case
- Less flexibility for future changes

### Direct Supabase URL (Option D)
- URL `vrcnzpmndtroqxxoqkzy.supabase.co` is not user-friendly
- Vendor lock-in - clients hardcode Supabase URL
- No central CORS control

## References

- [Vercel Rewrites Documentation](https://vercel.com/docs/edge-network/rewrites)
- [Supabase Custom Domains](https://supabase.com/docs/guides/platform/custom-domains)
- [PRD-V4](/docs/prd-v4.md) - Phase 6A requirements
