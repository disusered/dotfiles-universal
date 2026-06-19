#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = resolve(SCRIPT_DIR, "..");
const DEFAULT_SCOPE_MAP = resolve(PLUGIN_ROOT, "scope-map.json");

function loadJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function normalizePath(path) {
  return resolve(path).replace(/\/+$/, "");
}

function isSameOrChild(cwd, parent) {
  const normalizedCwd = normalizePath(cwd);
  const normalizedParent = normalizePath(parent);
  return normalizedCwd === normalizedParent || normalizedCwd.startsWith(`${normalizedParent}/`);
}

function identity(scope) {
  return {
    account: scope.account,
    user: scope.user,
    agentId: scope.agentId,
  };
}

function resourceUris(scope) {
  return (Array.isArray(scope.resourceUris) ? scope.resourceUris : [])
    .filter((uri) => typeof uri === "string" && uri.trim())
    .map((uri) => uri.trim().replace(/\/+$/, ""));
}

function scopeKey(scope) {
  return `${scope.account}\0${scope.user}\0${scope.agentId}`;
}

function uniqueScopes(scopes) {
  const seen = new Set();
  const result = [];
  for (const scope of scopes) {
    const key = scopeKey(scope);
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(scope);
  }
  return result;
}

function useGeneralFallback(map, active) {
  if (typeof active.generalFallback === "boolean") return active.generalFallback;
  return map.generalFallback !== false;
}

export function resolveScopeConfig(options = {}) {
  const mapPath = options.mapPath || process.env.OPENVIKING_SCOPE_MAP_FILE || DEFAULT_SCOPE_MAP;
  const map = loadJson(mapPath);
  const cwd = options.cwd || process.env.OPENVIKING_CWD || process.cwd();
  const explicitScope = options.scope || process.env.OPENVIKING_MEMORY_SCOPE || "";
  const defaultScope = map.defaultScope;
  const scopes = Array.isArray(map.scopes) ? map.scopes : [];

  let active = defaultScope;
  if (explicitScope) {
    active = scopes.find((scope) => scope.name === explicitScope) || defaultScope;
  } else {
    active = scopes.find((scope) => {
      const paths = Array.isArray(scope.paths) ? scope.paths : [];
      return paths.some((path) => isSameOrChild(cwd, path));
    }) || defaultScope;
  }

  const lookupScopes = uniqueScopes(
    useGeneralFallback(map, active) ? [active, defaultScope] : [active],
  ).map(identity);

  return {
    cwd,
    activeScope: active.name || "general",
    lookupScopes,
    writeScope: identity(active),
    resourceUris: resourceUris(active),
  };
}

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--cwd") {
      args.cwd = argv[++i];
    } else if (arg === "--scope") {
      args.scope = argv[++i];
    } else if (arg === "--map") {
      args.mapPath = argv[++i];
    } else if (arg === "--json") {
      args.json = true;
    }
  }
  return args;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const args = parseArgs(process.argv);
  const config = resolveScopeConfig(args);
  process.stdout.write(JSON.stringify(config, null, args.json ? 2 : 0) + "\n");
}
