"use strict";

// cc-fleet status core — pure functions over a dir of per-pane status files.
// Consumed by hook.js (writer) and the tmux status-right / dashboard readers.

const fs = require("node:fs");
const path = require("node:path");

// Priority order, highest urgency first.
const PRIORITY = ["needs-you", "done", "working", "idle"];
const PRIORITY_INDEX = Object.fromEntries(PRIORITY.map((s, i) => [s, i]));
const VALID_STATES = new Set(PRIORITY);

const GLYPH = {
  "needs-you": "#[fg=red]●",
  "done": "#[fg=green]✓",
  "working": "#[fg=yellow]◐",
  "idle": "#[fg=brightblack]○",
};

const REQUIRED_STRINGS = ["pane", "dir", "summary"];

function isValid(obj) {
  if (!obj || typeof obj !== "object") return false;
  for (const k of REQUIRED_STRINGS) {
    if (typeof obj[k] !== "string") return false;
  }
  if (typeof obj.state !== "string" || !VALID_STATES.has(obj.state)) return false;
  if (typeof obj.ts !== "number" || Number.isNaN(obj.ts)) return false;
  return true;
}

// readStatuses(dir) -> Array<status>. Skips corrupt/invalid files, never throws.
function readStatuses(dir) {
  let names;
  try {
    names = fs.readdirSync(dir);
  } catch (e) {
    return [];
  }
  const out = [];
  for (const name of names) {
    if (!name.endsWith(".json")) continue;
    let parsed;
    try {
      parsed = JSON.parse(fs.readFileSync(path.join(dir, name), "utf8"));
    } catch (e) {
      continue;
    }
    if (isValid(parsed)) out.push(parsed);
  }
  return out;
}

// rank(statuses) -> new sorted array. Priority asc, tie-break oldest ts first.
function rank(statuses) {
  return statuses.slice().sort((a, b) => {
    const d = PRIORITY_INDEX[a.state] - PRIORITY_INDEX[b.state];
    return d !== 0 ? d : a.ts - b.ts;
  });
}

// summarize(statuses) -> tmux status-right fragment. Empty input -> "".
function summarize(statuses) {
  const counts = Object.create(null);
  for (const s of statuses) counts[s.state] = (counts[s.state] || 0) + 1;
  const segments = [];
  for (const state of PRIORITY) {
    if (counts[state]) segments.push(`${GLYPH[state]}${counts[state]}`);
  }
  if (segments.length === 0) return "";
  return segments.join(" ") + " #[default]";
}

module.exports = { readStatuses, rank, summarize, PRIORITY, GLYPH };
