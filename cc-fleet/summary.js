#!/usr/bin/env node
"use strict";

// cc-fleet status-right reader. Prints the tmux summary fragment for all LIVE
// panes (filters out status files of panes that no longer exist). Invoked by
// tmux every status-interval via #(...).

const os = require("node:os");
const path = require("node:path");
const { execSync } = require("node:child_process");
const { readStatuses, summarize } = require(path.join(__dirname, "status.js"));

const runDir = path.join(os.homedir(), ".claude", "cc-fleet", "run");

let live = null;
try {
  const out = execSync("tmux list-panes -a -F '#{pane_id}'", { encoding: "utf8" });
  live = new Set(out.split("\n").filter(Boolean));
} catch (e) { /* not in tmux / no server — show all */ }

let statuses = readStatuses(runDir);
if (live) statuses = statuses.filter((s) => live.has(s.pane));

process.stdout.write(summarize(statuses));
