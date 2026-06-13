#!/usr/bin/env node
"use strict";

// cc-fleet hook — one entry for SessionStart/UserPromptSubmit/Stop/Notification.
// Maps the event to a state, writes run/<pane>.json, sets the tmux per-pane
// option @cc_state (drives border color), and fires a desktop toast when Claude
// needs you. No stdout — never injects context or blocks a prompt.

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFile } = require("node:child_process");

const pane = process.env.TMUX_PANE;
if (!pane) process.exit(0); // not in a tmux pane — nothing to track

const STATE_BY_EVENT = {
  SessionStart: "idle",
  UserPromptSubmit: "working",
  Stop: "done",
  Notification: "needs-you",
};

let raw = "";
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  let data = {};
  try { data = JSON.parse(raw || "{}"); } catch (e) {}

  const state = STATE_BY_EVENT[data.hook_event_name];
  if (!state) process.exit(0);

  const dir = data.cwd || process.env.PWD || process.cwd();
  const runDir = path.join(os.homedir(), ".claude", "cc-fleet", "run");
  try { fs.mkdirSync(runDir, { recursive: true }); } catch (e) {}

  const rec = { pane, state, dir, summary: path.basename(dir || ""), ts: Date.now() };
  try { fs.writeFileSync(path.join(runDir, pane + ".json"), JSON.stringify(rec)); } catch (e) {}

  // Per-pane border color (silent if pane is gone).
  execFile("tmux", ["set", "-p", "-t", pane, "@cc_state", state], () => {});

  // Toast only when Claude actually needs you.
  if (state === "needs-you") {
    const msg = String(data.message || "Claude needs your input").slice(0, 200);
    const notify = path.join(os.homedir(), ".claude", "cc-fleet", "notify.sh");
    execFile("bash", [notify, "Claude · " + path.basename(dir || ""), msg], () => {});
  }

  process.exit(0);
});
