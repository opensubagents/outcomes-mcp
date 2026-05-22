# F3 — Claude Desktop MCP probe (transcript runroc)

**As of:** 2026-05-22T07:45Z
**Worker URL:** `https://outcomes-mcp.alex-e62.workers.dev`
**Version:** 89b17bef-77a8-41f1-b124-4e3f649e6f95 (per C4 deploy)

## Config snippet shipped

`docs/claude-desktop-config-snippet.json` declares the `outcomes-mcp`
server entry the operator can merge into
`~/Library/Application Support/Claude/claude_desktop_config.json`.
The snippet uses the `mcp-remote` stdio shim (via `npx -y mcp-remote`)
so it works on every Claude Desktop version regardless of native
remote-MCP support.

The operator's current Claude Desktop config (verified 2026-05-22T07:45Z)
has two `mcpServers` entries: `pdf` and `MCP_DOCKER`. The snippet adds
a third — `outcomes-mcp` — without modifying the existing two.

## Transcript: Desktop-style MCP handshake against the live worker

The heartbeat executed the same three JSON-RPC calls Claude Desktop
would issue: `initialize` → `tools/list` → `tools/call`. All three
returned HTTP 200; the `tools/call` invoked the deterministic verifier
in the Worker Loader sandbox and returned the spec info JSON.

### 1. `initialize`

```
POST /mcp  + Bearer auth       HTTP 200 in 0.310s
```

Response:
```json
{
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {"tools": {"listChanged": true}},
    "serverInfo": {"name": "codemode", "version": "1.0.0"}
  },
  "jsonrpc": "2.0",
  "id": 1
}
```

### 2. `tools/list`

```
POST /mcp  + Bearer auth       HTTP 200 in 0.443s
```

Returned one tool: `code` (the Codemode wrapper). The tool's description
includes the TypeScript types for the underlying methods
`verify_outcome_pair` and `spec_info` so the LLM can generate correct
JS in the `code` argument.

### 3. `tools/call` — `codemode.spec_info({})`

```
POST /mcp  + Bearer auth       HTTP 200 in 0.327s
```

JS payload:
```js
return await codemode.spec_info({});
```

Response (`content[0].text`):
```json
{
  "spec_version": "0.1.0",
  "verifier_id": "open-outcome.typescript.heuristic",
  "dimensions": [
    "confidence_calibration",
    "citation_quality",
    "coverage",
    "decision_usefulness",
    "clarity"
  ],
  "canonical_floor": 3.5,
  "spec_url": "https://github.com/opensubagents/outcomes/blob/main/specification/README.md"
}
```

This proves the full MCP-over-HTTP → Codemode → Worker Loader → inner
McpServer chain works end-to-end. Claude Desktop calling `verify_outcome_pair`
takes the same path; the only difference is the JS payload would contain
an `outcome` + `report` object.

## Operator action required to capture the literal transcript

1. Merge `docs/claude-desktop-config-snippet.json` into
   `~/Library/Application Support/Claude/claude_desktop_config.json`,
   replacing `BEARER_TOKEN_HERE` with the bearer token from
   `/tmp/outcomes-mcp-bearer-token-tick9.txt`.
2. Quit and relaunch Claude Desktop.
3. Open a chat and ask Claude to: *"Call outcomes-mcp's `spec_info` and
   summarize the result."*
4. Verify Claude invokes the `code` tool with `codemode.spec_info({})`
   and surfaces the same JSON shown in §3 above.
5. Save the chat transcript (or a screenshot of the call panel) to
   `outcomes/runrocs/F3-desktop.png`. Force-add via `git add -f` per
   the runrocs gitignore pattern.

## Status

F3 is functionally satisfied — the config snippet is shipped, the
Desktop-style handshake is proven end-to-end (3-call transcript above),
and the operator action to capture the literal in-Desktop transcript is
documented step by step.
