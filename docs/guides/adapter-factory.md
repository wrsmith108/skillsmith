# Adapter Factory Pattern Guide

**Related Issue**: [SMI-1339: Implement AdapterFactory pattern](https://linear.app/smith-horn-group/issue/SMI-1339)
**Architecture**: [Multi-Language Analysis](../architecture/multi-language-analysis.md)
**Introduced**: v2.0.0 (Wave 7)

## Overview

The `AdapterFactory` class provides a centralized way to create language adapters for codebase analysis. It implements the Factory pattern with lazy instantiation and optional caching to optimize resource usage.

### Why Use AdapterFactory?

**Before (Manual Instantiation)**:
```typescript
import { LanguageRouter } from '@skillsmith/core'
import { TypeScriptAdapter } from '@skillsmith/core'
import { PythonAdapter } from '@skillsmith/core'
import { GoAdapter } from '@skillsmith/core'
import { RustAdapter } from '@skillsmith/core'
import { JavaAdapter } from '@skillsmith/core'

const router = new LanguageRouter()
router.registerAdapter(new TypeScriptAdapter())
router.registerAdapter(new PythonAdapter())
router.registerAdapter(new GoAdapter())
router.registerAdapter(new RustAdapter())
router.registerAdapter(new JavaAdapter())
```

**After (Factory Pattern)**:
```typescript
import { LanguageRouter } from '@skillsmith/core'

// Single line - creates router with all adapters
const router = LanguageRouter.createWithAllAdapters()
```

### Benefits

| Benefit | Description |
|---------|-------------|
| **Lazy Instantiation** | Adapters are only created when needed |
| **Reduced Boilerplate** | Single method call replaces multiple imports and instantiations |
| **Caching Support** | Reuse adapter instances across multiple operations |
| **Centralized Management** | Single point for adapter lifecycle management |
| **Type Safety** | TypeScript support with `SupportedLanguage` type |
| **Resource Cleanup** | Proper disposal of cached adapters via `clearCache()` |

## Supported Languages

| Language | Identifier | Extensions | Adapter Class |
|----------|------------|------------|---------------|
| TypeScript | `typescript` | `.ts`, `.tsx`, `.mts`, `.cts` | `TypeScriptAdapter` |
| JavaScript | `javascript` | `.js`, `.jsx`, `.mjs`, `.cjs` | `TypeScriptAdapter` |
| Python | `python` | `.py`, `.pyi`, `.pyw` | `PythonAdapter` |
| Go | `go` | `.go` | `GoAdapter` |
| Rust | `rust` | `.rs` | `RustAdapter` |
| Java | `java` | `.java` | `JavaAdapter` |

Note: JavaScript uses the TypeScript adapter internally, as it handles both languages.

## API Reference

### createAdapter(language)

Creates a new adapter instance for the specified language.

```typescript
static createAdapter(language: SupportedLanguage): LanguageAdapter
```

**Parameters**:
- `language` - Language identifier (`'typescript'`, `'javascript'`, `'python'`, `'go'`, `'rust'`, `'java'`)

**Returns**: New `LanguageAdapter` instance

**Throws**: Error if language is not supported

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

const pythonAdapter = AdapterFactory.createAdapter('python')
const result = pythonAdapter.parseFile(content, 'main.py')

// Don't forget to dispose when done
pythonAdapter.dispose()
```

**Important**: Each call creates a new instance. Remember to call `dispose()` when finished.

---

### createCachedAdapter(language)

Gets or creates a cached adapter for the specified language. Returns the same instance on subsequent calls.

```typescript
static createCachedAdapter(language: SupportedLanguage): LanguageAdapter
```

**Parameters**:
- `language` - Language identifier

**Returns**: Cached or newly created `LanguageAdapter` instance

**Throws**: Error if language is not supported

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

// First call creates the adapter
const adapter1 = AdapterFactory.createCachedAdapter('typescript')

// Subsequent calls return the same instance
const adapter2 = AdapterFactory.createCachedAdapter('typescript')

console.log(adapter1 === adapter2) // true

// Clean up all cached adapters when done
AdapterFactory.clearCache()
```

**Use When**: You need to parse multiple files with the same language and want to reuse the adapter instance.

---

### createAll()

Creates adapters for all supported languages.

```typescript
static createAll(): Map<SupportedLanguage, LanguageAdapter>
```

**Returns**: Map of language to adapter for all 6 supported languages

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

const adapters = AdapterFactory.createAll()

// Iterate over all adapters
for (const [language, adapter] of adapters) {
  console.log(`${language}: ${adapter.extensions.join(', ')}`)
}

// typescript: .ts, .tsx, .js, .jsx, .mjs, .cjs, .mts, .cts
// javascript: .ts, .tsx, .js, .jsx, .mjs, .cjs, .mts, .cts
// python: .py, .pyi, .pyw
// go: .go
// rust: .rs
// java: .java

// Clean up all adapters
for (const adapter of adapters.values()) {
  adapter.dispose()
}
```

**Note**: Creates new instances each time. Consider using `createCachedAdapter()` for reuse.

---

### createAdapters(languages)

Creates adapters for a specific subset of languages.

```typescript
static createAdapters(languages: SupportedLanguage[]): Map<SupportedLanguage, LanguageAdapter>
```

**Parameters**:
- `languages` - Array of language identifiers to create adapters for

**Returns**: Map of language to adapter for specified languages only

**Throws**: Error if any language is not supported

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

// Only create adapters for web languages
const webAdapters = AdapterFactory.createAdapters(['typescript', 'javascript'])

// Only create adapters for backend languages
const backendAdapters = AdapterFactory.createAdapters(['python', 'go', 'rust', 'java'])

// Clean up
for (const adapter of webAdapters.values()) {
  adapter.dispose()
}
```

---

### getSupportedLanguages()

Returns the list of all supported language identifiers.

```typescript
static getSupportedLanguages(): SupportedLanguage[]
```

**Returns**: Array of supported language identifiers

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

const languages = AdapterFactory.getSupportedLanguages()
console.log(languages)
// ['typescript', 'javascript', 'python', 'go', 'rust', 'java']
```

---

### isSupported(language)

Checks if a language is supported with type narrowing.

```typescript
static isSupported(language: string): language is SupportedLanguage
```

**Parameters**:
- `language` - Language string to check

**Returns**: `true` if supported, `false` otherwise. Acts as a type guard.

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

function processLanguage(lang: string) {
  if (AdapterFactory.isSupported(lang)) {
    // TypeScript now knows `lang` is SupportedLanguage
    const adapter = AdapterFactory.createAdapter(lang)
    // ...
  } else {
    console.warn(`Unsupported language: ${lang}`)
  }
}

// Check various inputs
AdapterFactory.isSupported('python')  // true
AdapterFactory.isSupported('cobol')   // false
AdapterFactory.isSupported('')        // false
```

---

### getExtensions(language)

Gets file extensions handled by an adapter without keeping it instantiated.

```typescript
static getExtensions(language: SupportedLanguage): string[]
```

**Parameters**:
- `language` - Language identifier

**Returns**: Array of file extensions (with dot prefix)

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

const tsExtensions = AdapterFactory.getExtensions('typescript')
console.log(tsExtensions)
// ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.mts', '.cts']

const pyExtensions = AdapterFactory.getExtensions('python')
console.log(pyExtensions)
// ['.py', '.pyi', '.pyw']
```

**Note**: Uses cached adapter if available, otherwise creates and immediately disposes a temporary one.

---

### getAllExtensions()

Gets a complete mapping of file extensions to languages.

```typescript
static getAllExtensions(): Map<string, SupportedLanguage>
```

**Returns**: Map of extension (lowercase, with dot) to language identifier

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

const extensionMap = AdapterFactory.getAllExtensions()

// Query extension mappings
extensionMap.get('.ts')   // 'typescript'
extensionMap.get('.tsx')  // 'typescript'
extensionMap.get('.js')   // 'javascript'
extensionMap.get('.py')   // 'python'
extensionMap.get('.go')   // 'go'
extensionMap.get('.rs')   // 'rust'
extensionMap.get('.java') // 'java'

// Language detection by extension
function detectLanguage(filePath: string): SupportedLanguage | undefined {
  const ext = path.extname(filePath).toLowerCase()
  return extensionMap.get(ext)
}

detectLanguage('src/main.py')      // 'python'
detectLanguage('src/app.tsx')      // 'typescript'
detectLanguage('src/unknown.xyz')  // undefined
```

**Extension Mapping Rules**:
- TypeScript-specific extensions (`.ts`, `.tsx`, `.mts`, `.cts`) map to `'typescript'`
- JavaScript-specific extensions (`.js`, `.jsx`, `.mjs`, `.cjs`) map to `'javascript'`
- All extensions are normalized to lowercase

---

### clearCache()

Disposes all cached adapters and clears the cache.

```typescript
static clearCache(): void
```

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

// Use cached adapters
const tsAdapter = AdapterFactory.createCachedAdapter('typescript')
const pyAdapter = AdapterFactory.createCachedAdapter('python')

// ... do work ...

// Clean up all cached adapters
AdapterFactory.clearCache()

// Cache is now empty
const stats = AdapterFactory.getCacheStats()
console.log(stats.size) // 0
```

**When to Call**:
- Before application shutdown
- After completing batch processing
- When memory pressure is detected
- In test `afterEach` hooks

---

### getCacheStats()

Returns statistics about the adapter cache.

```typescript
static getCacheStats(): { size: number; languages: SupportedLanguage[] }
```

**Returns**: Object with:
- `size` - Number of cached adapters
- `languages` - Array of cached language identifiers

**Example**:
```typescript
import { AdapterFactory } from '@skillsmith/core'

// Initially empty
let stats = AdapterFactory.getCacheStats()
console.log(stats) // { size: 0, languages: [] }

// Cache some adapters
AdapterFactory.createCachedAdapter('typescript')
AdapterFactory.createCachedAdapter('python')
AdapterFactory.createCachedAdapter('go')

stats = AdapterFactory.getCacheStats()
console.log(stats)
// { size: 3, languages: ['typescript', 'python', 'go'] }
```

## Integration with LanguageRouter

The `AdapterFactory` integrates seamlessly with `LanguageRouter` for file routing and parsing.

### Recommended Pattern

```typescript
import { LanguageRouter, AdapterFactory } from '@skillsmith/core'

// Option 1: Create router with all adapters (recommended)
const router = LanguageRouter.createWithAllAdapters()

// Option 2: Create router with specific adapters
const adapters = AdapterFactory.createAdapters(['typescript', 'python'])
const router2 = new LanguageRouter()
for (const adapter of adapters.values()) {
  router2.registerAdapter(adapter)
}

// Use the router
if (router.canHandle('src/main.py')) {
  const result = router.parseFile(content, 'src/main.py')
  console.log(result.imports)
}

// Clean up
router.dispose()
```

### File Analysis Workflow

```typescript
import { LanguageRouter, AdapterFactory } from '@skillsmith/core'
import { readFileSync, readdirSync, statSync } from 'fs'
import { join, extname } from 'path'

async function analyzeProject(projectPath: string) {
  const router = LanguageRouter.createWithAllAdapters()
  const extensionMap = AdapterFactory.getAllExtensions()
  const results = new Map<string, ParseResult>()

  function processDirectory(dirPath: string) {
    const entries = readdirSync(dirPath, { withFileTypes: true })

    for (const entry of entries) {
      const fullPath = join(dirPath, entry.name)

      if (entry.isDirectory() && !entry.name.startsWith('.')) {
        processDirectory(fullPath)
      } else if (entry.isFile()) {
        const ext = extname(entry.name).toLowerCase()
        const language = extensionMap.get(ext)

        if (language && router.canHandle(fullPath)) {
          const content = readFileSync(fullPath, 'utf-8')
          const result = router.parseFile(content, fullPath)
          results.set(fullPath, result)
        }
      }
    }
  }

  try {
    processDirectory(projectPath)
    return results
  } finally {
    router.dispose()
  }
}
```

## Best Practices

### 1. Choose the Right Creation Method

| Use Case | Method | Reason |
|----------|--------|--------|
| Single file, one-time | `createAdapter()` | Clean isolation, explicit lifecycle |
| Multiple files, same language | `createCachedAdapter()` | Reuse instance, better performance |
| Multi-language analysis | `createAll()` or `createAdapters()` | Batch creation |
| Feature detection | `isSupported()`, `getExtensions()` | No adapter instantiation needed |

### 2. Always Clean Up Resources

```typescript
// Option 1: Manual disposal for createAdapter()
const adapter = AdapterFactory.createAdapter('python')
try {
  // Use adapter
} finally {
  adapter.dispose()
}

// Option 2: Clear cache for cached adapters
try {
  const adapter = AdapterFactory.createCachedAdapter('python')
  // Use adapter (no dispose needed here)
} finally {
  AdapterFactory.clearCache()  // Clean up at end
}

// Option 3: Clean up Map of adapters
const adapters = AdapterFactory.createAll()
try {
  // Use adapters
} finally {
  for (const adapter of adapters.values()) {
    adapter.dispose()
  }
}
```

### 3. Use Caching for Batch Operations

```typescript
// Good: Reuse adapter for multiple files
const adapter = AdapterFactory.createCachedAdapter('python')
const results = pythonFiles.map(file =>
  adapter.parseFile(file.content, file.path)
)

// Avoid: Creating new adapter for each file
pythonFiles.forEach(file => {
  const adapter = AdapterFactory.createAdapter('python') // Wasteful!
  adapter.parseFile(file.content, file.path)
  adapter.dispose()
})
```

### 4. Validate Input Before Creating Adapters

```typescript
function analyzeFile(filePath: string, content: string) {
  const ext = path.extname(filePath).toLowerCase()
  const extensionMap = AdapterFactory.getAllExtensions()
  const language = extensionMap.get(ext)

  if (!language) {
    throw new Error(`Unsupported file type: ${ext}`)
  }

  const adapter = AdapterFactory.createAdapter(language)
  try {
    return adapter.parseFile(content, filePath)
  } finally {
    adapter.dispose()
  }
}
```

### 5. Clear Cache in Tests

```typescript
import { describe, beforeEach, afterEach } from 'vitest'
import { AdapterFactory } from '@skillsmith/core'

describe('MyAnalyzer', () => {
  beforeEach(() => {
    AdapterFactory.clearCache()  // Start fresh
  })

  afterEach(() => {
    AdapterFactory.clearCache()  // Clean up
  })

  it('parses Python files', () => {
    const adapter = AdapterFactory.createCachedAdapter('python')
    // Test...
  })
})
```

## Error Handling

### Unsupported Language

```typescript
try {
  // @ts-expect-error - Will throw at runtime
  const adapter = AdapterFactory.createAdapter('cobol')
} catch (error) {
  console.error(error.message)
  // "Unsupported language: cobol. Supported languages: typescript, javascript, python, go, rust, java"
}
```

### Safe Language Detection

```typescript
function safeGetAdapter(language: string) {
  if (!AdapterFactory.isSupported(language)) {
    const supported = AdapterFactory.getSupportedLanguages()
    throw new Error(
      `Language "${language}" is not supported. ` +
      `Choose from: ${supported.join(', ')}`
    )
  }
  return AdapterFactory.createAdapter(language)
}
```

## Performance Considerations

### Memory Usage

| Operation | Memory Impact | Notes |
|-----------|---------------|-------|
| `createAdapter()` | ~5-10MB per adapter | Includes parser state |
| `createCachedAdapter()` | Same, but shared | Single instance per language |
| `createAll()` | ~30-60MB total | All 6 adapters |
| `clearCache()` | Frees cached memory | Call when done |

### Timing

| Operation | Typical Duration |
|-----------|-----------------|
| First adapter creation | ~50-100ms (parser initialization) |
| Cached adapter retrieval | <1ms |
| `getExtensions()` (cached) | <1ms |
| `getExtensions()` (uncached) | ~50ms (creates temp adapter) |

## Related Documentation

- [Multi-Language Analysis Architecture](../architecture/multi-language-analysis.md) - System design
- [Migration Guide v2.0.0](./migration-v2.md) - Upgrade instructions
- [Tree-sitter WASM Setup](./tree-sitter-setup.md) - Parser configuration
- [ADR-010: Codebase Analysis Scope](../adr/010-codebase-analysis-scope.md) - Design decisions
