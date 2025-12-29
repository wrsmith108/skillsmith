# ADR-005: VS Code Extension MCP Client Architecture

**Status**: Accepted
**Date**: 2025-12-28
**Deciders**: Skillsmith Team
**Issue**: SMI-709

## Context

The VS Code extension needs to communicate with the Skillsmith MCP server to provide skill discovery, installation, and management features. We needed to decide how to integrate MCP protocol support into the extension.

## Decision

Implement a dedicated MCP client module within the VS Code extension:

```
packages/vscode-extension/src/mcp/
├── McpClient.ts      # WebSocket-based MCP protocol client
├── McpStatusBar.ts   # Status bar indicator for connection state
├── types.ts          # TypeScript interfaces for MCP messages
└── index.ts          # Module exports
```

Key design decisions:
1. **WebSocket transport**: Uses `ws` package for bidirectional MCP communication
2. **Status bar integration**: Visual indicator shows connection state (connected/disconnected/error)
3. **Typed interfaces**: Full TypeScript coverage for MCP request/response types
4. **Auto-reconnect**: Handles connection drops with exponential backoff

## Consequences

### Positive
- Native MCP protocol support without external dependencies
- Real-time connection status visible to users
- Type-safe MCP tool invocations
- Supports all MCP tool types (search, get_skill, install, uninstall)

### Negative
- More code to maintain than using an external MCP SDK
- WebSocket management complexity

### Neutral
- Extension requires MCP server to be running for full functionality
- Graceful degradation when server unavailable

## Alternatives Considered

### Alternative 1: HTTP REST API
- Pros: Simpler transport, no persistent connection
- Cons: Not MCP-compliant, would require custom server changes
- Why rejected: MCP is the standard protocol for Claude integrations

### Alternative 2: External MCP SDK
- Pros: Less code to maintain
- Cons: Additional dependency, less control over behavior
- Why rejected: Available SDKs didn't meet our requirements

### Alternative 3: Subprocess Communication
- Pros: Simple IPC
- Cons: Complex lifecycle management, platform differences
- Why rejected: WebSocket is more robust and cross-platform

## References

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- `packages/vscode-extension/src/mcp/`
- SMI-709 implementation PR
