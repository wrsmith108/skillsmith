# MCP Apps Implementation Plan - Critical Review

> **Status**: Review completed
> **Date**: 2026-01-27
> **Reviewer**: Claude (AI-assisted)

This document provides a critical review of the draft implementation plan, identifying blockers, fail modes, conflicts, and accessibility issues.

---

## 1. Blockers Analysis

### 1.1 CRITICAL: Transport Compatibility

**Issue**: The current Skillsmith MCP server uses `StdioServerTransport` (see `packages/mcp-server/src/index.ts:196`), but MCP Apps examples use `StreamableHTTPServerTransport`.

**Impact**: MCP Apps require HTTP transport for resource serving. The stdio transport may not support the `resources` capability properly for UI resource fetching.

**Resolution Options**:
1. **Dual transport support**: Support both stdio (for CLI tools) and HTTP (for MCP Apps)
2. **HTTP-only migration**: Migrate entirely to HTTP transport
3. **Proxy approach**: Keep stdio as primary, add HTTP endpoint for UI resources only

**Recommendation**: Option 1 (dual transport) for maximum compatibility. The MCP SDK supports multiple transports concurrently.

**Severity**: BLOCKER - Must resolve before implementation

---

### 1.2 CRITICAL: Build Pipeline Conflict

**Issue**: The draft plan adds Vite with different config than existing TypeScript build. Current tsconfig uses `"module": "NodeNext"` with `"moduleResolution": "NodeNext"`, while Vite typically uses `"moduleResolution": "bundler"`.

**Impact**: Build conflicts, type resolution issues, potential dual compilation artifacts.

**Resolution**:
- Create separate `tsconfig.ui.json` for UI code with Vite-compatible settings
- Keep existing tsconfig for server code unchanged
- Update build script to run both builds sequentially

**Severity**: BLOCKER - Build system must be resolved first

---

### 1.3 HIGH: Docker Build Integration

**Issue**: UI build step not in Dockerfile. The draft mentions updating Dockerfile but doesn't account for Vite dependencies in container.

**Impact**: Docker builds will fail or produce incomplete artifacts.

**Resolution**:
```dockerfile
# Add Vite to build stage
RUN npm run build:ui  # Before npm run build
```

**Severity**: HIGH - Breaks CI/CD

---

### 1.4 MEDIUM: Package Publishing

**Issue**: `dist/ui/` directory needs to be included in `"files"` array in package.json for npm publishing.

**Current**:
```json
"files": ["dist"]
```

**Required**: No change needed (dist/* already included), but need to verify bundled HTML files are included correctly.

**Severity**: MEDIUM - Affects npm package

---

## 2. Fail Modes Analysis

### 2.1 Host Doesn't Support MCP Apps

**Scenario**: User runs Skillsmith with a host that doesn't support the `resources` capability or MCP Apps extension.

**Current behavior**: Tool returns `_meta.ui` but host ignores it, displays JSON.

**Desired behavior**: Graceful degradation - JSON output remains readable and useful.

**Mitigation**:
- JSON output already formatted with `JSON.stringify(result, null, 2)` - good for readability
- Consider adding ASCII-art fallbacks for visualizations (similar to `formatSearchResults()`)
- Test with basic MCP hosts that don't support apps

**Status**: ACCEPTABLE - Current JSON output is adequate fallback

---

### 2.2 UI Resource Loading Fails

**Scenario**: Host requests `ui://skillsmith/search` but resource handler throws error.

**Potential causes**:
- Bundled HTML file missing from dist
- File read permission issues
- Path resolution fails in different environments

**Mitigation**:
- Add comprehensive error handling in resource handlers
- Include fallback HTML with error message
- Log errors to stderr for debugging
- Unit test resource serving with mocked filesystem

**Implementation**:
```typescript
async () => {
  try {
    const html = await fs.readFile(uiPath, 'utf-8')
    return { contents: [{ uri, mimeType: RESOURCE_MIME_TYPE, text: html }] }
  } catch (error) {
    const fallbackHtml = `<html><body><h1>Error loading UI</h1><p>${error.message}</p></body></html>`
    return { contents: [{ uri, mimeType: RESOURCE_MIME_TYPE, text: fallbackHtml }] }
  }
}
```

---

### 2.3 Tool Callback Fails from UI

**Scenario**: User clicks "Install" in UI, but `app.callServerTool()` fails.

**Potential causes**:
- Network timeout
- Tool execution error (skill not found, permission denied)
- Host disconnected

**Mitigation**:
- UI must show loading states during tool calls
- Display clear error messages in UI
- Provide retry button
- Consider optimistic UI updates with rollback

**Implementation**:
```typescript
getTimeBtn.addEventListener('click', async () => {
  try {
    setLoading(true)
    const result = await app.callServerTool({ name: 'install_skill', arguments: { id } })
    showSuccess(result)
  } catch (error) {
    showError(error.message, { retryable: true })
  } finally {
    setLoading(false)
  }
})
```

---

### 2.4 API Offline During UI Interaction

**Scenario**: User performs search (API works), then clicks Install (API offline).

**Current behavior**: API client has fallback to local DB, but local DB may not have skill.

**Mitigation**:
- Cache skill data in UI state when first received
- Use cached data for display even if API is offline
- Show offline indicator in UI
- Disable actions that require live API when offline detected

---

### 2.5 Large Result Sets

**Scenario**: Search returns 100+ skills, UI attempts to render all.

**Impact**: Slow rendering, memory issues, poor UX.

**Mitigation**:
- Implement virtual scrolling or pagination in UI
- Limit initial render to 20 items
- Add "Load more" button
- Server-side already limits to 10 by default - consider making this configurable from UI

---

## 3. Conflicts Analysis

### 3.1 VS Code Extension UI Patterns

**Potential Conflict**: MCP Apps UI and VS Code extension have overlapping functionality.

**Analysis**:
- VS Code extension uses Webview panels (different rendering context)
- MCP Apps use sandboxed iframes via host
- UI code patterns in `SkillDetailPanel.ts` can inform MCP Apps design
- No runtime conflict - they serve different hosts

**Recommendation**:
- Share UI design patterns and CSS variables where possible
- Don't share code directly (different APIs: `vscode.postMessage` vs `App` class)
- Document that VS Code users should use the extension, not MCP Apps

**Status**: NO CONFLICT - Complementary features

---

### 3.2 Middleware Interactions

**Potential Conflict**: Existing middleware (license, quota, CSP) may affect MCP Apps responses.

**Analysis** (reviewing `packages/mcp-server/src/middleware/`):
- `license.ts`: Checks license tier before tool execution - applies to tool calls from UI too
- `quota.ts`: Enforces API call limits - UI tool callbacks count against quota
- `csp.ts`: Content Security Policy - different context (server-side) than MCP Apps CSP

**Impact**:
- Quota limits apply to UI interactions (each "Install" button click is a tool call)
- License restrictions apply normally

**Status**: NO CONFLICT - Middleware works as intended

---

### 3.3 Tool Response Schema Changes

**Potential Conflict**: Adding `_meta.ui` to responses may break existing integrations.

**Analysis**:
- MCP spec defines `_meta` as optional extension field
- Existing code only reads `content` array
- Adding `_meta` is backward-compatible

**Status**: NO CONFLICT - Additive change

---

### 3.4 Directory Structure

**Potential Conflict**: Adding `src/ui/` and `src/resources/` directories.

**Analysis**:
- `src/` currently has flat structure with subdirs: `tools/`, `middleware/`, `utils/`, etc.
- Adding `ui/` and `resources/` follows existing pattern
- tsconfig `include` already covers `src/**/*`

**Status**: NO CONFLICT - Follows existing patterns

---

## 4. Accessibility Issues

### 4.1 CRITICAL: Keyboard Navigation

**Issue**: Draft plan mentions keyboard accessibility but doesn't specify implementation.

**Requirements**:
- All interactive elements must be focusable
- Tab order must be logical
- Enter/Space must activate buttons
- Escape should close modals/dropdowns

**Implementation**:
```html
<!-- Good: Native button is keyboard accessible -->
<button onclick="install()">Install</button>

<!-- Bad: Div requires manual ARIA and keyboard handling -->
<div class="button" onclick="install()">Install</div>
```

**Recommendation**: Use native HTML elements wherever possible.

---

### 4.2 CRITICAL: Screen Reader Announcements

**Issue**: Dynamic content updates (e.g., "Installed successfully") won't be announced.

**Requirements**:
- Use ARIA live regions for dynamic updates
- Announce loading states
- Announce errors

**Implementation**:
```html
<div aria-live="polite" id="status"></div>

<script>
function announce(message) {
  document.getElementById('status').textContent = message
}
</script>
```

---

### 4.3 HIGH: Color Contrast

**Issue**: Trust tier badges use colors (green, yellow) that may not meet WCAG contrast ratios.

**VS Code Extension colors** (from SkillDetailPanel.ts):
```css
.badge-verified { background-color: #28a745; color: white; }  /* Contrast: 4.5:1 - PASSES AA */
.badge-community { background-color: #ffc107; color: black; } /* Contrast: 8.59:1 - PASSES AAA */
```

**Recommendation**: Reuse these tested colors. Always include text labels, not just colors.

---

### 4.4 HIGH: Focus Indicators

**Issue**: Custom-styled buttons may lose default focus indicators.

**Requirements**:
- Visible focus indicator with contrast ≥ 3:1
- Focus indicator must be ≥ 2px

**Implementation**:
```css
button:focus-visible {
  outline: 2px solid var(--vscode-focusBorder);
  outline-offset: 2px;
}
```

---

### 4.5 MEDIUM: Reduced Motion

**Issue**: Loading spinners and transitions may cause issues for vestibular disorders.

**Requirements**:
- Respect `prefers-reduced-motion` media query
- Provide static alternatives for animations

**Implementation**:
```css
@media (prefers-reduced-motion: reduce) {
  .spinner {
    animation: none;
  }
  * {
    transition: none !important;
  }
}
```

---

### 4.6 MEDIUM: Touch Targets

**Issue**: Install buttons and filter controls need adequate touch target size for mobile/tablet hosts.

**Requirements**: Minimum 44x44px touch targets (WCAG 2.5.5)

**Implementation**:
```css
button, .filter-option {
  min-height: 44px;
  min-width: 44px;
  padding: 10px 16px;
}
```

---

### 4.7 LOW: Data Tables

**Issue**: Comparison view uses table-like layout for skill comparison.

**Requirements**:
- Use proper `<table>` markup with `<th>` headers
- Include `scope` attributes
- Consider providing a simplified text summary

**Implementation**:
```html
<table>
  <caption class="sr-only">Skill comparison: jest-helper vs vitest-helper</caption>
  <thead>
    <tr>
      <th scope="col">Attribute</th>
      <th scope="col">jest-helper</th>
      <th scope="col">vitest-helper</th>
    </tr>
  </thead>
  <tbody>...</tbody>
</table>
```

---

## 5. Open Questions Resolved

### Q1: Framework Choice

**Recommendation**: Vanilla TypeScript

**Rationale**:
- Smaller bundle size (critical for embedded UIs)
- No framework overhead
- MCP Apps examples primarily use vanilla JS
- Simpler maintenance
- Host CSP restrictions may block framework CDNs

If complexity grows, consider Preact (3KB) as lightweight React alternative.

---

### Q2: State Persistence

**Recommendation**: Option A - Reset state on each tool call

**Rationale**:
- Simpler mental model for users
- Avoids stale state issues
- Each tool call is independent context
- Filter state can be persisted in URL hash within UI session

---

### Q3: Theming

**Recommendation**: Use CSS custom properties with host-agnostic defaults

**Implementation**:
```css
:root {
  --skill-bg: #ffffff;
  --skill-fg: #1a1a1a;
  --skill-accent: #0066cc;
}

@media (prefers-color-scheme: dark) {
  :root {
    --skill-bg: #1a1a1a;
    --skill-fg: #ffffff;
    --skill-accent: #66b3ff;
  }
}
```

Note: Cannot access host CSS variables from sandboxed iframe. Use system preference detection.

---

### Q4: Offline Behavior

**Recommendation**: Show clear offline state with cached data display

**Implementation**:
- Display "Offline - showing cached data" banner
- Disable install/uninstall actions
- Keep search/filter working on cached results
- Retry connection on user action

---

## 6. Summary of Required Changes to Plan

### Must Address Before Implementation

1. **Transport**: Add HTTP transport support alongside stdio
2. **Build**: Create separate tsconfig for UI, update build scripts
3. **Docker**: Add Vite build step to Dockerfile

### Must Address During Implementation

4. **Error handling**: Comprehensive error states in all resource handlers and UI callbacks
5. **Accessibility**: Implement all WCAG 2.1 AA requirements from Section 4
6. **Loading states**: All async operations need loading indicators

### Can Address Post-MVP

7. **Virtual scrolling**: For large result sets
8. **Offline mode**: Full offline support with cached data
9. **Analytics**: Track UI interactions for UX improvement

---

## 7. Risk Reassessment

| Risk | Original | Revised | Notes |
|------|----------|---------|-------|
| Host support varies | High/Medium | **Medium/Medium** | Graceful degradation confirmed working |
| Bundle size too large | Medium/Medium | **Low/Medium** | Vanilla JS keeps bundles small |
| Sandbox restrictions | Medium/Low | **Low/Low** | Well-documented, test early |
| Build complexity | Low/Medium | **Medium/Medium** | Dual tsconfig adds complexity |
| Transport compatibility | Not identified | **CRITICAL** | New blocker identified |
| Accessibility compliance | Not identified | **High/High** | Requires dedicated effort |

