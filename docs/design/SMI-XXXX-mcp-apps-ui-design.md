# SMI-XXXX: MCP Apps UI Integration Design Document

> **Status**: Ready for Implementation
> **Author**: Claude (AI-assisted)
> **Date**: 2026-01-27
> **Last Updated**: 2026-01-27

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Background](#2-background)
3. [Goals and Non-Goals](#3-goals-and-non-goals)
4. [Technical Design](#4-technical-design)
5. [UI Component Specifications](#5-ui-component-specifications)
6. [Accessibility Requirements](#6-accessibility-requirements)
7. [Error Handling](#7-error-handling)
8. [Build and Deployment](#8-build-and-deployment)
9. [Testing Strategy](#9-testing-strategy)
10. [Implementation Phases](#10-implementation-phases)
11. [References](#11-references)

---

## 1. Executive Summary

This document describes the design for integrating MCP Apps UI capabilities into Skillsmith's MCP server. MCP Apps is an official MCP extension that enables tools to return interactive UI components rendered directly in the conversation within hosts like Claude, ChatGPT, VS Code, and Goose.

**Key Features**:
- Interactive skill search dashboard with real-time filtering
- Side-by-side skill comparison with visualizations
- Rich skill detail panels with score breakdowns
- Validation report UI with actionable error details
- Recommendation dashboard with contextual explanations

**Key Benefits**:
- Reduced cognitive load (visual vs. JSON parsing)
- Faster decision-making (interactive comparisons)
- Fewer round-trips (client-side filtering)
- Better discovery (visual recommendations)

---

## 2. Background

### 2.1 What is MCP Apps?

MCP Apps (announced January 2026) is an official MCP extension that allows MCP servers to return interactive HTML interfaces that render directly in the chat interface. Key characteristics:

- **Tools with UI metadata**: Tools include a `_meta.ui.resourceUri` field pointing to a UI resource
- **UI Resources**: Server-side resources served via the `ui://` scheme containing bundled HTML/JavaScript
- **Sandboxed rendering**: UIs render in isolated iframes with restricted permissions
- **Bidirectional communication**: Apps communicate with hosts via JSON-RPC over postMessage

### 2.2 Current Skillsmith Architecture

Skillsmith MCP server currently:
- Uses `StdioServerTransport` for CLI communication
- Returns JSON-formatted text responses
- Has 8 tools: `search`, `get_skill`, `install_skill`, `uninstall_skill`, `skill_recommend`, `skill_validate`, `skill_compare`, `skill_suggest`
- Includes a separate VS Code extension with webview-based UI

### 2.3 Why MCP Apps for Skillsmith?

| Current (JSON) | With MCP Apps |
|----------------|---------------|
| Parse JSON to understand results | Visual cards with badges and scores |
| Manual comparison of skills | Interactive side-by-side comparison |
| Re-invoke tool to change filters | Real-time client-side filtering |
| Read validation errors as text | Clickable error cards with fixes |

---

## 3. Goals and Non-Goals

### 3.1 Goals

1. **Enable interactive skill discovery** in Claude, ChatGPT, VS Code, and Goose
2. **Maintain backward compatibility** - Hosts without MCP Apps support receive JSON as before
3. **Meet WCAG 2.1 AA accessibility standards** for all UI components
4. **Keep bundle sizes under 50KB** per UI component for fast loading
5. **Support graceful degradation** when API or network is unavailable

### 3.2 Non-Goals

1. **Not replacing the VS Code extension** - MCP Apps complement, not replace
2. **Not building a standalone web application** - UIs only work within MCP hosts
3. **Not supporting offline-first scenarios** - Cached data display only, not full offline mode
4. **Not implementing complex state management** - Each tool call resets UI state

### 3.3 Success Metrics

| Metric | Target |
|--------|--------|
| UI renders correctly in all supported hosts | 100% |
| Time-to-interactive | <200ms |
| Accessibility violations (axe-core) | 0 critical/serious |
| Bundle size per component | <50KB |
| Backward compatibility | 100% |

---

## 4. Technical Design

### 4.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        MCP Host (Claude/VS Code/etc.)           │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Sandboxed Iframe                         ││
│  │  ┌─────────────────────────────────────────────────────────┐││
│  │  │              Skillsmith UI Component                    │││
│  │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                 │││
│  │  │  │ Search  │  │ Compare │  │ Detail  │ ...             │││
│  │  │  └────┬────┘  └────┬────┘  └────┬────┘                 │││
│  │  │       │            │            │                       │││
│  │  │       └────────────┴────────────┘                       │││
│  │  │                    │                                    │││
│  │  │          App.callServerTool()                           │││
│  │  │                    │                                    │││
│  │  └────────────────────┼────────────────────────────────────┘││
│  │                       │ postMessage                         ││
│  └───────────────────────┼─────────────────────────────────────┘│
│                          │                                      │
└──────────────────────────┼──────────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │    Skillsmith MCP       │
              │        Server           │
              │  ┌──────────────────┐   │
              │  │ StdioTransport   │◄──┼── CLI tools
              │  └──────────────────┘   │
              │  ┌──────────────────┐   │
              │  │ HTTP Transport   │◄──┼── MCP Apps resources
              │  └──────────────────┘   │
              │  ┌──────────────────┐   │
              │  │ Tool Handlers    │   │
              │  │ + UI Resources   │   │
              │  └──────────────────┘   │
              └─────────────────────────┘
```

### 4.2 Transport Strategy

**Challenge**: Current server uses `StdioServerTransport`, but MCP Apps require HTTP for resource serving.

**Solution**: Dual transport support with environment detection.

```typescript
// src/index.ts
import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js'

const server = new Server({
  name: 'skillsmith',
  version: '0.3.0',
}, {
  capabilities: {
    tools: {},
    resources: {},  // Enable resources for MCP Apps
  },
})

async function main() {
  // Check for HTTP mode (via environment variable or CLI flag)
  const httpMode = process.env.SKILLSMITH_HTTP_MODE === 'true' || process.argv.includes('--http')

  if (httpMode) {
    // HTTP transport for MCP Apps support
    const port = parseInt(process.env.SKILLSMITH_PORT || '3001', 10)
    await startHttpServer(server, port)
  } else {
    // Stdio transport for CLI/traditional MCP hosts
    const transport = new StdioServerTransport()
    await server.connect(transport)
  }
}
```

### 4.3 Package Structure

```
packages/mcp-server/
├── src/
│   ├── index.ts                    # Server entry (dual transport)
│   ├── context.ts                  # Tool context (unchanged)
│   ├── http-server.ts              # NEW: HTTP transport setup
│   ├── tools/                      # Existing tools
│   │   ├── search.ts               # Add _meta.ui to response
│   │   ├── compare.ts              # Add _meta.ui to response
│   │   ├── get-skill.ts            # Add _meta.ui to response
│   │   ├── validate.ts             # Add _meta.ui to response
│   │   └── recommend.ts            # Add _meta.ui to response
│   ├── resources/                  # NEW: UI resource handlers
│   │   ├── index.ts                # Resource registration
│   │   └── ui-resources.ts         # All UI resource handlers
│   └── ui/                         # NEW: UI source files
│       ├── shared/                 # Shared utilities
│       │   ├── app-utils.ts        # App class helpers
│       │   ├── accessibility.ts    # A11y utilities
│       │   └── styles.css          # Shared base styles
│       ├── search/
│       │   ├── index.html          # Entry point
│       │   └── app.ts              # Search UI logic
│       ├── compare/
│       │   ├── index.html
│       │   └── app.ts
│       ├── detail/
│       │   ├── index.html
│       │   └── app.ts
│       ├── validate/
│       │   ├── index.html
│       │   └── app.ts
│       └── recommend/
│           ├── index.html
│           └── app.ts
├── dist/
│   └── ui/                         # Bundled HTML (via Vite)
│       ├── search.html
│       ├── compare.html
│       ├── detail.html
│       ├── validate.html
│       └── recommend.html
├── tsconfig.json                   # Server TypeScript config
├── tsconfig.ui.json                # NEW: UI TypeScript config
├── vite.config.ts                  # NEW: Vite build config
└── package.json                    # Updated dependencies
```

### 4.4 Dependency Changes

```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.4",
    "@modelcontextprotocol/ext-apps": "^1.0.0",
    "@skillsmith/core": "*",
    "express": "^4.21.0",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "vite": "^6.0.0",
    "vite-plugin-singlefile": "^2.0.0",
    "@types/express": "^4.17.21",
    "@types/cors": "^2.8.17"
  }
}
```

### 4.5 Tool Response Modification

Each tool that supports UI adds `_meta.ui` to its response:

```typescript
// src/tools/search.ts
export async function executeSearch(input: SearchInput, context: ToolContext): Promise<MCPToolResponse> {
  const result = await performSearch(input, context)

  return {
    content: [{
      type: 'text',
      text: JSON.stringify(result, null, 2),
    }],
    _meta: {
      ui: {
        resourceUri: 'ui://skillsmith/search',
      },
    },
  }
}
```

### 4.6 Resource Registration

```typescript
// src/resources/ui-resources.ts
import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { registerAppResource, RESOURCE_MIME_TYPE } from '@modelcontextprotocol/ext-apps/server'
import fs from 'node:fs/promises'
import path from 'node:path'

const UI_COMPONENTS = ['search', 'compare', 'detail', 'validate', 'recommend'] as const

export function registerUIResources(server: Server): void {
  const uiDir = path.join(import.meta.dirname, '..', 'dist', 'ui')

  for (const component of UI_COMPONENTS) {
    const uri = `ui://skillsmith/${component}`

    registerAppResource(
      server,
      uri,  // template
      uri,  // uri
      { mimeType: RESOURCE_MIME_TYPE },
      async () => {
        try {
          const htmlPath = path.join(uiDir, `${component}.html`)
          const html = await fs.readFile(htmlPath, 'utf-8')
          return {
            contents: [{
              uri,
              mimeType: RESOURCE_MIME_TYPE,
              text: html,
            }],
          }
        } catch (error) {
          // Fallback error UI
          const errorHtml = generateErrorHtml(component, error as Error)
          return {
            contents: [{
              uri,
              mimeType: RESOURCE_MIME_TYPE,
              text: errorHtml,
            }],
          }
        }
      }
    )
  }
}

function generateErrorHtml(component: string, error: Error): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Error - ${component}</title>
  <style>
    body { font-family: system-ui; padding: 20px; color: #333; }
    .error { background: #fee; border: 1px solid #f99; padding: 16px; border-radius: 8px; }
    code { background: #f5f5f5; padding: 2px 6px; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="error" role="alert">
    <h1>Failed to load UI</h1>
    <p>The <code>${component}</code> UI component could not be loaded.</p>
    <p>Error: ${error.message}</p>
    <p>The tool result is still available as JSON in the conversation.</p>
  </div>
</body>
</html>`
}
```

---

## 5. UI Component Specifications

### 5.1 Search Dashboard (`ui://skillsmith/search`)

**Purpose**: Interactive skill discovery with filtering and sorting.

**Wireframe**:
```
┌────────────────────────────────────────────────────────────────┐
│ Search Results for "testing"                 [Sort: Score ▼]  │
├────────────────────────────────────────────────────────────────┤
│ Filters: [Category ▼] [Trust ▼] [Min Score: ══════●══ 70]     │
├────────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────────────┐  │
│ │ ✓ jest-helper                              87/100 ████▓░ │  │
│ │ Testing | community/jest-helper                          │  │
│ │ Generate Jest test cases for JavaScript projects         │  │
│ │ [Install] [Compare ☐]                                    │  │
│ └──────────────────────────────────────────────────────────┘  │
│ ┌──────────────────────────────────────────────────────────┐  │
│ │ ✓ vitest-helper                            92/100 █████░ │  │
│ │ Testing | community/vitest-helper                        │  │
│ │ Vitest testing utilities with native ESM support         │  │
│ │ [Install] [Compare ☐]                                    │  │
│ └──────────────────────────────────────────────────────────┘  │
│                                                                │
│ Showing 2 of 5 results | [Load More]                          │
├────────────────────────────────────────────────────────────────┤
│ Selected for comparison: 0 | [Compare Selected]               │
└────────────────────────────────────────────────────────────────┘
```

**State Interface**:
```typescript
interface SearchUIState {
  // Data from tool result
  results: SkillSearchResult[]
  total: number
  query: string

  // Client-side UI state
  filteredResults: SkillSearchResult[]
  filters: {
    category: SkillCategory | 'all'
    trustTier: TrustTier | 'all'
    minScore: number
  }
  sortBy: 'score' | 'name'
  sortOrder: 'asc' | 'desc'

  // Interaction state
  selectedForCompare: Set<string>  // skill IDs, max 5
  installingSkillId: string | null
  loadingMore: boolean
  error: string | null
}
```

**User Interactions**:
| Action | Behavior |
|--------|----------|
| Change filter | Client-side filter, no tool call |
| Change sort | Client-side sort, no tool call |
| Click Install | `app.callServerTool({ name: 'install_skill', arguments: { id } })` |
| Toggle Compare | Add/remove from `selectedForCompare` (max 5) |
| Click Compare Selected | `app.callServerTool({ name: 'skill_compare', arguments: { skill_ids } })` |
| Click skill card | `app.callServerTool({ name: 'get_skill', arguments: { id } })` |

---

### 5.2 Comparison View (`ui://skillsmith/compare`)

**Purpose**: Side-by-side skill comparison with visualizations.

**Wireframe**:
```
┌────────────────────────────────────────────────────────────────┐
│ Comparing Skills                                    [+ Add]   │
├───────────────────────────┬────────────────────────────────────┤
│     jest-helper           │     vitest-helper        🏆       │
├───────────────────────────┼────────────────────────────────────┤
│ Score          87         │ Score          92         ✓       │
│ ███████████░░░░░          │ ██████████████░░                   │
├───────────────────────────┼────────────────────────────────────┤
│ Trust     COMMUNITY       │ Trust     COMMUNITY               │
├───────────────────────────┼────────────────────────────────────┤
│ Quality        85         │ Quality        89         ✓       │
│ Security       95 ✓       │ Security       91                 │
│ Docs           72         │ Docs           88         ✓       │
│ Maintenance    80         │ Maintenance    94         ✓       │
├───────────────────────────┴────────────────────────────────────┤
│ Recommendation:                                                │
│ vitest-helper is recommended for its higher quality score     │
│ (92 vs 87) and better documentation.                          │
├────────────────────────────────────────────────────────────────┤
│ [Install jest-helper] [Install vitest-helper]                 │
└────────────────────────────────────────────────────────────────┘
```

**Accessibility Note**: Table uses proper `<table>` markup with `<th scope="col">` headers.

---

### 5.3 Skill Detail Panel (`ui://skillsmith/detail`)

**Purpose**: Rich skill information display.

**Wireframe**:
```
┌────────────────────────────────────────────────────────────────┐
│ jest-helper                               ✓ VERIFIED          │
│ by anthropic                                                   │
├────────────────────────────────────────────────────────────────┤
│ Generate Jest test cases and testing utilities for            │
│ JavaScript and TypeScript projects.                           │
├────────────────────────────────────────────────────────────────┤
│ ┌────────────────────┐  ┌────────────────────────────────────┐│
│ │ Score Breakdown    │  │ Quick Facts                       ││
│ │                    │  │ Category:    Testing              ││
│ │ Quality    ████░ 85│  │ Downloads:   12,450               ││
│ │ Security   █████ 95│  │ Last Update: 2 days ago           ││
│ │ Docs       ███░░ 72│  │ License:     MIT                  ││
│ │ Popularity ████░ 88│  │                                   ││
│ │ Maint.     ████░ 80│  │ Tags: [jest] [testing] [tdd]      ││
│ └────────────────────┘  └────────────────────────────────────┘│
├────────────────────────────────────────────────────────────────┤
│ [Install] [View Repository ↗] [View Documentation ↗]          │
└────────────────────────────────────────────────────────────────┘
```

---

### 5.4 Validation Report (`ui://skillsmith/validate`)

**Purpose**: Interactive validation results with actionable error details.

**Wireframe**:
```
┌────────────────────────────────────────────────────────────────┐
│ Validation: my-skill/SKILL.md                    [Re-validate]│
├────────────────────────────────────────────────────────────────┤
│ Status: ⚠ Valid with Warnings                                 │
│ ████████████████████░░░░░░░░░░ 12/15 checks passed            │
├────────────────────────────────────────────────────────────────┤
│ ❌ ERRORS (2)                                      [Collapse] │
│ ┌──────────────────────────────────────────────────────────┐  │
│ │ Line 15: Missing required field 'version'                │  │
│ │ Add version field to metadata section                    │  │
│ │ [Copy suggested fix]                                     │  │
│ └──────────────────────────────────────────────────────────┘  │
│ ┌──────────────────────────────────────────────────────────┐  │
│ │ Line 42: Invalid trigger pattern 'test*'                 │  │
│ │ Use glob pattern: 'test/**/*.ts'                         │  │
│ │ [Copy suggested fix]                                     │  │
│ └──────────────────────────────────────────────────────────┘  │
├────────────────────────────────────────────────────────────────┤
│ ⚠ WARNINGS (1)                                    [Expand ▶] │
├────────────────────────────────────────────────────────────────┤
│ ✅ PASSED (12)                                    [Expand ▶] │
└────────────────────────────────────────────────────────────────┘
```

---

### 5.5 Recommendations Dashboard (`ui://skillsmith/recommend`)

**Purpose**: Contextual skill recommendations with explanations.

**Wireframe**:
```
┌────────────────────────────────────────────────────────────────┐
│ Recommended for Your Project                                   │
│ Based on: package.json, installed skills, recent activity     │
├────────────────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────────────────┐  │
│ │ react-testing                          98% match         │  │
│ │ ██████████████████████████████░                          │  │
│ │                                                          │  │
│ │ "Detected React + Jest in your project. This skill adds  │  │
│ │  React-specific testing utilities."                      │  │
│ │                                                          │  │
│ │ [Install] [View Details] [Not Interested]                │  │
│ └──────────────────────────────────────────────────────────┘  │
│ ┌──────────────────────────────────────────────────────────┐  │
│ │ storybook-gen                          85% match         │  │
│ │ █████████████████████████░░░░░░                          │  │
│ │                                                          │  │
│ │ "You have components in src/components/. Generate        │  │
│ │  Storybook stories automatically."                       │  │
│ │                                                          │  │
│ │ [Install] [View Details] [Not Interested]                │  │
│ └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

## 6. Accessibility Requirements

All UI components must meet WCAG 2.1 Level AA compliance.

### 6.1 Keyboard Navigation

| Requirement | Implementation |
|-------------|----------------|
| All interactive elements focusable | Use native `<button>`, `<a>`, `<input>` elements |
| Logical tab order | DOM order matches visual order |
| Enter/Space activates buttons | Native behavior (no JS needed) |
| Arrow keys navigate lists | Add `role="listbox"` with `aria-activedescendant` |
| Escape closes dropdowns | Add keydown listener on dropdown |

### 6.2 Screen Reader Support

```html
<!-- Live region for dynamic announcements -->
<div aria-live="polite" aria-atomic="true" class="sr-only" id="announcer"></div>

<!-- Announce state changes -->
<script>
function announce(message) {
  document.getElementById('announcer').textContent = message
}

// Usage
announce('Installing jest-helper...')
announce('jest-helper installed successfully')
</script>
```

### 6.3 Color and Contrast

| Element | Foreground | Background | Ratio | Status |
|---------|------------|------------|-------|--------|
| Body text | #1a1a1a | #ffffff | 14.5:1 | AAA |
| Badge (verified) | #ffffff | #28a745 | 4.5:1 | AA |
| Badge (community) | #000000 | #ffc107 | 8.6:1 | AAA |
| Error text | #d32f2f | #ffffff | 5.9:1 | AA |
| Links | #0066cc | #ffffff | 5.3:1 | AA |

**Rule**: Never convey information by color alone. Always include text labels or icons.

### 6.4 Focus Indicators

```css
/* Visible focus for all interactive elements */
:focus-visible {
  outline: 2px solid #0066cc;
  outline-offset: 2px;
}

/* Remove default outline only when focus-visible handles it */
:focus:not(:focus-visible) {
  outline: none;
}
```

### 6.5 Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }

  .spinner {
    animation: none;
    /* Show static indicator instead */
    border-color: currentColor;
  }
}
```

### 6.6 Touch Targets

```css
/* Minimum 44x44px touch targets */
button,
.clickable,
input[type="checkbox"] + label {
  min-height: 44px;
  min-width: 44px;
  padding: 10px 16px;
}
```

### 6.7 Screen Reader Only Text

```css
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
```

---

## 7. Error Handling

### 7.1 Error Categories

| Category | Example | User-Facing Message |
|----------|---------|---------------------|
| Network | API timeout | "Connection failed. Please try again." |
| Not Found | Skill doesn't exist | "Skill 'xyz' not found. It may have been removed." |
| Permission | License tier restriction | "This feature requires Team tier. [Upgrade]" |
| Validation | Invalid skill ID | "Invalid skill ID format. Expected 'author/name'." |
| Server | Internal error | "Something went wrong. Please try again later." |

### 7.2 Error UI Component

```html
<div class="error-card" role="alert" aria-live="assertive">
  <div class="error-icon" aria-hidden="true">⚠</div>
  <div class="error-content">
    <h3 class="error-title">Connection Failed</h3>
    <p class="error-message">Unable to reach the Skillsmith API.</p>
    <div class="error-actions">
      <button class="btn-primary" onclick="retry()">Try Again</button>
      <button class="btn-secondary" onclick="dismiss()">Dismiss</button>
    </div>
  </div>
</div>
```

### 7.3 Loading States

Every async operation must show a loading indicator:

```html
<button id="install-btn" onclick="install()">
  <span class="btn-text">Install</span>
  <span class="btn-loading sr-only" aria-hidden="true">
    <span class="spinner"></span>
    Installing...
  </span>
</button>

<script>
function setLoading(btn, loading) {
  btn.disabled = loading
  btn.setAttribute('aria-busy', loading)
  btn.querySelector('.btn-text').hidden = loading
  const loadingEl = btn.querySelector('.btn-loading')
  loadingEl.hidden = !loading
  loadingEl.setAttribute('aria-hidden', !loading)
  if (loading) {
    announce('Installing skill...')
  }
}
</script>
```

---

## 8. Build and Deployment

### 8.1 TypeScript Configuration

**Server config** (`tsconfig.json`) - unchanged:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "dist",
    "rootDir": "."
  },
  "include": ["src/**/*"],
  "exclude": ["src/ui/**/*"]  // Exclude UI from server build
}
```

**UI config** (`tsconfig.ui.json`) - new:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "strict": true,
    "skipLibCheck": true,
    "outDir": "dist/ui-ts"
  },
  "include": ["src/ui/**/*"]
}
```

### 8.2 Vite Configuration

```typescript
// vite.config.ts
import { defineConfig } from 'vite'
import { viteSingleFile } from 'vite-plugin-singlefile'

export default defineConfig({
  plugins: [viteSingleFile()],
  build: {
    outDir: 'dist/ui',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        search: 'src/ui/search/index.html',
        compare: 'src/ui/compare/index.html',
        detail: 'src/ui/detail/index.html',
        validate: 'src/ui/validate/index.html',
        recommend: 'src/ui/recommend/index.html',
      },
      output: {
        entryFileNames: '[name].js',
        assetFileNames: '[name].[ext]',
      },
    },
  },
})
```

### 8.3 Build Scripts

```json
{
  "scripts": {
    "build:ui": "vite build",
    "build:server": "tsc -p tsconfig.json",
    "build": "npm run build:ui && npm run build:server",
    "dev:ui": "vite build --watch",
    "prepublishOnly": "npm run build && npm run test"
  }
}
```

### 8.4 Docker Integration

Update `Dockerfile`:
```dockerfile
FROM node:22-slim AS build

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .

# Build UI first (generates dist/ui/*.html)
RUN npm run build:ui

# Build server (generates dist/*.js)
RUN npm run build:server

# ... rest of Dockerfile
```

### 8.5 Package Files

Update `package.json` files array:
```json
{
  "files": [
    "dist"
  ]
}
```

The `dist/ui/` directory is automatically included since it's under `dist/`.

---

## 9. Testing Strategy

### 9.1 Unit Tests

**UI State Management**:
```typescript
// src/ui/search/__tests__/state.test.ts
import { filterResults, sortResults } from '../state'

describe('filterResults', () => {
  it('filters by category', () => {
    const results = [
      { id: '1', category: 'testing' },
      { id: '2', category: 'devops' },
    ]
    expect(filterResults(results, { category: 'testing' })).toHaveLength(1)
  })

  it('filters by minimum score', () => {
    const results = [
      { id: '1', score: 90 },
      { id: '2', score: 60 },
    ]
    expect(filterResults(results, { minScore: 70 })).toHaveLength(1)
  })
})
```

### 9.2 Integration Tests

**Resource Serving**:
```typescript
// src/resources/__tests__/ui-resources.test.ts
describe('UI Resources', () => {
  it('serves search UI resource', async () => {
    const server = createTestServer()
    registerUIResources(server)

    const result = await server.readResource('ui://skillsmith/search')

    expect(result.contents[0].mimeType).toBe('text/html')
    expect(result.contents[0].text).toContain('<!DOCTYPE html>')
  })

  it('returns error HTML for missing files', async () => {
    // Mock fs.readFile to throw
    const result = await server.readResource('ui://skillsmith/missing')

    expect(result.contents[0].text).toContain('Failed to load UI')
  })
})
```

### 9.3 Accessibility Tests

**Automated (axe-core)**:
```typescript
// src/ui/search/__tests__/a11y.test.ts
import { axe, toHaveNoViolations } from 'jest-axe'

expect.extend(toHaveNoViolations)

describe('Search UI Accessibility', () => {
  it('has no accessibility violations', async () => {
    document.body.innerHTML = await loadSearchUI()

    const results = await axe(document.body)
    expect(results).toHaveNoViolations()
  })
})
```

**Manual Testing Checklist**:
- [ ] Navigate all UI with keyboard only
- [ ] Test with VoiceOver (macOS)
- [ ] Test with NVDA (Windows)
- [ ] Verify color contrast with browser devtools
- [ ] Test with prefers-reduced-motion enabled

### 9.4 E2E Tests

**Test with basic-host**:
```bash
# Terminal 1: Start Skillsmith MCP server in HTTP mode
SKILLSMITH_HTTP_MODE=true npm run dev

# Terminal 2: Start basic-host pointing to Skillsmith
cd ext-apps/examples/basic-host
SERVERS='["http://localhost:3001"]' npm start

# Terminal 3: Run Playwright tests
npx playwright test
```

### 9.5 Cross-Host Testing

| Host | Version | Test Method |
|------|---------|-------------|
| Claude (web) | Latest | Manual via cloudflared tunnel |
| Claude Desktop | Latest | Manual with local server |
| VS Code Insiders | Latest | Manual with MCP extension |
| basic-host | Latest | Automated E2E |

---

## 10. Implementation Phases

### Phase 1: Foundation (1-2 weeks)

**Deliverables**:
- HTTP transport support alongside stdio
- Vite build configuration and UI build pipeline
- Resource registration infrastructure
- Search UI skeleton (static HTML, no interactions)

**Acceptance Criteria**:
- `npm run build` produces `dist/ui/search.html`
- Server starts in HTTP mode with `--http` flag
- `ui://skillsmith/search` resource serves HTML
- Search tool returns `_meta.ui` in response
- UI renders in basic-host

### Phase 2: Search Dashboard (2 weeks)

**Deliverables**:
- Complete search UI with filtering and sorting
- Install action integration
- Compare selection (max 5)
- Full accessibility compliance

**Acceptance Criteria**:
- All filters work client-side (no tool re-invocation)
- Install button triggers `install_skill` tool
- axe-core reports 0 violations
- Keyboard navigation works end-to-end

### Phase 3: Comparison & Detail (2 weeks)

**Deliverables**:
- Comparison view with score visualizations
- Skill detail panel
- Navigation between components (search → detail)

**Acceptance Criteria**:
- Comparison shows up to 5 skills side-by-side
- Score breakdowns render as bar charts
- Detail panel shows all skill metadata
- "Add to compare" from detail view works

### Phase 4: Validation & Recommendations (2 weeks)

**Deliverables**:
- Validation report UI
- Recommendations dashboard
- Error handling across all components

**Acceptance Criteria**:
- Validation errors are expandable/collapsible
- Copy-to-clipboard works for fixes
- Recommendations show match percentages
- "Not interested" action works

### Phase 5: Polish & Release (1-2 weeks)

**Deliverables**:
- Performance optimization
- Cross-host compatibility testing
- Documentation updates
- Release preparation

**Acceptance Criteria**:
- Bundle size <50KB per component
- Time-to-interactive <200ms
- Works in Claude, VS Code, basic-host
- CLAUDE.md updated with HTTP mode instructions

---

## 11. References

### 11.1 MCP Apps Documentation

- [MCP Apps Official Documentation](https://modelcontextprotocol.io/docs/extensions/apps)
- [MCP Apps SDK API Reference](https://modelcontextprotocol.github.io/ext-apps/api/)
- [MCP Apps GitHub Repository](https://github.com/modelcontextprotocol/ext-apps)
- [MCP Apps Blog Announcement](https://blog.modelcontextprotocol.io/posts/2026-01-26-mcp-apps/)

### 11.2 Example Servers

- [customer-segmentation-server](https://github.com/modelcontextprotocol/ext-apps/tree/main/examples/customer-segmentation-server) - Data exploration patterns
- [pdf-server](https://github.com/modelcontextprotocol/ext-apps/tree/main/examples/pdf-server) - Document viewing
- [basic-server-vanillajs](https://github.com/modelcontextprotocol/ext-apps/tree/main/examples/basic-server-vanillajs) - Vanilla JS template

### 11.3 Skillsmith Internal

- [ADR-009: Embedding Service Fallback Strategy](../adr/009-embedding-service-fallback.md)
- [ADR-013: Open Core Licensing](../adr/013-open-core-licensing.md)
- [VS Code Extension SkillDetailPanel](../../packages/vscode-extension/src/views/SkillDetailPanel.ts) - UI pattern reference

### 11.4 Accessibility

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [axe-core Testing Library](https://github.com/dequelabs/axe-core)

---

## Appendix A: UI Implementation Example

Complete example of the Search UI app:

```typescript
// src/ui/search/app.ts
import { App } from '@modelcontextprotocol/ext-apps'

interface SkillResult {
  id: string
  name: string
  description: string
  author: string
  category: string
  trustTier: string
  score: number
}

interface SearchToolResult {
  results: SkillResult[]
  total: number
  query: string
}

// State
let state = {
  results: [] as SkillResult[],
  filteredResults: [] as SkillResult[],
  filters: { category: 'all', trustTier: 'all', minScore: 0 },
  selectedForCompare: new Set<string>(),
  installing: null as string | null,
}

// DOM elements
const resultsContainer = document.getElementById('results')!
const announcer = document.getElementById('announcer')!
const categoryFilter = document.getElementById('category-filter') as HTMLSelectElement
const trustFilter = document.getElementById('trust-filter') as HTMLSelectElement
const scoreSlider = document.getElementById('score-slider') as HTMLInputElement

// Initialize MCP App
const app = new App({ name: 'Skillsmith Search', version: '1.0.0' })
app.connect()

// Handle initial tool result
app.ontoolresult = (result) => {
  const data = JSON.parse(result.content?.find(c => c.type === 'text')?.text || '{}') as SearchToolResult
  state.results = data.results
  applyFilters()
  render()
  announce(`Found ${data.total} skills for "${data.query}"`)
}

// Filter handlers
categoryFilter.addEventListener('change', () => {
  state.filters.category = categoryFilter.value
  applyFilters()
  render()
})

trustFilter.addEventListener('change', () => {
  state.filters.trustTier = trustFilter.value
  applyFilters()
  render()
})

scoreSlider.addEventListener('input', () => {
  state.filters.minScore = parseInt(scoreSlider.value, 10)
  document.getElementById('score-value')!.textContent = scoreSlider.value
  applyFilters()
  render()
})

// Filter logic
function applyFilters() {
  state.filteredResults = state.results.filter(skill => {
    if (state.filters.category !== 'all' && skill.category !== state.filters.category) return false
    if (state.filters.trustTier !== 'all' && skill.trustTier !== state.filters.trustTier) return false
    if (skill.score < state.filters.minScore) return false
    return true
  })
}

// Render
function render() {
  resultsContainer.innerHTML = state.filteredResults.map(skill => `
    <article class="skill-card" data-id="${skill.id}">
      <header>
        <h2>${escapeHtml(skill.name)}</h2>
        <span class="badge badge-${skill.trustTier}">${skill.trustTier}</span>
        <span class="score">${skill.score}/100</span>
      </header>
      <p>${escapeHtml(skill.description)}</p>
      <footer>
        <button
          class="btn-primary install-btn"
          data-id="${skill.id}"
          ${state.installing === skill.id ? 'disabled aria-busy="true"' : ''}
        >
          ${state.installing === skill.id ? 'Installing...' : 'Install'}
        </button>
        <label class="compare-checkbox">
          <input
            type="checkbox"
            ${state.selectedForCompare.has(skill.id) ? 'checked' : ''}
            ${state.selectedForCompare.size >= 5 && !state.selectedForCompare.has(skill.id) ? 'disabled' : ''}
          >
          Compare
        </label>
      </footer>
    </article>
  `).join('')

  // Add event listeners
  document.querySelectorAll('.install-btn').forEach(btn => {
    btn.addEventListener('click', () => installSkill((btn as HTMLElement).dataset.id!))
  })

  document.querySelectorAll('.compare-checkbox input').forEach(checkbox => {
    checkbox.addEventListener('change', (e) => {
      const id = (e.target as HTMLElement).closest('.skill-card')!.getAttribute('data-id')!
      if ((e.target as HTMLInputElement).checked) {
        state.selectedForCompare.add(id)
      } else {
        state.selectedForCompare.delete(id)
      }
      render()
    })
  })
}

// Install action
async function installSkill(id: string) {
  state.installing = id
  render()
  announce(`Installing ${id}...`)

  try {
    await app.callServerTool({ name: 'install_skill', arguments: { id } })
    announce(`${id} installed successfully`)
  } catch (error) {
    announce(`Failed to install ${id}: ${(error as Error).message}`)
  } finally {
    state.installing = null
    render()
  }
}

// Accessibility
function announce(message: string) {
  announcer.textContent = message
}

function escapeHtml(str: string): string {
  const div = document.createElement('div')
  div.textContent = str
  return div.innerHTML
}
```

---

## Appendix B: Backward Compatibility

Hosts that don't support MCP Apps will:

1. **Ignore `_meta.ui`**: The MCP spec defines `_meta` as optional metadata
2. **Display JSON**: The `content[0].text` field contains formatted JSON
3. **Function normally**: All tool functionality remains intact

Example of what a non-MCP-Apps host sees:

```json
{
  "results": [
    {
      "id": "community/jest-helper",
      "name": "jest-helper",
      "description": "Generate Jest test cases...",
      "author": "anthropic",
      "category": "testing",
      "trustTier": "verified",
      "score": 87
    }
  ],
  "total": 1,
  "query": "testing",
  "timing": {
    "searchMs": 12,
    "totalMs": 15
  }
}
```

This JSON is readable and contains all relevant information.
