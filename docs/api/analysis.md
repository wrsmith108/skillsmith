# Analysis API Reference

This document provides complete API documentation for the `@skillsmith/core` analysis module, which provides multi-language codebase analysis for skill recommendations.

## Table of Contents

- [Types](#types)
- [Classes](#classes)
- [Adapters](#adapters)
- [Utility Functions](#utility-functions)

---

## Types

### SupportedLanguage

Enumeration of supported programming languages.

```typescript
type SupportedLanguage = 'typescript' | 'javascript' | 'python' | 'go' | 'rust' | 'java'
```

### ParseResult

Result of parsing a single file.

```typescript
interface ParseResult {
  imports: ImportInfo[]
  exports: ExportInfo[]
  functions: FunctionInfo[]
}
```

### ImportInfo

Information about an import statement.

```typescript
interface ImportInfo {
  /** Module specifier (e.g., 'react', './utils', 'os') */
  module: string
  /** Named imports (e.g., ['useState', 'useEffect']) */
  namedImports: string[]
  /** Default import name if present */
  defaultImport?: string
  /** Namespace import name if present (import * as X) */
  namespaceImport?: string
  /** Whether this is a type-only import */
  isTypeOnly: boolean
  /** Source file where import was found */
  sourceFile: string
  /** Source language */
  language?: SupportedLanguage
  /** Line number */
  line?: number
}
```

### ExportInfo

Information about an export declaration.

```typescript
interface ExportInfo {
  /** Exported name */
  name: string
  /** Kind of export */
  kind: ExportKind
  /** Whether this is a default export */
  isDefault: boolean
  /** Source file where export was found */
  sourceFile: string
  /** Source language */
  language?: SupportedLanguage
  /** Visibility (for Go, Rust, Java) */
  visibility?: 'public' | 'private' | 'protected' | 'internal'
  /** Line number */
  line?: number
}
```

### ExportKind

Type of exported declaration.

```typescript
type ExportKind =
  | 'function'
  | 'class'
  | 'variable'
  | 'type'
  | 'interface'
  | 'enum'
  | 'struct'   // Go, Rust
  | 'trait'    // Rust
  | 'module'   // Python, Rust
  | 'unknown'
```

### FunctionInfo

Information about a function declaration.

```typescript
interface FunctionInfo {
  /** Function name */
  name: string
  /** Number of parameters */
  parameterCount: number
  /** Whether function is async */
  isAsync: boolean
  /** Whether function is exported */
  isExported: boolean
  /** Source file where function was found */
  sourceFile: string
  /** Line number */
  line: number
  /** Source language */
  language?: SupportedLanguage
  /** Method receiver (Go) */
  receiver?: string
  /** Decorators (Python, Java) */
  decorators?: string[]
  /** Attributes (Rust) */
  attributes?: string[]
}
```

### CodebaseContext

Complete analysis result for a codebase.

```typescript
interface CodebaseContext {
  /** Root directory analyzed */
  rootPath: string
  /** All imports found in the codebase */
  imports: ImportInfo[]
  /** All exports found in the codebase */
  exports: ExportInfo[]
  /** All functions found in the codebase */
  functions: FunctionInfo[]
  /** Detected frameworks */
  frameworks: FrameworkInfo[]
  /** Dependencies from all package managers */
  dependencies: DependencyInfo[]
  /** File statistics */
  stats: {
    totalFiles: number
    filesByExtension: Record<string, number>
    filesByLanguage?: Record<SupportedLanguage, number>
    totalLines: number
  }
  /** Analysis metadata */
  metadata: {
    durationMs: number
    version: string
    languages?: SupportedLanguage[]
    cacheHitRate?: number
  }
}
```

### FrameworkInfo

Detected framework information.

```typescript
interface FrameworkInfo {
  /** Framework name */
  name: string
  /** Confidence level (0-1) */
  confidence: number
  /** Evidence for detection */
  evidence: string[]
}
```

### DependencyInfo

Package dependency information.

```typescript
interface DependencyInfo {
  /** Package name */
  name: string
  /** Version specifier */
  version: string
  /** Whether this is a dev dependency */
  isDev: boolean
}
```

### FrameworkRule

Rule for framework detection.

```typescript
interface FrameworkRule {
  /** Framework name */
  name: string
  /** Dependency indicators (package names) */
  depIndicators: string[]
  /** Import indicators (module specifiers) */
  importIndicators: string[]
}
```

### CacheStats

Cache performance statistics.

```typescript
interface CacheStats {
  /** Current size in bytes */
  size: number
  /** Number of entries */
  entries: number
  /** Maximum size in bytes */
  maxSize: number
  /** Cache hit rate (0-1) */
  hitRate: number
}
```

---

## Classes

### CodebaseAnalyzer

Main entry point for codebase analysis.

```typescript
class CodebaseAnalyzer {
  constructor(options?: AnalyzerOptions)

  /**
   * Analyze a codebase and extract context for skill recommendations
   * @param rootPath - Root directory of the codebase
   * @param options - Analysis options
   * @returns CodebaseContext with extracted information
   */
  analyze(rootPath: string, options?: AnalyzeOptions): Promise<CodebaseContext>

  /**
   * Parse a single file (for incremental updates)
   * @param filePath - Path to the file
   * @param content - File content
   * @param previousTree - Previous parse tree for incremental update
   */
  parseFile(filePath: string, content: string, previousTree?: unknown): Promise<ParseResult>

  /**
   * Get supported languages
   */
  getSupportedLanguages(): SupportedLanguage[]

  /**
   * Check if a language is supported
   */
  supportsLanguage(filePath: string): boolean

  /**
   * Clean up resources
   */
  dispose(): void
}
```

**Options:**

```typescript
interface AnalyzerOptions {
  /** Cache size in MB (default: 200) */
  cacheSizeMB?: number
}

interface AnalyzeOptions {
  /** Maximum files to analyze (default: 1000) */
  maxFiles?: number
  /** Directories to exclude (default: node_modules, dist, .git) */
  excludeDirs?: string[]
  /** Include dev dependencies in analysis */
  includeDevDeps?: boolean
}
```

**Example:**

```typescript
import { CodebaseAnalyzer } from '@skillsmith/core'

const analyzer = new CodebaseAnalyzer()
const context = await analyzer.analyze('/path/to/project', {
  maxFiles: 5000,
  excludeDirs: ['node_modules', 'dist', 'vendor'],
})

console.log(context.metadata.languages)  // ['typescript', 'python']
console.log(context.frameworks)          // [{ name: 'React', confidence: 0.95, ... }]

analyzer.dispose()
```

---

### LanguageRouter

Routes files to appropriate language adapters.

```typescript
class LanguageRouter {
  constructor(options?: LanguageRouterOptions)

  /**
   * Register a language adapter
   */
  registerAdapter(adapter: LanguageAdapter): void

  /**
   * Unregister a language adapter
   */
  unregisterAdapter(language: SupportedLanguage): boolean

  /**
   * Get adapter for a file path
   * @throws Error if no adapter found and throwOnUnsupported is true
   */
  getAdapter(filePath: string): LanguageAdapter

  /**
   * Try to get adapter (returns null instead of throwing)
   */
  tryGetAdapter(filePath: string): LanguageAdapter | null

  /**
   * Check if a file can be handled
   */
  canHandle(filePath: string): boolean

  /**
   * Get language for a file path
   */
  getLanguage(filePath: string): SupportedLanguage | null

  /**
   * Parse a file using the appropriate adapter
   */
  parseFile(content: string, filePath: string): ParseResult

  /**
   * Get list of supported languages
   */
  getSupportedLanguages(): SupportedLanguage[]

  /**
   * Get list of supported file extensions
   */
  getSupportedExtensions(): string[]

  /**
   * Get all framework detection rules from all adapters
   */
  getAllFrameworkRules(): FrameworkRule[]

  /**
   * Clean up all adapters
   */
  dispose(): void
}
```

**Options:**

```typescript
interface LanguageRouterOptions {
  /** Whether to throw on unsupported files (default: false) */
  throwOnUnsupported?: boolean
}
```

**Example:**

```typescript
import { LanguageRouter, TypeScriptAdapter, PythonAdapter, GoAdapter } from '@skillsmith/core'

const router = new LanguageRouter()
router.registerAdapter(new TypeScriptAdapter())
router.registerAdapter(new PythonAdapter())
router.registerAdapter(new GoAdapter())

// Route and parse
const result = router.parseFile(content, 'main.py')

// Get all framework rules across languages
const rules = router.getAllFrameworkRules()

router.dispose()
```

---

### ParseCache

LRU cache for parse results with memory-based eviction.

```typescript
class ParseCache {
  constructor(options?: ParseCacheOptions)

  /**
   * Get cached result if content unchanged
   * @returns Cached parse result or null
   */
  get(filePath: string, content: string): ParseResult | null

  /**
   * Store parse result in cache
   */
  set(filePath: string, content: string, result: ParseResult): void

  /**
   * Check if a file is cached
   */
  has(filePath: string): boolean

  /**
   * Invalidate cache entries for changed files
   */
  invalidate(filePaths: string[]): void

  /**
   * Invalidate entries matching a pattern
   */
  invalidatePattern(pattern: string): void

  /**
   * Clear entire cache
   */
  clear(): void

  /**
   * Get cache statistics
   */
  getStats(): CacheStats

  /**
   * Get number of cached entries
   */
  get size(): number

  /**
   * Reset hit/miss counters
   */
  resetStats(): void
}
```

**Options:**

```typescript
interface ParseCacheOptions {
  /** Maximum memory in MB (default: 200) */
  maxMemoryMB?: number
  /** TTL in milliseconds (default: no TTL) */
  ttlMs?: number
}
```

**Example:**

```typescript
import { ParseCache } from '@skillsmith/core'

const cache = new ParseCache({ maxMemoryMB: 100, ttlMs: 60000 })

// Check cache before parsing
const cached = cache.get('src/main.ts', content)
if (cached) {
  return cached
}

// Parse and cache
const result = adapter.parseFile(content, 'src/main.ts')
cache.set('src/main.ts', content, result)

// View stats
console.log(cache.getStats())
// { size: 1048576, entries: 50, maxSize: 104857600, hitRate: 0.85 }
```

---

### TreeCache

Cache for parsed AST trees to enable incremental parsing.

```typescript
class TreeCache {
  constructor(options?: TreeCacheOptions)

  /**
   * Get cached tree for a file
   */
  get(filePath: string): unknown | null

  /**
   * Store tree with version and content hash
   */
  set(filePath: string, tree: unknown | null, contentHash: string): void

  /**
   * Check if tree is still valid for content
   */
  isValid(filePath: string, contentHash: string): boolean

  /**
   * Check if a file has a cached tree
   */
  has(filePath: string): boolean

  /**
   * Invalidate tree for a file
   */
  invalidate(filePath: string): void

  /**
   * Invalidate multiple files
   */
  invalidateMany(filePaths: string[]): void

  /**
   * Invalidate files matching pattern
   */
  invalidatePattern(pattern: RegExp): number

  /**
   * Get cache statistics
   */
  getStats(): TreeCacheStats

  /**
   * Clear all cached trees
   */
  clear(): void

  /**
   * Dispose and clean up
   */
  dispose(): void
}
```

**Options:**

```typescript
interface TreeCacheOptions {
  /** Maximum trees to cache (default: 100) */
  maxTrees?: number
}
```

---

### IncrementalParser

Coordinates incremental parsing across language adapters.

```typescript
class IncrementalParser {
  constructor(options?: IncrementalParserOptions)

  /**
   * Parse file, using incremental parsing if possible
   */
  parse(filePath: string, content: string, adapter: LanguageAdapter): IncrementalParseResult

  /**
   * Parse file with explicit edit information
   */
  parseWithEdit(
    filePath: string,
    content: string,
    adapter: LanguageAdapter,
    edit: FileEdit
  ): IncrementalParseResult

  /**
   * Invalidate cache for file(s)
   */
  invalidate(filePaths: string | string[]): void

  /**
   * Invalidate files matching a pattern
   */
  invalidatePattern(pattern: RegExp): number

  /**
   * Check if a file is cached
   */
  isCached(filePath: string): boolean

  /**
   * Get cache statistics
   */
  getStats(): IncrementalParserStats

  /**
   * Reset statistics
   */
  resetStats(): void

  /**
   * Clear all caches
   */
  clear(): void

  /**
   * Dispose of all resources
   */
  dispose(): void
}
```

**Types:**

```typescript
interface IncrementalParseResult {
  result: ParseResult
  wasIncremental: boolean
  durationMs: number
  wasCached: boolean
}

interface IncrementalParserOptions {
  maxTrees?: number
  cacheContent?: boolean
}

interface IncrementalParserStats {
  treeCache: TreeCacheStats
  contentCacheSize: number
  incrementalParses: number
  fullParses: number
  avgIncrementalTimeMs: number
  avgFullTimeMs: number
}
```

---

### ParserWorkerPool

Worker thread pool for parallel file parsing.

```typescript
class ParserWorkerPool extends EventEmitter {
  constructor(options?: WorkerPoolOptions)

  /**
   * Parse files in parallel using worker threads
   * @throws Error if pool has been disposed
   */
  parseFiles(tasks: ParseTask[]): Promise<WorkerResult[]>

  /**
   * Get pool statistics
   */
  getStats(): { poolSize: number; activeWorkers: number; queuedTasks: number }

  /**
   * Dispose of worker pool
   */
  dispose(): void
}
```

**Types:**

```typescript
interface ParseTask {
  filePath: string
  content: string
  language: string
}

interface WorkerResult {
  filePath: string
  result: ParseResult
  durationMs: number
  error?: string
}

interface WorkerPoolOptions {
  /** Number of workers (default: CPU cores - 1) */
  poolSize?: number
  /** Minimum batch size to use workers (default: 10) */
  minBatchForWorkers?: number
}
```

**Example:**

```typescript
import { ParserWorkerPool } from '@skillsmith/core'

const pool = new ParserWorkerPool({ poolSize: 4 })

const tasks = files.map(f => ({
  filePath: f.path,
  content: f.content,
  language: 'typescript'
}))

const results = await pool.parseFiles(tasks)
console.log(`Parsed ${results.length} files`)

pool.dispose()
```

---

### MemoryMonitor

Monitors memory usage and triggers cleanup when thresholds are exceeded.

```typescript
class MemoryMonitor {
  constructor(options?: MemoryMonitorOptions)

  /**
   * Get current memory statistics
   */
  getStats(): MemoryStats

  /**
   * Check memory and cleanup if needed
   */
  checkAndCleanup(): CleanupResult

  /**
   * Force cleanup regardless of threshold
   */
  forceCleanup(): CleanupResult

  /**
   * Start periodic monitoring
   * @returns Stop function
   */
  startMonitoring(intervalMs?: number): () => void

  /**
   * Stop periodic monitoring
   */
  stopMonitoring(): void

  /**
   * Get cleanup count
   */
  getCleanupCount(): number

  /**
   * Get total bytes freed
   */
  getTotalFreedBytes(): number

  /**
   * Check if monitoring is active
   */
  isMonitoring(): boolean

  /**
   * Get memory summary string
   */
  getSummary(): string

  /**
   * Format bytes for display (static)
   */
  static formatBytes(bytes: number): string
}
```

**Types:**

```typescript
interface MemoryStats {
  heapUsed: number
  heapTotal: number
  external: number
  arrayBuffers: number
  rss: number
  threshold: number
  isOverThreshold: boolean
}

interface CleanupResult {
  cleaned: boolean
  freedBytes: number
  reason?: string
}

interface MemoryMonitorOptions {
  thresholdMB?: number
  cache?: ParseCache
  verbose?: boolean
}
```

---

## Adapters

All adapters implement the `LanguageAdapter` abstract class:

```typescript
abstract class LanguageAdapter {
  abstract readonly language: SupportedLanguage
  abstract readonly extensions: string[]

  canHandle(filePath: string): boolean
  abstract parseFile(content: string, filePath: string): ParseResult
  abstract parseIncremental(content: string, filePath: string, previousTree?: unknown): ParseResult
  abstract getFrameworkRules(): FrameworkRule[]
  abstract dispose(): void
}
```

### TypeScriptAdapter

Parses TypeScript and JavaScript files using the TypeScript compiler API.

```typescript
class TypeScriptAdapter extends LanguageAdapter {
  readonly language: 'typescript'
  readonly extensions: ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs']
}
```

### PythonAdapter

Parses Python files using regex-based parsing.

```typescript
class PythonAdapter extends LanguageAdapter {
  readonly language: 'python'
  readonly extensions: ['.py', '.pyi', '.pyw']
}
```

**Detected Frameworks:** Django, FastAPI, Flask, pytest, pandas, numpy

### GoAdapter

Parses Go files using regex-based parsing. Handles Go's capitalization-based visibility.

```typescript
class GoAdapter extends LanguageAdapter {
  readonly language: 'go'
  readonly extensions: ['.go']
}
```

**Detected Frameworks:** Gin, Echo, Fiber, GORM, Cobra, Viper, Chi, Gorilla Mux, gRPC, testify

**Additional Types:**

```typescript
interface GoModInfo {
  module: string
  goVersion?: string
  require: Array<{ path: string; version: string }>
  replace: Array<{ old: string; new: string; version?: string }>
}

interface GoExportInfo extends ExportInfo {
  visibility: 'public' | 'private'
}

interface GoFunctionInfo extends FunctionInfo {
  receiver?: string
}
```

### RustAdapter

Parses Rust files using regex-based parsing. Handles `pub` visibility modifiers.

```typescript
class RustAdapter extends LanguageAdapter {
  readonly language: 'rust'
  readonly extensions: ['.rs']
}
```

**Detected Frameworks:** Actix, Rocket, Axum, Tokio, Serde, Diesel, SQLx, Clap, Warp, Reqwest, Hyper, Tonic, Tracing

**Additional Types:**

```typescript
interface CargoDependency {
  name: string
  version: string
  isDev: boolean
}

interface RustExportInfo extends ExportInfo {
  visibility: 'public' | 'private'
}

interface RustFunctionInfo extends FunctionInfo {
  attributes?: string[]
}
```

### JavaAdapter

Parses Java files using regex-based parsing. Handles visibility modifiers and annotations.

```typescript
class JavaAdapter extends LanguageAdapter {
  readonly language: 'java'
  readonly extensions: ['.java']
}
```

**Detected Frameworks:** Spring Boot, Spring, Quarkus, Micronaut, Jakarta EE, JUnit, Hibernate, Lombok, Maven, Gradle, TestNG, Mockito, Jackson, Gson, Apache Commons, SLF4J, Log4j

**Additional Types:**

```typescript
interface MavenDependency {
  groupId: string
  artifactId: string
  name: string
  version: string
  isDev: boolean
  scope?: string
}

interface JavaExportInfo extends ExportInfo {
  visibility: 'public' | 'private' | 'protected' | 'internal'
  isAbstract?: boolean
  isFinal?: boolean
}

interface JavaFunctionInfo extends FunctionInfo {
  decorators?: string[]
  isStatic?: boolean
  isSynchronized?: boolean
}
```

---

## Utility Functions

### parseGoMod

Parse go.mod file to extract module info and dependencies.

```typescript
function parseGoMod(content: string): GoModInfo
```

**Example:**

```typescript
import { parseGoMod } from '@skillsmith/core'

const info = parseGoMod(goModContent)
console.log(info.module)     // "github.com/user/project"
console.log(info.goVersion)  // "1.21"
console.log(info.require)    // [{ path: "github.com/gin-gonic/gin", version: "v1.9.1" }]
```

### parseCargoToml

Parse Cargo.toml to extract Rust dependencies.

```typescript
function parseCargoToml(content: string): CargoDependency[]
```

**Example:**

```typescript
import { parseCargoToml } from '@skillsmith/core'

const deps = parseCargoToml(cargoTomlContent)
console.log(deps)
// [{ name: "serde", version: "1.0", isDev: false },
//  { name: "tokio", version: "1.0", isDev: false }]
```

### parsePomXml

Parse Maven pom.xml to extract Java dependencies.

```typescript
function parsePomXml(content: string): { name: string; version: string; isDev: boolean }[]
```

**Example:**

```typescript
import { parsePomXml } from '@skillsmith/core'

const deps = parsePomXml(pomXmlContent)
console.log(deps)
// [{ name: "org.springframework:spring-core", version: "5.3.0", isDev: false }]
```

### parseBuildGradle

Parse Gradle build.gradle or build.gradle.kts to extract Java dependencies.

```typescript
function parseBuildGradle(content: string): { name: string; version: string; isDev: boolean }[]
```

**Example:**

```typescript
import { parseBuildGradle } from '@skillsmith/core'

const deps = parseBuildGradle(buildGradleContent)
console.log(deps)
// [{ name: "org.springframework:spring-core", version: "5.3.0", isDev: false }]
```

### calculateEdit

Calculate edit information from content diff.

```typescript
function calculateEdit(
  oldContent: string,
  newContent: string,
  changeStart: number,
  changeEnd: number,
  newText: string
): FileEdit
```

### indexToPosition

Convert character index to line/column position.

```typescript
function indexToPosition(content: string, index: number): Point

interface Point {
  row: number
  column: number
}
```

### streamFiles

Memory-efficient file streaming for large codebases.

```typescript
async function* streamFiles(
  files: string[],
  maxBufferSize?: number
): AsyncGenerator<FileContent>

interface FileContent {
  path: string
  content: string
  size: number
}
```

---

## See Also

- [Migration Guide](../guides/migration-v2.md)
- [Architecture Documentation](../architecture/multi-language-analysis.md)
- [ADR-010: Codebase Analysis Scope](../adr/010-codebase-analysis-scope.md)
