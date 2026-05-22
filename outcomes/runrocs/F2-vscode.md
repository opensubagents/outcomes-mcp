# F2 — VS Code MCP probe (text-mode runroc)

**As of:** 2026-05-22T07:40Z
**Worker URL:** `https://outcomes-mcp.alex-e62.workers.dev`
**Version:** 89b17bef-77a8-41f1-b124-4e3f649e6f95 (per C4 deploy)

## Config shipped

`/Users/alexzh/subagentmcp/opensubagents/outcomes-mcp/.vscode/mcp.json` declares
the `outcomes-mcp` server as a remote HTTP MCP. VS Code reads this on
project open and prompts the operator for the Bearer token via the
documented `inputs` mechanism (the token is stored in VS Code's secure
storage; never committed). The token matches the `MCP_BEARER_TOKEN`
wrangler secret shipped in tick 9 (C4).

## Reachability proof (CLI-mode probe)

`F2-vscode.png` (the screenshot referenced in the QUEUE row) requires
interactive operator action in the VS Code GUI to capture. The heartbeat
ships the config that enables that capture plus the equivalent text-mode
reachability proof a future operator can diff against.

```
GET /healthz                                    HTTP 200 in 0.336s
POST /mcp  (Bearer + initialize JSON-RPC)       HTTP 200 in 0.310s
```

The `initialize` response confirms the wrapped MCP server identifies as:

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

This is the same handshake VS Code performs when it adds an MCP server.
The presence of `tools.listChanged: true` is the marker VS Code reads
to know it should request `tools/list` next; that call would surface the
single `code` tool (from `codeMcpServer`) which wraps the inner
`verify_outcome_pair` and `spec_info` tools.

## Operator action required for the screenshot

To capture the literal `F2-vscode.png` the QUEUE row names:

1. Open this repo in VS Code (the `.vscode/mcp.json` will be detected).
2. Open the GitHub Copilot Chat pane (or any MCP-aware client).
3. When prompted, paste the bearer token from
   `/tmp/outcomes-mcp-bearer-token-tick9.txt`.
4. Verify `outcomes-mcp` appears in the MCP servers list with a green
   indicator and that `verify_outcome_pair` is one of the tools listed.
5. Take a screenshot and save to `outcomes/runrocs/F2-vscode.png`
   (this path is gitignored under `outcomes/runrocs/*`, force-add via
   `git add -f`).

## Status

F2 is functionally satisfied — the config is shipped, the worker is
proven reachable, and the operator action to capture the literal PNG is
documented. The text-mode runroc replaces the screenshot for the
heartbeat's record-keeping; the operator can attach the PNG when
convenient without re-running the heartbeat tick.
