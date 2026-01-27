# Skillsmith MCP Apps Implementation Plan - DRAFT v1

> **Status**: Draft for review
> **Date**: 2026-01-27
> **Author**: Claude (AI-assisted)

## Executive Summary

This document outlines the implementation plan for integrating MCP Apps UI capabilities into Skillsmith's MCP server, enabling interactive skill discovery, comparison, and management directly within Claude and other MCP hosts.

---

## 1. Project Overview

### 1.1 Goals
- Transform Skillsmith's text-based tool responses into interactive UI experiences
- Reduce cognitive load for users browsing and comparing skills
- Enable real-time filtering and interaction without re-invoking tools
- Maintain backward compatibility with hosts that don't support MCP Apps

### 1.2 Non-Goals
- Replacing the VS Code extension (complementary, not replacement)
- Building a standalone web application
- Supporting offline-first scenarios in the UI layer

### 1.3 Success Metrics
- UI renders correctly in Claude, ChatGPT, VS Code, and Goose
- <200ms time-to-interactive for all UI components
- Zero accessibility violations (WCAG 2.1 AA)
- 100% backward compatibility (non-UI hosts receive JSON as before)

---

## 2. Technical Architecture

### 2.1 Package Structure Changes

```
packages/mcp-server/
├── src/
│   ├── index.ts              # Add resources capability
│   ├── tools/                # Existing tools
│   │   ├── search.ts         # Add _meta.ui to response
│   │   ├── compare.ts        # Add _meta.ui to response
│   │   └── ...
│   ├── resources/            # NEW: UI resource handlers
│   │   ├── index.ts          # Resource registration
│   │   ├── search-ui.ts      # Search dashboard resource
│   │   ├── compare-ui.ts     # Comparison view resource
│   │   ├── detail-ui.ts      # Skill detail resource
│   │   ├── validate-ui.ts    # Validation report resource
│   │   └── recommend-ui.ts   # Recommendations resource
│   └── ui/                   # NEW: UI source files
│       ├── search/
│       │   ├── index.html
│       │   └── app.ts
│       ├── compare/
│       │   ├── index.html
│       │   └── app.ts
│       └── ...
├── dist/
│   └── ui/                   # Bundled HTML files (via Vite)
├── vite.config.ts            # NEW: Vite config for UI bundling
└── package.json              # Add ext-apps dependency
```

### 2.2 Dependency Additions

```json
{
  "dependencies": {
    "@modelcontextprotocol/ext-apps": "^1.0.0"
  },
  "devDependencies": {
    "vite": "^6.0.0",
    "vite-plugin-singlefile": "^2.0.0"
  }
}
```

### 2.3 Server Capabilities Update

Current:
```typescript
capabilities: {
  tools: {},
}
```

Updated:
```typescript
capabilities: {
  tools: {},
  resources: {},  // NEW: Required for MCP Apps
}
```

### 2.4 Tool Response Changes

**Before (search tool):**
```typescript
return {
  content: [{ type: 'text', text: JSON.stringify(result) }],
}
```

**After (search tool):**
```typescript
return {
  content: [{ type: 'text', text: JSON.stringify(result) }],
  _meta: {
    ui: {
      resourceUri: 'ui://skillsmith/search',
    },
  },
}
```

### 2.5 Resource Registration

```typescript
// src/resources/index.ts
import { registerAppResource, RESOURCE_MIME_TYPE } from '@modelcontextprotocol/ext-apps/server'
import fs from 'node:fs/promises'
import path from 'node:path'

export function registerUIResources(server: Server) {
  const uiDir = path.join(import.meta.dirname, '..', 'dist', 'ui')

  // Search UI
  registerAppResource(
    server,
    'ui://skillsmith/search',
    'ui://skillsmith/search',
    { mimeType: RESOURCE_MIME_TYPE },
    async () => {
      const html = await fs.readFile(path.join(uiDir, 'search.html'), 'utf-8')
      return {
        contents: [{
          uri: 'ui://skillsmith/search',
          mimeType: RESOURCE_MIME_TYPE,
          text: html
        }],
      }
    }
  )

  // Register other UI resources...
}
```

---

## 3. UI Component Specifications

### 3.1 Search Dashboard (`ui://skillsmith/search`)

**Functionality:**
- Display search results as interactive cards
- Real-time client-side filtering (category, trust tier, min score)
- Sort controls (score, name, recency)
- Quick actions: Install, Compare, View Details

**Data Flow:**
1. Host calls `search` tool → returns JSON + `_meta.ui`
2. Host renders search UI in sandboxed iframe
3. `app.ontoolresult` receives initial results
4. User interacts with filters (client-side, no tool call)
5. User clicks "Install" → `app.callServerTool({ name: 'install_skill', arguments: { id } })`

**UI State:**
```typescript
interface SearchUIState {
  results: SkillSearchResult[]
  query: string
  filters: {
    category: string | null
    trustTier: string | null
    minScore: number
  }
  sortBy: 'score' | 'name' | 'recency'
  sortOrder: 'asc' | 'desc'
  selectedForCompare: string[]  // Max 5
}
```

### 3.2 Comparison View (`ui://skillsmith/compare`)

**Functionality:**
- Side-by-side skill comparison (2-5 skills)
- Score breakdown visualizations (bar charts)
- Difference highlighting with winner indicators
- Direct install buttons

**Data Flow:**
1. Host calls `skill_compare` tool → returns JSON + `_meta.ui`
2. `app.ontoolresult` receives comparison data
3. User can add more skills → `app.callServerTool({ name: 'get_skill' })`

### 3.3 Skill Detail Panel (`ui://skillsmith/detail`)

**Functionality:**
- Full skill metadata display
- Score breakdown visualization
- Repository/documentation links
- Install button with progress
- Related skills section

### 3.4 Validation Report (`ui://skillsmith/validate`)

**Functionality:**
- Pass/fail summary with progress bar
- Expandable error/warning sections
- Severity-based grouping
- Copy-to-clipboard for fixes

### 3.5 Recommendations Dashboard (`ui://skillsmith/recommend`)

**Functionality:**
- Personalized recommendation cards
- Match confidence visualization
- "Why recommended" explanations
- Quick dismiss/not interested actions

---

## 4. Build Process

### 4.1 Vite Configuration

```typescript
// vite.config.ts
import { defineConfig } from 'vite'
import { viteSingleFile } from 'vite-plugin-singlefile'

export default defineConfig({
  plugins: [viteSingleFile()],
  build: {
    outDir: 'dist/ui',
    rollupOptions: {
      input: {
        search: 'src/ui/search/index.html',
        compare: 'src/ui/compare/index.html',
        detail: 'src/ui/detail/index.html',
        validate: 'src/ui/validate/index.html',
        recommend: 'src/ui/recommend/index.html',
      },
    },
  },
})
```

### 4.2 Build Scripts

```json
{
  "scripts": {
    "build:ui": "vite build",
    "build": "npm run build:ui && tsc",
    "dev:ui": "vite build --watch"
  }
}
```

### 4.3 Docker Integration

Update `Dockerfile` to include Vite build step:
```dockerfile
RUN npm run build:ui
RUN npm run build
```

---

## 5. Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Add `@modelcontextprotocol/ext-apps` dependency
- [ ] Update server capabilities to include `resources`
- [ ] Create Vite build configuration
- [ ] Implement basic UI resource serving
- [ ] Create search UI skeleton (vanilla JS)
- [ ] Verify rendering in Claude and basic-host

### Phase 2: Search Dashboard (Week 3-4)
- [ ] Complete search UI with filtering
- [ ] Add install action integration
- [ ] Implement compare selection
- [ ] Accessibility audit and fixes
- [ ] Unit tests for UI state management

### Phase 3: Comparison & Detail (Week 5-6)
- [ ] Comparison view with visualizations
- [ ] Skill detail panel
- [ ] Cross-component navigation
- [ ] Integration tests

### Phase 4: Validation & Recommendations (Week 7-8)
- [ ] Validation report UI
- [ ] Recommendations dashboard
- [ ] End-to-end testing
- [ ] Documentation

### Phase 5: Polish & Release (Week 9-10)
- [ ] Performance optimization
- [ ] Cross-host compatibility testing
- [ ] Accessibility certification
- [ ] Release preparation

---

## 6. Risk Assessment

### 6.1 Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Host support varies | High | Medium | Graceful degradation to JSON |
| Bundle size too large | Medium | Medium | Code splitting, lazy loading |
| Sandbox restrictions | Medium | Low | Test early on all hosts |
| Build complexity | Low | Medium | Clear documentation |

### 6.2 Compatibility Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| VS Code extension conflict | Medium | Low | Different UI paradigm (webview vs MCP) |
| API client changes | Medium | Low | Version lock ext-apps |
| Breaking MCP SDK update | High | Low | Pin SDK versions |

---

## 7. Testing Strategy

### 7.1 Unit Tests
- UI state management logic
- Filter/sort functions
- Data transformation utilities

### 7.2 Integration Tests
- Tool call → UI render → User action → Tool callback
- Resource serving correctness
- Backward compatibility (non-UI hosts)

### 7.3 E2E Tests
- Claude Desktop rendering
- VS Code host rendering
- basic-host test harness

### 7.4 Accessibility Tests
- axe-core automated scanning
- Manual keyboard navigation
- Screen reader testing (VoiceOver, NVDA)

---

## 8. Open Questions

1. **Framework choice**: Vanilla JS vs React/Preact/Svelte?
   - Vanilla JS: Smaller bundle, no framework overhead
   - React: Team familiarity, component reuse from VS Code extension

2. **State persistence**: Should filter state persist across tool calls?
   - Option A: Reset on each tool call
   - Option B: Persist via `app.updateContext()`

3. **Theming**: Should UI respect host's dark/light mode?
   - Need to investigate host CSS variable exposure

4. **Offline behavior**: What happens when API is offline during UI interaction?
   - Need clear error states and fallback messaging

---

## Appendix A: Reference Examples

From MCP Apps examples repository:
- `customer-segmentation-server`: Data exploration with filtering (similar to search)
- `pdf-server`: Document viewing (similar to validation report)
- `wiki-explorer-server`: Navigation and discovery patterns

---

## Appendix B: Accessibility Requirements

- All interactive elements keyboard accessible
- ARIA labels on all visual-only indicators
- Color contrast ratio ≥ 4.5:1
- Focus indicators visible
- Reduced motion support
- Screen reader announcements for dynamic content

