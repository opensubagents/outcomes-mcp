// HeuristicVerifier — deterministic, no LLM, no network.
// One-to-one port of opensubagents/outcomes/sdk-typescript/src/verifier.ts.
// See specification/appendix-a-rubric.md for the rubric this implements.

import {
  Confidence,
  SourceKind,
  SPEC_VERSION,
  type Citation,
  type DimensionScore,
  type OutcomeDeclaration,
  type Report,
  type Verdict,
} from "./types.js";

export const REFERENCE_VERIFIER_ID = "open-outcome.typescript.heuristic";

function allCitations(report: Report): Citation[] {
  const seen = new Map<string, Citation>();
  for (const claim of report.claims) {
    for (const c of claim.citations) {
      if (!seen.has(c.url)) seen.set(c.url, c);
    }
  }
  return Array.from(seen.values());
}

export function verify(outcome: OutcomeDeclaration, report: Report): Verdict {
  const dimensions: DimensionScore[] = [
    scoreConfidenceCalibration(report),
    scoreCitationQuality(report),
    scoreCoverage(outcome, report),
    scoreDecisionUsefulness(report),
    scoreClarity(report),
  ];
  const overall =
    Math.round(
      (dimensions.reduce((a, b) => a + b.score, 0) / dimensions.length) * 10,
    ) / 10;
  return {
    spec_version: SPEC_VERSION,
    dimensions,
    overall,
    evidence: allCitations(report),
    notes: "HeuristicVerifier (no LLM)",
    verifier_id: REFERENCE_VERIFIER_ID,
  };
}

function scoreConfidenceCalibration(report: Report): DimensionScore {
  const violations: string[] = [];
  for (const claim of report.claims) {
    const primary = claim.citations.filter((c) => c.kind === SourceKind.PRIMARY).length;
    const reputable = claim.citations.filter(
      (c) => c.kind === SourceKind.PRIMARY || c.kind === SourceKind.SECONDARY,
    ).length;
    if (claim.confidence === Confidence.HIGH && primary < 2) {
      violations.push(
        `high-confidence claim has ${primary} primary source(s): ${claim.statement.slice(0, 60)}...`,
      );
    } else if (
      claim.confidence === Confidence.MEDIUM &&
      primary < 1 &&
      reputable < 2
    ) {
      violations.push(
        `medium-confidence claim has weak sourcing: ${claim.statement.slice(0, 60)}...`,
      );
    } else if (claim.confidence === Confidence.LOW && primary >= 2) {
      violations.push(
        `low-confidence claim is well-sourced (under-calibrated): ${claim.statement.slice(0, 60)}...`,
      );
    }
  }
  const n = report.claims.length;
  const ratio = n ? (n - violations.length) / n : 0;
  const score = 1 + Math.round(ratio * 4);
  const justification =
    violations.length === 0
      ? "all claims calibrated"
      : `${violations.length}/${n} miscalibrated: ${violations.slice(0, 2).join("; ")}`;
  return { name: "confidence_calibration", score, justification };
}

function scoreCitationQuality(report: Report): DimensionScore {
  const cits = allCitations(report);
  if (cits.length === 0) {
    return { name: "citation_quality", score: 1, justification: "report has no citations" };
  }
  const counts: Record<SourceKind, number> = {
    [SourceKind.PRIMARY]: 0,
    [SourceKind.SECONDARY]: 0,
    [SourceKind.COMMUNITY]: 0,
  };
  for (const c of cits) counts[c.kind] += 1;
  const primaryShare = counts.primary / cits.length;
  if (primaryShare >= 0.5) {
    return {
      name: "citation_quality",
      score: 5,
      justification: `${counts.primary}/${cits.length} primary`,
    };
  }
  if (primaryShare >= 0.25) {
    return {
      name: "citation_quality",
      score: 4,
      justification: `${counts.primary}/${cits.length} primary`,
    };
  }
  if (counts.primary >= 1) {
    return {
      name: "citation_quality",
      score: 3,
      justification: "at least one primary, mostly secondary",
    };
  }
  if (counts.secondary >= 1) {
    return { name: "citation_quality", score: 2, justification: "secondary only" };
  }
  return { name: "citation_quality", score: 1, justification: "community-only sourcing" };
}

function scoreCoverage(outcome: OutcomeDeclaration, report: Report): DimensionScore {
  const required: string[] = [...outcome.success_criteria];
  const af = outcome.archetype_fields ?? {};
  const fromArchetype = (key: string): string[] => {
    const v = af[key];
    return Array.isArray(v) ? (v as unknown[]).map(String) : [];
  };
  if (outcome.archetype === "vendor_comparison") required.push(...fromArchetype("dimensions"));
  else if (outcome.archetype === "deep_dive") required.push(...fromArchetype("angles"));
  else if (outcome.archetype === "capability_audit")
    required.push(...fromArchetype("capabilities"));

  if (required.length === 0) {
    return {
      name: "coverage",
      score: 3,
      justification: "outcome specifies no explicit coverage requirements",
    };
  }
  const haystack = report.claims.map((c) => c.statement.toLowerCase()).join(" ");
  const hits = required.filter((r) =>
    r
      .toLowerCase()
      .split(/\s+/)
      .some((tok) => tok.length > 0 && haystack.includes(tok)),
  ).length;
  const ratio = hits / required.length;
  const score = 1 + Math.round(ratio * 4);
  return {
    name: "coverage",
    score,
    justification: `${hits}/${required.length} required axes mentioned`,
  };
}

function scoreDecisionUsefulness(report: Report): DimensionScore {
  let signals = 0;
  if ((report.open_questions ?? []).length > 0) signals += 1;
  if (report.claims.some((c) => c.caveats !== undefined && c.caveats !== "")) signals += 1;
  if (report.methodology_notes) signals += 1;
  const summary = report.summary.toLowerCase();
  if (["recommend", "choose", "prefer", "avoid", "tradeoff"].some((w) => summary.includes(w))) {
    signals += 1;
  }
  const score = Math.max(1, Math.min(5, 1 + signals));
  return {
    name: "decision_usefulness",
    score,
    justification: `${signals}/4 decision signals present`,
  };
}

function scoreClarity(report: Report): DimensionScore {
  const sentences = report.summary
    .replace(/!/g, ".")
    .split(".")
    .filter((s) => s.trim().length > 0);
  const n = sentences.length;
  if (n >= 2 && n <= 4) {
    return { name: "clarity", score: 5, justification: `summary is ${n} sentences` };
  }
  if (n === 1 || n === 5) {
    return {
      name: "clarity",
      score: 3,
      justification: `summary is ${n} sentence(s) — outside 2-4 ideal`,
    };
  }
  return { name: "clarity", score: 2, justification: `summary is ${n} sentences` };
}
