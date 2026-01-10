# Migration Guide: Skillsmith v1.x to v2.0.0

This guide helps you migrate from Skillsmith Core v1.x to v2.0.0, which introduces multi-language codebase analysis.

## Overview

v2.0.0 adds support for analyzing codebases in 5 languages:

| Language | Extensions | Dependency Files |
|----------|------------|------------------|
| TypeScript | `.ts`, `.tsx`, `.mts`, `.cts` | `package.json` |
| JavaScript | `.js`, `.jsx`, `.mjs`, `.cjs` | `package.json` |
| Python | `.py`, `.pyi`, `.pyw` | `requirements.txt`, `pyproject.toml` |
| Go | `.go` | `go.mod` |
| Rust | `.rs` | `Cargo.toml` |
| Java | `.java` | `pom.xml`, `build.gradle` |

## No Breaking Changes

v2.0.0 is fully backward compatible. All existing v1.x APIs continue to work without modification:

```typescript
// This code works identically in v1.x and v2.0.0
import { CodebaseAnalyzer } from '@skillsmith/core'

const analyzer = new CodebaseAnalyzer()
const context = await analyzer.analyze('/path/to/project')
console.log(context.frameworks) // Detected frameworks
```

## What's New in v2.0.0

### 1. Multi-Language Support

The `CodebaseAnalyzer` now automatically detects and parses multiple languages:

```typescript
const context = await analyzer.analyze('/path/to/polyglot-project')

// New: See which languages were detected
console.log(context.metadata.languages)
// ['typescript', 'python', 'go']

// New: File counts by language
console.log(context.stats.filesByLanguage)
// { typescript: 45, python: 23, go: 12 }
```

### 2. Language Router

Route files to appropriate language adapters:

```typescript
import { LanguageRouter, TypeScriptAdapter, PythonAdapter, GoAdapter } from '@skillsmith/core'

const router = new LanguageRouter()
router.registerAdapter(new TypeScriptAdapter())
router.registerAdapter(new PythonAdapter())
router.registerAdapter(new GoAdapter())

// Check if a file is supported
router.canHandle('main.py') // true
router.canHandle('main.go') // true
router.canHandle('main.rs') // false (Rust adapter not registered)

// Parse a file
const result = router.parseFile(content, 'main.py')
console.log(result.imports, result.exports, result.functions)

// Get all registered languages
router.getSupportedLanguages() // ['typescript', 'python', 'go']

// Don't forget to clean up
router.dispose()
```

### 3. Language Adapters

Each language has a dedicated adapter implementing the `LanguageAdapter` interface:

```typescript
import {
  TypeScriptAdapter,
  PythonAdapter,
  GoAdapter,
  RustAdapter,
  JavaAdapter,
} from '@skillsmith/core'

// Use adapters directly for single-language analysis
const pythonAdapter = new PythonAdapter()
const result = pythonAdapter.parseFile(pythonCode, 'main.py')

// Access language-specific framework rules
const frameworks = pythonAdapter.getFrameworkRules()
// [{ name: 'Django', depIndicators: ['django'], ... }, ...]

pythonAdapter.dispose()
```

### 4. Parse Caching

Improve performance with LRU caching of parse results:

```typescript
import { ParseCache } from '@skillsmith/core'

const cache = new ParseCache({ maxMemoryMB: 100 })

// Check cache before parsing
const cached = cache.get('src/main.py', fileContent)
if (cached) {
  return cached // Use cached result
}

// Parse and cache
const result = adapter.parseFile(fileContent, 'src/main.py')
cache.set('src/main.py', fileContent, result)

// View cache statistics
const stats = cache.getStats()
console.log(`Hit rate: ${(stats.hitRate * 100).toFixed(1)}%`)
console.log(`Size: ${(stats.size / 1024 / 1024).toFixed(1)} MB`)

// Invalidate when files change
cache.invalidate(['src/modified.py', 'src/deleted.py'])
```

### 5. Incremental Parsing

Parse changes efficiently with tree caching:

```typescript
import { IncrementalParser, TypeScriptAdapter } from '@skillsmith/core'

const parser = new IncrementalParser({ maxTrees: 50 })
const adapter = new TypeScriptAdapter()

// First parse (full)
const result1 = parser.parse('src/main.ts', content1, adapter)
console.log(result1.wasIncremental) // false

// Second parse with small change (incremental)
const result2 = parser.parse('src/main.ts', content2, adapter)
console.log(result2.wasIncremental) // true
console.log(result2.durationMs) // < 100ms

// Check stats
const stats = parser.getStats()
console.log(`Incremental: ${stats.incrementalParses}, Full: ${stats.fullParses}`)

parser.dispose()
```

### 6. Worker Thread Pool

Parallelize parsing for large codebases:

```typescript
import { ParserWorkerPool } from '@skillsmith/core'

const pool = new ParserWorkerPool({ poolSize: 4 })

const tasks = files.map(f => ({
  filePath: f.path,
  content: f.content,
  language: 'typescript'
}))

const results = await pool.parseFiles(tasks)
console.log(`Parsed ${results.length} files in parallel`)

pool.dispose()
```

### 7. Memory Monitoring

Prevent memory exhaustion in large analyses:

```typescript
import { MemoryMonitor, ParseCache } from '@skillsmith/core'

const cache = new ParseCache({ maxMemoryMB: 200 })
const monitor = new MemoryMonitor({
  thresholdMB: 500,
  cache,
  verbose: true
})

// Start periodic monitoring (every 10 seconds)
const stopMonitoring = monitor.startMonitoring(10000)

// Check memory manually
const result = monitor.checkAndCleanup()
if (result.cleaned) {
  console.log(`Freed ${MemoryMonitor.formatBytes(result.freedBytes)}`)
}

// Get memory summary
console.log(monitor.getSummary())
// "Heap: 245.32 MB / 512.00 MB, RSS: 380.45 MB, Threshold: 500.00 MB, Status: OK"

// Stop monitoring when done
stopMonitoring()
```

### 8. Dependency Parsers

Parse language-specific dependency files:

```typescript
import {
  parseGoMod,
  parseCargoToml,
  parsePomXml,
  parseBuildGradle,
} from '@skillsmith/core'

// Go dependencies
const goMod = parseGoMod(goModContent)
console.log(goMod.module)  // "github.com/user/project"
console.log(goMod.require) // [{ path: "...", version: "..." }]

// Rust dependencies
const cargo = parseCargoToml(cargoTomlContent)
console.log(cargo) // [{ name: "serde", version: "1.0", isDev: false }]

// Java Maven dependencies
const maven = parsePomXml(pomXmlContent)
console.log(maven) // [{ name: "org.springframework:spring-core", version: "5.3.0", isDev: false }]

// Java Gradle dependencies
const gradle = parseBuildGradle(buildGradleContent)
console.log(gradle) // [{ name: "org.springframework:spring-core", version: "5.3.0", isDev: false }]
```

## New Types

### SupportedLanguage

```typescript
type SupportedLanguage = 'typescript' | 'javascript' | 'python' | 'go' | 'rust' | 'java'
```

### Extended ImportInfo

```typescript
interface ImportInfo {
  module: string
  namedImports: string[]
  defaultImport?: string
  namespaceImport?: string
  isTypeOnly: boolean
  sourceFile: string
  language?: SupportedLanguage  // NEW
  line?: number                 // NEW
}
```

### Extended ExportInfo

```typescript
interface ExportInfo {
  name: string
  kind: ExportKind
  isDefault: boolean
  sourceFile: string
  language?: SupportedLanguage                       // NEW
  visibility?: 'public' | 'private' | 'protected' | 'internal'  // NEW
  line?: number                                      // NEW
}
```

### Extended FunctionInfo

```typescript
interface FunctionInfo {
  name: string
  parameterCount: number
  isAsync: boolean
  isExported: boolean
  sourceFile: string
  line: number
  language?: SupportedLanguage  // NEW
  receiver?: string             // NEW (Go)
  decorators?: string[]         // NEW (Python, Java)
  attributes?: string[]         // NEW (Rust)
}
```

### Extended CodebaseContext

```typescript
interface CodebaseContext {
  // ... existing fields ...
  stats: {
    totalFiles: number
    filesByExtension: Record<string, number>
    filesByLanguage?: Record<SupportedLanguage, number>  // NEW
    totalLines: number
  }
  metadata: {
    durationMs: number
    version: string
    languages?: SupportedLanguage[]  // NEW
    cacheHitRate?: number            // NEW
  }
}
```

## Performance Improvements

| Metric | v1.x | v2.0.0 | Improvement |
|--------|------|--------|-------------|
| 10k file analysis | ~15s | <5s | 3x faster |
| Incremental parse | N/A | <100ms | New capability |
| Memory efficiency | - | LRU cache | ~30% reduction |
| Parallel parsing | Single-threaded | Worker pool | 4x on 4-core |

## Framework Detection

v2.0.0 adds framework detection for all supported languages:

| Language | Frameworks Detected |
|----------|---------------------|
| TypeScript/JS | React, Vue, Angular, Next.js, Express, Nest.js, Jest, Vitest, etc. |
| Python | Django, FastAPI, Flask, pytest, pandas, numpy |
| Go | Gin, Echo, Fiber, GORM, Cobra, gRPC, testify |
| Rust | Actix, Rocket, Axum, Tokio, Serde, Diesel, SQLx |
| Java | Spring Boot, Quarkus, Micronaut, JUnit, Hibernate, Lombok |

## Upgrade Steps

1. **Update dependency**:
   ```bash
   npm install @skillsmith/core@2.0.0
   ```

2. **No code changes required** - all v1.x code continues to work.

3. **Optional: Access new features**:
   ```typescript
   // Check languages detected
   if (context.metadata.languages) {
     console.log('Languages:', context.metadata.languages)
   }

   // Check files by language
   if (context.stats.filesByLanguage) {
     console.log('Files by language:', context.stats.filesByLanguage)
   }
   ```

## Docker Requirement

Multi-language parsing with tree-sitter requires native modules. Run all development and testing in Docker:

```bash
# Start container
docker compose --profile dev up -d

# Run commands
docker exec skillsmith-dev-1 npm run build
docker exec skillsmith-dev-1 npm test
```

See [ADR-002: Docker glibc Requirement](../adr/002-docker-glibc-requirement.md) for details.

## Questions?

- [Architecture Documentation](../architecture/multi-language-analysis.md)
- [API Reference](../api/analysis.md)
- [GitHub Issues](https://github.com/smith-horn-group/skillsmith/issues)
