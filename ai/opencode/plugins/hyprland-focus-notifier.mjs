import { execSync, spawn } from "node:child_process";
import { readFileSync } from "node:fs";
import { basename } from "node:path";

const TERMINAL_REGEX =
  /kitty|foot|footclient|ghostty|wezterm|alacritty|terminator|tilix|konsole|gnome-terminal|xterm|warp|tmux/i;
const DEBUG = process.env.OPENCODE_HYPRLAND_NOTIFIER_DEBUG === "1";
const DEFAULT_TIMEOUT_SEC = 5;
const PINNED_ADDR = process.env.OPENCODE_HYPRLAND_WINDOW_ADDR?.trim() || null;

const MESSAGES = {
  permission: "Permission requested",
  complete: "Session finished",
  error: "Session errored",
  question: "Question waiting for input",
  plan_exit: "Plan ready for review",
};

function log(...args) {
  if (!DEBUG) return;
  try {
    process.stderr.write(`[hyprland-focus-notifier] ${args.join(" ")}\n`);
  } catch {}
}

function readProcStat(pid) {
  try {
    return readFileSync(`/proc/${pid}/stat`, "utf-8");
  } catch {
    return null;
  }
}

function readProcComm(pid) {
  try {
    return readFileSync(`/proc/${pid}/comm`, "utf-8").trim();
  } catch {
    return "";
  }
}

function findTerminalPid() {
  let pid = process.pid;
  let guard = 0;
  while (pid && pid > 1 && guard++ < 32) {
    const stat = readProcStat(pid);
    if (!stat) break;
    const m = stat.match(/^\d+\s+\([^)]+\)\s+\S\s+(\d+)/);
    if (!m) break;
    const ppid = parseInt(m[1], 10);
    if (!Number.isFinite(ppid) || ppid <= 1) break;
    const comm = readProcComm(ppid);
    if (comm && TERMINAL_REGEX.test(comm)) {
      if (comm === "tmux") {
        const inner = findTerminalPidFromTmux();
        if (inner) return inner;
      }
      return ppid;
    }
    pid = ppid;
  }
  return null;
}

function findTerminalPidFromTmux() {
  try {
    const pane = execSync("tmux display-message -p -F '#{pane_pid}'", {
      timeout: 500,
    })
      .toString()
      .trim();
    const pid = parseInt(pane, 10);
    if (Number.isFinite(pid)) return pid;
  } catch {}
  return null;
}

function hyprctlJSON(cmd) {
  try {
    const out = execSync(cmd, { timeout: 1000 }).toString();
    return JSON.parse(out);
  } catch {
    return null;
  }
}

function captureTerminalAddress(pid) {
  if (!pid) return null;
  const clients = hyprctlJSON("hyprctl clients -j");
  if (!Array.isArray(clients)) return null;
  const direct = clients.find((c) => c.pid === pid);
  if (direct?.address) return direct.address;
  const byComm = clients.find(
    (c) => c.pid && readProcComm(c.pid) && TERMINAL_REGEX.test(readProcComm(c.pid))
  );
  return byComm?.address ?? null;
}

function isTerminalFocused(terminalPid) {
  const active = hyprctlJSON("hyprctl activewindow -j");
  if (!active) return false;
  if (active.pid && active.pid === terminalPid) return true;
  const comm = active.pid ? readProcComm(active.pid) : "";
  return Boolean(comm) && TERMINAL_REGEX.test(comm);
}

function focusTerminal(addr) {
  if (!addr) return;
  try {
    execSync(`hyprctl dispatch focuswindow address:${addr}`, { timeout: 1000 });
    log("focused", addr);
  } catch (e) {
    log("focus failed", e?.message ?? String(e));
  }
}

let lastNotifId = null;

function notify(title, body, onClick, { grouping = true, timeoutSec = DEFAULT_TIMEOUT_SEC } = {}) {
  const args = [
    "--app-name",
    "opencode",
    "--urgency",
    "normal",
    "--expire-time",
    String(timeoutSec * 1000),
    "--action",
    "default=Focus terminal",
  ];
  if (grouping && lastNotifId !== null) {
    args.push("--replace-id", String(lastNotifId));
  }
  args.push("--print-id", "--", title, body);

  const child = spawn("notify-send", args, {
    stdio: ["ignore", "pipe", "ignore"],
  });
  let buf = "";
  child.stdout?.on("data", (chunk) => {
    buf += chunk.toString();
    let nl;
    while ((nl = buf.indexOf("\n")) >= 0) {
      const line = buf.slice(0, nl).trim();
      buf = buf.slice(nl + 1);
      if (!line) continue;
      if (/^\d+$/.test(line)) {
        lastNotifId = parseInt(line, 10);
        continue;
      }
      if (line === "default") {
        onClick?.();
      }
    }
  });
  child.on("error", (e) => log("notify-send spawn error", e?.message ?? String(e)));
}

function makePlugin({ client, directory }) {
  if (process.platform !== "linux") {
    log("disabled: not linux");
    return {};
  }
  if (!process.env.HYPRLAND_INSTANCE_SIGNATURE) {
    log("disabled: no HYPRLAND_INSTANCE_SIGNATURE");
    return {};
  }

  const terminalPid = findTerminalPid();
  const terminalAddress =
    PINNED_ADDR || captureTerminalAddress(terminalPid) || null;
  log("captured pid=", terminalPid, "addr=", terminalAddress);

  if (!terminalAddress) {
    log("disabled: could not resolve terminal window address");
  }

  const projectName = directory ? basename(directory) : null;

  function emit(eventType) {
    if (!terminalAddress) return;
    if (isTerminalFocused(terminalPid)) {
      log("suppressed (terminal focused)");
      return;
    }
    const title = `OpenCode${projectName ? ` (${projectName})` : ""}`;
    const body = MESSAGES[eventType] ?? eventType;
    notify(title, body, () => focusTerminal(terminalAddress));
  }

  return {
    event: async ({ event }) => {
      log("event", event?.type);
      if (event.type === "permission.asked") emit("permission");
      else if (event.type === "session.idle") emit("complete");
      else if (event.type === "session.error") emit("error");
    },
    "permission.ask": async () => emit("permission"),
    "tool.execute.before": async (input) => {
      if (input?.tool === "question") emit("question");
      else if (input?.tool === "plan_exit") emit("plan_exit");
    },
  };
}

export function HyprlandFocusNotifierPlugin(opts) {
  try {
    return makePlugin(opts);
  } catch (e) {
    log("plugin init failed", e?.message ?? String(e));
    return {};
  }
}

export default HyprlandFocusNotifierPlugin;
