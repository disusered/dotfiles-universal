#!/usr/bin/env node

/**
 * Auto-Recall Hook Script for Codex.
 *
 * Triggered by UserPromptSubmit hook.
 * Reads `prompt` from stdin → searches OpenViking → returns recalled memories
 * via `hookSpecificOutput.additionalContext` so Codex injects them into the turn.
 *
 * Codex output schema (codex-rs/hooks/schema/generated/user-prompt-submit.command.output.schema.json):
 *   { hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: "<text>" } }
 * — `decision: "approve"` is NOT a codex thing; only `decision: "block"` is. So a no-op
 * is just `{}`.
 */

import { loadConfig } from "./config.mjs";
import { createLogger } from "./debug-log.mjs";
import { resolveScopeConfig } from "./scope-config.mjs";

const cfg = loadConfig();
const { log, logError } = createLogger("auto-recall");
let activeFetchScope = {
  account: cfg.account,
  user: cfg.user,
  agentId: cfg.agentId,
};

function output(obj) {
  process.stdout.write(JSON.stringify(obj) + "\n");
}

function emit(additionalContext) {
  if (!additionalContext) {
    output({});
    return;
  }
  output({
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext,
    },
  });
}

function scopeHeaders(scope = activeFetchScope) {
  const headers = {};
  const account = scope?.account || cfg.account;
  const user = scope?.user || cfg.user;
  const agentId = scope?.agentId || cfg.agentId;
  if (account) headers["X-OpenViking-Account"] = account;
  if (user) headers["X-OpenViking-User"] = user;
  if (agentId) headers["X-OpenViking-Agent"] = agentId;
  return headers;
}

function scopeLabel(scope = {}) {
  return scope.agentId || scope.account || "default";
}

function scopeKey(scope = {}) {
  return `${scope.account || ""}\0${scope.user || ""}\0${scope.agentId || ""}`;
}

function withScope(item, scope, kind) {
  return {
    ...item,
    _openvikingScope: scope,
    _openvikingScopeLabel: scopeLabel(scope),
    _openvikingKind: kind,
  };
}

async function fetchJSON(path, init = {}, scope = activeFetchScope) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), cfg.timeoutMs);
  try {
    const headers = { "Content-Type": "application/json", ...scopeHeaders(scope) };
    if (cfg.apiKey) {
      headers["Authorization"] = `Bearer ${cfg.apiKey}`;
      headers["X-API-Key"] = cfg.apiKey;
    }
    const res = await fetch(`${cfg.baseUrl}${path}`, { ...init, headers, signal: controller.signal });
    const body = await res.json().catch(() => null);
    if (!body) return null;
    if (!res.ok || body.status === "error") return null;
    return body.result ?? body;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// Ranking
// ---------------------------------------------------------------------------

function clampScore(v) {
  if (typeof v !== "number" || Number.isNaN(v)) return 0;
  return Math.max(0, Math.min(1, v));
}

const PREFERENCE_QUERY_RE = /prefer|preference|favorite|favourite|like|偏好|喜欢|爱好|更倾向/i;
const TEMPORAL_QUERY_RE = /when|what time|date|day|month|year|yesterday|today|tomorrow|last|next|什么时候|何时|哪天|几月|几年|昨天|今天|明天/i;
const QUERY_TOKEN_RE = /[a-z0-9一-龥]{2,}/gi;
const STOPWORDS = new Set([
  "what", "when", "where", "which", "who", "whom", "whose", "why", "how", "did", "does",
  "is", "are", "was", "were", "the", "and", "for", "with", "from", "that", "this", "your", "you",
]);

function buildQueryProfile(query) {
  const text = query.trim();
  const allTokens = text.toLowerCase().match(QUERY_TOKEN_RE) || [];
  const tokens = allTokens.filter((t) => !STOPWORDS.has(t));
  return {
    tokens,
    wantsPreference: PREFERENCE_QUERY_RE.test(text),
    wantsTemporal: TEMPORAL_QUERY_RE.test(text),
  };
}

function lexicalOverlapBoost(tokens, text) {
  if (tokens.length === 0 || !text) return 0;
  const haystack = ` ${text.toLowerCase()} `;
  let matched = 0;
  for (const token of tokens.slice(0, 8)) {
    if (haystack.includes(token)) matched += 1;
  }
  return Math.min(0.2, (matched / Math.min(tokens.length, 4)) * 0.2);
}

function getRankingBreakdown(item, profile) {
  const base = clampScore(item.score);
  const abstract = (item.abstract || item.overview || "").trim();
  const cat = (item.category || "").toLowerCase();
  const uri = item.uri.toLowerCase();
  const leafBoost = (item.level === 2 || uri.endsWith(".md")) ? 0.12 : 0;
  const eventBoost = profile.wantsTemporal && (cat === "events" || uri.includes("/events/")) ? 0.1 : 0;
  const prefBoost = profile.wantsPreference && (cat === "preferences" || uri.includes("/preferences/")) ? 0.08 : 0;
  const overlapBoost = lexicalOverlapBoost(profile.tokens, `${item.uri} ${abstract}`);
  return {
    baseScore: base,
    leafBoost,
    eventBoost,
    prefBoost,
    overlapBoost,
    finalScore: base + leafBoost + eventBoost + prefBoost + overlapBoost,
  };
}

function rankForInjection(item, profile) {
  return getRankingBreakdown(item, profile).finalScore;
}

function dedupeByAbstract(items) {
  const seen = new Set();
  return items.filter((item) => {
    const key = (item.abstract || item.overview || "").trim().toLowerCase() || item.uri;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function pickMemories(items, limit, queryText) {
  if (items.length === 0 || limit <= 0) return [];
  const profile = buildQueryProfile(queryText);
  const sorted = [...items].sort((a, b) => rankForInjection(b, profile) - rankForInjection(a, profile));
  const deduped = dedupeByAbstract(sorted);
  const leaves = deduped.filter((m) => m.level === 2 || m.uri.endsWith(".md"));
  if (leaves.length >= limit) return leaves.slice(0, limit);
  const picked = [...leaves];
  const used = new Set(picked.map((m) => m.uri));
  for (const item of deduped) {
    if (picked.length >= limit) break;
    if (used.has(item.uri)) continue;
    picked.push(item);
  }
  return picked;
}

function postProcess(items, limit, threshold) {
  const seen = new Set();
  const sorted = [...items].sort((a, b) => clampScore(b.score) - clampScore(a.score));
  const result = [];
  for (const item of sorted) {
    if (item.level !== 2) continue;
    if (clampScore(item.score) < threshold) continue;
    const cat = (item.category || "").toLowerCase() || "unknown";
    const abs = (item.abstract || item.overview || "").trim().toLowerCase();
    const key = abs ? `${cat}:${abs}` : `uri:${item.uri}`;
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(item);
    if (result.length >= limit) break;
  }
  return result;
}

// ---------------------------------------------------------------------------
// User URI space resolution
// ---------------------------------------------------------------------------

const USER_RESERVED_DIRS = new Set(["memories", "skills"]);
const _userSpaceCache = new Map();

async function resolveUserSpace(scope) {
  const cacheKey = scopeKey(scope);
  if (_userSpaceCache.has(cacheKey)) return _userSpaceCache.get(cacheKey);

  let fallbackSpace = "default";
  try {
    const status = await fetchJSON("/api/v1/system/status", {}, scope);
    if (status && typeof status.user === "string" && status.user.trim()) {
      fallbackSpace = status.user.trim();
    }
  } catch { /* fallback */ }

  try {
    const entries = await fetchJSON(`/api/v1/fs/ls?uri=${encodeURIComponent("viking://user")}&output=original`, {}, scope);
    if (Array.isArray(entries)) {
      const spaces = entries
        .filter((e) => e?.isDir)
        .map((e) => (typeof e.name === "string" ? e.name.trim() : ""))
        .filter((n) => n && !n.startsWith(".") && !USER_RESERVED_DIRS.has(n));
      if (spaces.length > 0) {
        if (spaces.includes(fallbackSpace)) { _userSpaceCache.set(cacheKey, fallbackSpace); return fallbackSpace; }
        if (spaces.includes("default")) { _userSpaceCache.set(cacheKey, "default"); return "default"; }
        if (spaces.length === 1) { _userSpaceCache.set(cacheKey, spaces[0]); return spaces[0]; }
      }
    }
  } catch { /* fallback */ }

  _userSpaceCache.set(cacheKey, fallbackSpace);
  return fallbackSpace;
}

async function resolveTargetUri(targetUri, scope) {
  const trimmed = targetUri.trim().replace(/\/+$/, "");
  const m = trimmed.match(/^viking:\/\/user(?:\/(.*))?$/);
  if (!m) return trimmed;
  const rawRest = (m[1] ?? "").trim();
  if (!rawRest) return trimmed;
  const parts = rawRest.split("/").filter(Boolean);
  if (parts.length === 0) return trimmed;
  if (!USER_RESERVED_DIRS.has(parts[0])) return trimmed;
  const space = await resolveUserSpace(scope);
  return `viking://user/${space}/${parts.join("/")}`;
}

async function searchScope(query, targetUri, limit, bucket = "memories", scope = activeFetchScope) {
  const resolvedUri = await resolveTargetUri(targetUri, scope);
  const body = { query, target_uri: resolvedUri, limit, score_threshold: 0 };
  if (cfg.peerId) body.peer_id = cfg.peerId;
  const result = await fetchJSON("/api/v1/search/find", {
    method: "POST",
    body: JSON.stringify(body),
  }, scope);
  return (result?.[bucket] || []).map((item) => withScope(item, scope, bucket));
}

async function searchAll(query, limit, scopes, resourceUris = [], resourceScope = null) {
  const batches = await Promise.all(scopes.flatMap((scope) => {
    const targets = [
      searchScope(query, "viking://user/memories", limit, "memories", scope),
      searchScope(query, "viking://user/skills", limit, "skills", scope),
    ];
    if (scope.agentId) {
      targets.push(searchScope(query, `viking://agent/${scope.agentId}/memories`, limit, "memories", scope));
    }
    return targets;
  }).concat(resourceUris.map((uri) => searchScope(query, uri, limit, "resources", resourceScope || scopes[0]))));
  const all = batches.flat();
  for (const scope of scopes) {
    const label = scopeLabel(scope);
    const scoped = all.filter((item) => scopeKey(item._openvikingScope) === scopeKey(scope));
    log("search_complete", {
      scope: label,
      rawCount: scoped.length,
      topScores: scoped.slice(0, 3).map((m) => m.score),
    });
  }
  if (resourceUris.length > 0) {
    log("resource_search_complete", {
      targetUris: resourceUris,
      rawCount: all.filter((item) => item._openvikingKind === "resources").length,
    });
  }
  const seen = new Set();
  return all.filter((m) => {
    const key = `${scopeKey(m._openvikingScope)}\0${m.uri}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

async function readMemoryContent(uri, scope = activeFetchScope) {
  try {
    const result = await fetchJSON(`/api/v1/content/read?uri=${encodeURIComponent(uri)}`, {}, scope);
    if (result && typeof result === "string" && result.trim()) return result.trim();
  } catch { /* fallback */ }
  return null;
}

async function main() {
  if (!cfg.autoRecall) {
    log("skip", { stage: "init", reason: "autoRecall disabled" });
    emit();
    return;
  }

  let input;
  try {
    const chunks = [];
    for await (const chunk of process.stdin) chunks.push(chunk);
    input = JSON.parse(Buffer.concat(chunks).toString());
  } catch {
    log("skip", { stage: "stdin_parse", reason: "invalid input" });
    emit();
    return;
  }

  const scopeConfig = resolveScopeConfig({ cwd: input.cwd || process.cwd() });
  activeFetchScope = scopeConfig.writeScope;

  const userPrompt = (input.prompt || "").trim();
  log("start", {
    query: userPrompt.slice(0, 200),
    queryLength: userPrompt.length,
    scope: scopeConfig.activeScope,
    lookupScopes: scopeConfig.lookupScopes.map(scopeLabel),
    config: { recallLimit: cfg.recallLimit, scoreThreshold: cfg.scoreThreshold },
  });

  if (!userPrompt || userPrompt.length < cfg.minQueryLength) {
    log("skip", { stage: "query_check", reason: "query too short or empty" });
    emit();
    return;
  }

  const health = await fetchJSON("/health", {}, scopeConfig.writeScope);
  if (!health) {
    logError("health_check", "server unreachable or unhealthy");
    emit();
    return;
  }

  const candidateLimit = Math.max(cfg.recallLimit * 4, 20);
  const allMemories = await searchAll(
    userPrompt,
    candidateLimit,
    scopeConfig.lookupScopes,
    scopeConfig.resourceUris,
    scopeConfig.writeScope,
  );
  if (allMemories.length === 0) {
    log("skip", { stage: "search", reason: "no results" });
    emit();
    return;
  }

  const processed = postProcess(allMemories, candidateLimit, cfg.scoreThreshold);
  log("post_process", { beforeCount: allMemories.length, afterCount: processed.length });

  const profile = buildQueryProfile(userPrompt);
  const ranked = [...processed]
    .map((item) => ({ item, breakdown: getRankingBreakdown(item, profile) }))
    .sort((a, b) => b.breakdown.finalScore - a.breakdown.finalScore);

  if (cfg.logRankingDetails) {
    for (const entry of ranked) {
      log("ranking_detail", { uri: entry.item.uri, ...entry.breakdown });
    }
  } else {
    log("ranking_summary", {
      candidateCount: processed.length,
      topCandidates: ranked.slice(0, 5).map((entry) => ({ uri: entry.item.uri, finalScore: entry.breakdown.finalScore })),
    });
  }

  const memories = pickMemories(processed, cfg.recallLimit, userPrompt);
  if (memories.length === 0) {
    log("skip", { stage: "pick", reason: "no memories survived ranking" });
    emit();
    return;
  }

  log("picked", { pickedCount: memories.length, uris: memories.map((m) => m.uri) });

  const lines = await Promise.all(
    memories.map(async (item) => {
      const label = `${item._openvikingScopeLabel || "default"}:${item.category || item._openvikingKind || "memory"}`;
      if (item.level === 2) {
        const content = await readMemoryContent(item.uri, item._openvikingScope);
        if (content) return `- [${label}] ${content}`;
      }
      return `- [${label}] ${(item.abstract || item.overview || item.uri).trim()}`;
    }),
  );

  const memoryContext =
    "<relevant-memories>\n" +
    "The following long-term memories from OpenViking may be relevant to this conversation:\n" +
    lines.join("\n") + "\n" +
    "</relevant-memories>";

  emit(memoryContext);
}

main().catch((err) => { logError("uncaught", err); emit(); });
