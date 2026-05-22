// Open Outcome MCP server — Codemode-style.
//
// Native MCP tools live on an inner McpServer. @cloudflare/codemode wraps
// the inner server with a single `code` tool that exposes those native
// tools as typed methods inside an isolated Cloudflare Worker sandbox
// (via Worker Loader). The agent writes one JS snippet that composes
// many calls; the sandbox runs the snippet; we return the result.
//
// Pattern source: cloudflare/agents @ packages/codemode and
// developers.cloudflare.com/agents/mcp (Cloudflare API MCP @ mcp.cloudflare.com).

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { DynamicWorkerExecutor } from "@cloudflare/codemode";
import { codeMcpServer } from "@cloudflare/codemode/mcp";
import { createMcpHandler } from "agents/mcp";
import { z } from "zod";

import { verify, REFERENCE_VERIFIER_ID } from "./verifier.js";
import type { OutcomeDeclaration, Report, Verdict } from "./types.js";

interface Env {
  LOADER: WorkerLoader;
}

const CitationInputSchema = z.object({
  url: z.string().url(),
  title: z.string().min(1),
  accessed: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  kind: z.enum(["primary", "secondary", "community"]),
  quote: z.string().optional(),
});

const ClaimInputSchema = z.object({
  statement: z.string().min(1),
  confidence: z.enum(["high", "medium", "low"]),
  citations: z.array(CitationInputSchema),
  caveats: z.string().optional(),
});

const OutcomeInputSchema = z.object({
  title: z.string().min(1),
  as_of: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  question: z.string().min(1),
  success_criteria: z.array(z.string().min(1)).min(1),
  archetype: z.string().min(1).optional(),
  archetype_fields: z.record(z.string(), z.unknown()).optional(),
  requester: z.string().optional(),
});

const ReportInputSchema = z.object({
  summary: z.string().min(1),
  claims: z.array(ClaimInputSchema).min(1),
  open_questions: z.array(z.string()).optional(),
  methodology_notes: z.string().optional(),
});

function buildInnerServer(): McpServer {
  const server = new McpServer({
    name: "open-outcome",
    version: "0.1.0",
  });

  server.registerTool(
    "verify_outcome_pair",
    {
      title: "Score an outcome+report pair",
      description:
        "Runs the deterministic HeuristicVerifier (no LLM, no network) on a " +
        "(OutcomeDeclaration, Report) pair. Returns a Verdict with five " +
        "dimension scores (1–5 integers) and an overall mean (1 decimal). " +
        "See https://github.com/opensubagents/outcomes/blob/main/specification/appendix-a-rubric.md",
      inputSchema: {
        outcome: OutcomeInputSchema,
        report: ReportInputSchema,
      },
    },
    async ({ outcome, report }) => {
      const verdict = verify(outcome as OutcomeDeclaration, report as Report);
      return {
        content: [{ type: "text", text: JSON.stringify(verdict) }],
        structuredContent: verdict as unknown as Record<string, unknown>,
      };
    },
  );

  server.registerTool(
    "spec_info",
    {
      title: "Open Outcome spec info",
      description:
        "Returns the spec version, verifier id, the five rubric dimensions, " +
        "and the canonical floor used by opensubagents/outcomes CI.",
      inputSchema: {},
    },
    async () => {
      const info = {
        spec_version: "0.1.0",
        verifier_id: REFERENCE_VERIFIER_ID,
        dimensions: [
          "confidence_calibration",
          "citation_quality",
          "coverage",
          "decision_usefulness",
          "clarity",
        ],
        canonical_floor: 3.5,
        spec_url:
          "https://github.com/opensubagents/outcomes/blob/main/specification/README.md",
      };
      return {
        content: [{ type: "text", text: JSON.stringify(info) }],
        structuredContent: info,
      };
    },
  );

  return server;
}

// Stateless: build fresh McpServer + handler PER REQUEST.
// The MCP spec stateless transport attaches each request to a transport, and
// an McpServer cannot reattach. Caching causes "Server is already connected".
async function buildHandler(env: Env) {
  const inner = buildInnerServer();
  const executor = new DynamicWorkerExecutor({
    loader: env.LOADER,
    timeout: 10_000,
    globalOutbound: null,
  });
  const wrapped = await codeMcpServer({
    server: inner,
    executor,
    description:
      "Open Outcome verifier — write JavaScript that composes the typed " +
      "methods below, then return a Verdict.\n\n" +
      "Types:\n```ts\n{{types}}\n```\n\n" +
      "Example:\n```ts\n{{example}}\n```",
  });
  return createMcpHandler(wrapped, { route: "/mcp" });
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === "/healthz") {
      return new Response("ok", { headers: { "content-type": "text/plain" } });
    }
    if (url.pathname === "/" && req.method === "GET") {
      return new Response(
        "Open Outcome MCP server — POST /mcp (streamable HTTP). See https://github.com/opensubagents/outcomes-mcp",
        { headers: { "content-type": "text/plain" } },
      );
    }
    const handler = await buildHandler(env);
    return handler(req, env, ctx);
  },
};
