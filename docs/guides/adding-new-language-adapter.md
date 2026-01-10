# Adding a New Language Adapter

SMI-1345: Step-by-step guide for implementing language adapters.

## Overview

Language adapters enable Skillsmith to analyze codebases written in different programming languages. Each adapter translates language-specific syntax into a unified `ParseResult` format containing imports, exports, and functions.

**Key insight from Wave 7**: Language adapters are naturally parallelizable - they have no shared state, use a common interface, follow similar structures, and have independent test suites.

## Prerequisites

Before creating a new adapter, ensure you have:

1. Docker development environment running (`docker compose --profile dev up -d`)
2. Familiarity with the target language's syntax (imports, exports, functions)
3. Understanding of regex patterns for parsing
4. (Optional) Tree-sitter grammar for the language

## Step-by-Step Guide

### Step 1: Update Type Definitions

First, add your language to the supported languages in `packages/core/src/analysis/types.ts`:

```typescript
// Add to SupportedLanguage union type
export type SupportedLanguage =
  | 'typescript'
  | 'javascript'
  | 'python'
  | 'go'
  | 'rust'
  | 'java'
  | 'ruby'  // <-- Add your language

// Add to LANGUAGE_EXTENSIONS mapping
export const LANGUAGE_EXTENSIONS: Record<SupportedLanguage, string[]> = {
  // ... existing languages
  ruby: ['.rb', '.rake', '.gemspec'],  // <-- Add extensions
}
```

### Step 2: Create the Adapter File

Copy the template to create your adapter:

```bash
# From project root
cp docs/templates/language-adapter-template.ts \
   packages/core/src/analysis/adapters/<language>.ts
```

For example, for Ruby:

```bash
cp docs/templates/language-adapter-template.ts \
   packages/core/src/analysis/adapters/ruby.ts
```

### Step 3: Implement the Adapter

Open your new adapter file and complete these tasks:

#### 3.1 Update Class Metadata

```typescript
export class RubyAdapter extends LanguageAdapter {
  readonly language: SupportedLanguage = 'ruby'
  readonly extensions = ['.rb', '.rake', '.gemspec']
  // ...
}
```

#### 3.2 Implement Import Extraction

Research your language's import syntax and create regex patterns:

```typescript
// Ruby example patterns
private extractImports(content: string, filePath: string): ImportInfo[] {
  const imports: ImportInfo[] = []
  const lines = content.split('\n')

  // require 'library'
  const requireRegex = /^require\s+['"]([^'"]+)['"]/

  // require_relative './local'
  const requireRelativeRegex = /^require_relative\s+['"]([^'"]+)['"]/

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim()

    if (line.startsWith('#') || line === '') continue

    const requireMatch = line.match(requireRegex)
    if (requireMatch) {
      imports.push({
        module: requireMatch[1],
        namedImports: [],
        isTypeOnly: false,
        sourceFile: filePath,
        language: 'ruby',
        line: i + 1,
      })
    }
    // Add more patterns...
  }

  return imports
}
```

#### 3.3 Implement Export Extraction

Determine how your language defines "exports":

| Language | Export Mechanism |
|----------|-----------------|
| Ruby | Public methods, classes, modules at top level |
| PHP | Classes, functions (no private prefix) |
| C++ | Non-static declarations in headers |
| C# | `public` visibility modifier |

```typescript
// Ruby example
private extractExports(content: string, filePath: string): ExportInfo[] {
  const exports: ExportInfo[] = []
  const lines = content.split('\n')

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]

    // Skip indented lines (methods inside classes)
    if (line.startsWith(' ') || line.startsWith('\t')) continue

    // Class definition at top level
    const classMatch = line.match(/^class\s+(\w+)/)
    if (classMatch && !classMatch[1].startsWith('_')) {
      exports.push({
        name: classMatch[1],
        kind: 'class',
        isDefault: false,
        sourceFile: filePath,
        language: 'ruby',
        line: i + 1,
      })
    }
    // Add more patterns...
  }

  return exports
}
```

#### 3.4 Implement Function Extraction

```typescript
// Ruby example
private extractFunctions(content: string, filePath: string): FunctionInfo[] {
  const functions: FunctionInfo[] = []
  const lines = content.split('\n')

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]

    // def method_name(params)
    const match = line.match(/^(\s*)def\s+(\w+)(?:\s*\(([^)]*)\))?/)
    if (match) {
      const indentation = match[1]
      const name = match[2]
      const paramsStr = match[3] || ''

      const params = paramsStr
        .split(',')
        .map(p => p.trim())
        .filter(p => p !== '')

      functions.push({
        name,
        parameterCount: params.length,
        isAsync: false,  // Ruby doesn't have async keyword
        isExported: indentation === '' && !name.startsWith('_'),
        sourceFile: filePath,
        language: 'ruby',
        line: i + 1,
      })
    }
  }

  return functions
}
```

#### 3.5 Add Framework Detection Rules

Research popular frameworks for your language:

```typescript
// Ruby example
getFrameworkRules(): FrameworkRule[] {
  return [
    {
      name: 'Rails',
      depIndicators: ['rails', 'railties'],
      importIndicators: ['rails', 'action_controller', 'active_record'],
    },
    {
      name: 'Sinatra',
      depIndicators: ['sinatra'],
      importIndicators: ['sinatra'],
    },
    {
      name: 'RSpec',
      depIndicators: ['rspec', 'rspec-core'],
      importIndicators: ['rspec'],
    },
    // Add more...
  ]
}
```

### Step 4: Create Tests

Copy the test template:

```bash
cp docs/templates/language-adapter-test-template.ts \
   packages/core/src/analysis/adapters/__tests__/<language>.test.ts
```

Update the tests with real code examples from your language:

```typescript
describe('RubyAdapter', () => {
  describe('parseFile - imports', () => {
    it('extracts require statements', () => {
      const content = `
require 'json'
require 'net/http'
require_relative './helper'
      `

      const result = adapter.parseFile(content, 'test.rb')

      expect(result.imports).toHaveLength(3)
      expect(result.imports[0].module).toBe('json')
      expect(result.imports[1].module).toBe('net/http')
      expect(result.imports[2].module).toBe('./helper')
    })
  })
})
```

### Step 5: Register the Adapter

Add your adapter to the `AdapterFactory` in `packages/core/src/analysis/adapters/factory.ts`:

```typescript
import { RubyAdapter } from './ruby.js'

export class AdapterFactory {
  private static adapters: Map<SupportedLanguage, LanguageAdapter> = new Map()

  static getAdapter(language: SupportedLanguage): LanguageAdapter {
    if (!this.adapters.has(language)) {
      switch (language) {
        // ... existing cases
        case 'ruby':
          this.adapters.set(language, new RubyAdapter())
          break
      }
    }
    return this.adapters.get(language)!
  }

  static getAdapterForFile(filePath: string): LanguageAdapter | null {
    // Adapter selection logic...
  }
}
```

### Step 6: Run Tests

```bash
# Run all tests
docker exec skillsmith-dev-1 npm test

# Run only your adapter tests
docker exec skillsmith-dev-1 npm test -- --grep "RubyAdapter"

# Check coverage
docker exec skillsmith-dev-1 npm run test:coverage
```

### Step 7: Add Tree-Sitter Support (Optional)

For enhanced parsing accuracy, add tree-sitter support:

1. Download the WASM file from [tree-sitter releases](https://github.com/AstroNvim/astraea) or build from source
2. Place in `packages/core/src/analysis/wasm/`
3. Update `initParser()` to load your language's WASM

## Common Patterns by Language

### Import Patterns

| Language | Pattern | Example |
|----------|---------|---------|
| Ruby | `require 'module'` | `require 'json'` |
| PHP | `use Namespace\Class` | `use App\Models\User;` |
| C++ | `#include <header>` | `#include <iostream>` |
| C# | `using Namespace;` | `using System.Linq;` |

### Export Patterns

| Language | Export Indicator |
|----------|-----------------|
| Ruby | Top-level class/module/def |
| PHP | Top-level class/function |
| C++ | Public class members, header declarations |
| C# | `public` keyword |

### Function Patterns

| Language | Regex Pattern |
|----------|--------------|
| Ruby | `/^(\s*)def\s+(\w+)/` |
| PHP | `/^(\s*)(?:public\|private\|protected)?\s*function\s+(\w+)/` |
| C++ | Complex - consider tree-sitter |
| C# | `/^(\s*)(?:public\|private)?\s*(?:static)?\s*\w+\s+(\w+)\s*\(/` |

## Checklist

Before submitting your adapter:

- [ ] Type definitions updated in `types.ts`
- [ ] Adapter class created with all required methods
- [ ] Import extraction handles all common patterns
- [ ] Export extraction respects visibility rules
- [ ] Function extraction counts parameters correctly
- [ ] Framework rules added for popular frameworks
- [ ] Comment detection updated for language syntax
- [ ] Test file created with comprehensive coverage
- [ ] Adapter registered in `AdapterFactory`
- [ ] All tests passing
- [ ] Code coverage >80% for new adapter
- [ ] Documentation updated (this guide if needed)

## Troubleshooting

### Tests Not Finding Adapter

Ensure you've exported the adapter class and it's registered in the factory.

### Regex Not Matching

1. Test regex patterns in isolation
2. Account for line endings (`\r\n` vs `\n`)
3. Use non-greedy quantifiers (`*?` instead of `*`)
4. Escape special characters properly

### Multi-line Constructs Not Detected

The basic regex approach works line-by-line. For complex multi-line patterns:
1. Join lines within parentheses/brackets
2. Consider tree-sitter for accurate AST parsing
3. Track state across lines (e.g., `inMultiLineImport` flag)

### Performance Issues

1. Compile regex patterns once (as class properties)
2. Use early returns for non-matching lines
3. Consider lazy initialization of tree-sitter

## Related Documentation

- [ADR-010: Codebase Analysis Scope](../adr/010-codebase-analysis-scope.md)
- [Multi-Language Analysis Architecture](../architecture/multi-language-analysis.md)
- [Tree-Sitter Setup Guide](./tree-sitter-setup.md)
- [Adapter Factory Guide](./adapter-factory.md)

## Example Adapters

Reference these existing adapters for patterns:

- **Python** (`python.ts`): Good example of import/export patterns
- **Go** (`go.ts`): Shows visibility-based exports
- **Rust** (`rust.ts`): Demonstrates module system handling
- **Java** (`java.ts`): Shows package and visibility modifiers
