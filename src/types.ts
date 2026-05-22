// Open Outcome types — vendored from opensubagents/outcomes/sdk-typescript.
// Plain TypeScript, no zod runtime dependency. Validation is performed by
// the verifier itself for the few invariants it cares about; structural
// validation happens at the MCP tool boundary via zod (separately).

export const Confidence = {
  HIGH: "high",
  MEDIUM: "medium",
  LOW: "low",
} as const;
export type Confidence = (typeof Confidence)[keyof typeof Confidence];

export const SourceKind = {
  PRIMARY: "primary",
  SECONDARY: "secondary",
  COMMUNITY: "community",
} as const;
export type SourceKind = (typeof SourceKind)[keyof typeof SourceKind];

export interface Citation {
  url: string;
  title: string;
  accessed: string;
  kind: SourceKind;
  quote?: string;
}

export interface Claim {
  statement: string;
  confidence: Confidence;
  citations: Citation[];
  caveats?: string;
}

export interface OutcomeDeclaration {
  title: string;
  as_of: string;
  question: string;
  success_criteria: string[];
  archetype?: string;
  archetype_fields?: Record<string, unknown>;
  requester?: string;
}

export interface Report {
  summary: string;
  claims: Claim[];
  open_questions?: string[];
  methodology_notes?: string;
}

export interface DimensionScore {
  name: string;
  score: number;
  justification: string;
}

export interface Verdict {
  spec_version: string;
  dimensions: DimensionScore[];
  overall: number;
  evidence: Citation[];
  notes?: string;
  verifier_id?: string;
}

export const SPEC_VERSION = "0.1.0";
