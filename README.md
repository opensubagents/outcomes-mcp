# outcomes-mcp

> Codemode-style MCP server for the [Open Outcome](https://github.com/opensubagents/outcomes) rubric.

Exposes the deterministic `HeuristicVerifier` from [`opensubagents/outcomes`](https://github.com/opensubagents/outcomes) as a single MCP `code` tool: write JavaScript against a typed verifier surface, run it in an isolated Cloudflare Worker Loader sandbox, get back a `Verdict`.

This follows the pattern Cloudflare uses for [`mcp.cloudflare.com`](https://developers.cloudflare.com/agents/) — two-tools (or one-tool, when small enough) wrapping a typed API surface via [`@cloudflare/codemode`](https://github.com/cloudflare/agents/tree/main/packages/codemode). One tool description in the model's context, arbitrary composition in the sandbox.

## Quickstart

```bash
npm install
npx wrangler dev
```

Probe with the [MCP Inspector](https://github.com/modelcontextprotocol/inspector):

```bash
npx @modelcontextprotocol/inspector@latest http://localhost:8787/mcp
```

Or call it raw:

```bash
curl -sS -X POST http://localhost:8787/mcp \
  -H 'content-type: application/json' \
  -H 'accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

You'll see a single `code` tool whose description carries the typed surface:

```ts
declare const codemode: {
  verify_outcome_pair: (input: { outcome: OutcomeDeclaration, report: Report })
    => Promise<Verdict>;
  spec_info: (input: {}) => Promise<{spec_version, verifier_id, dimensions, ...}>;
};
```

## What the `code` tool runs

Each call:

1. Builds a fresh `McpServer` (the inner server with native tools).
2. Wraps it via `codeMcpServer({server, executor})` from `@cloudflare/codemode/mcp` — auto-generates the typed surface above.
3. Runs the model's JS snippet in a `DynamicWorkerExecutor` (Worker Loader sandbox, `globalOutbound: null` so the sandbox cannot reach the network).
4. Dispatches `codemode.verify_outcome_pair(...)` etc. back to the host via Workers RPC.
5. Returns the snippet's return value as the tool result.

## Connecting from Claude Code

```bash
claude mcp add outcomes-mcp http://localhost:8787/mcp
```

Then ask Claude to score an outcome+report pair — Claude calls the `code` tool with composed JS, the verifier runs deterministically, the verdict comes back.

## Why this is here

- **Spec**: [`opensubagents/outcomes`](https://github.com/opensubagents/outcomes) — the Open Outcome v0.1.0 spec, JSON Schemas, and reference SDKs.
- **CI gate**: every PR to `opensubagents/outcomes` is scored by `HeuristicVerifier` and blocked when `verdict.overall < 3.5`.
- **This repo**: the same `HeuristicVerifier`, callable as an MCP tool while authoring, so an agent can declare → verify → grade *during* a session and not just at PR time.

## Files

| Path | Role |
| --- | --- |
| `src/index.ts` | Worker entry. Builds inner MCP server, wraps with Codemode, serves over streamable HTTP. |
| `src/types.ts` | TS types vendored from `opensubagents/outcomes/sdk-typescript`. |
| `src/verifier.ts` | Pure TS port of `HeuristicVerifier` (no zod runtime dep, no LLM, no network). |
| `wrangler.jsonc` | `worker_loaders: [{binding: "LOADER"}]`, `nodejs_compat`. |
| `outcomes/` | Self-evidencing outcome+report pairs scored by the upstream CI gate (bootstrap + orchestrator-bootstrap + the split PR pair). |

## Conformance

The vendored verifier is byte-equivalent to the upstream [`@opensubagents/outcomes-sdk`](https://www.npmjs.com/package/@opensubagents/outcomes-sdk) `HeuristicVerifier` for the algorithm; the zod runtime schemas are intentionally omitted here (validation is moved to the MCP tool boundary via zod 4). Once the SDK is published to npm (see [`opensubagents/outcomes-sdk-typescript`](https://github.com/opensubagents/outcomes-sdk-typescript)), `src/types.ts` and `src/verifier.ts` will be replaced by the npm import.

## Split note

This repo is the **public MCP server surface only**. The private operational substrate that runs the `/loop` heartbeat, the 31-outcome QUEUE.md, the rotation aliases, the eval matrix, and the per-tick `outcome.json + report.json` pairs lives in the private repo `subagentceo/outcomes-orchestrator`. Prior to 2026-05-22 those artifacts lived here; the split is documented in the orchestrator's `TOPOLOGY.md`.

## License

Apache-2.0.
