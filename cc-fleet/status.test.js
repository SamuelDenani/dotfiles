"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const { readStatuses, rank, summarize } = require("./status");

// --- helpers --------------------------------------------------------------

function makeTmpDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "cc-fleet-test-"));
}

function rmTmpDir(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
}

function validStatus(overrides = {}) {
  return {
    pane: "%3",
    state: "working",
    dir: "/home/u/proj",
    summary: "doing a thing",
    ts: 1000,
    ...overrides,
  };
}

function writeStatus(dir, paneid, obj) {
  fs.writeFileSync(
    path.join(dir, `${paneid}.json`),
    JSON.stringify(obj),
    "utf8"
  );
}

function writeRaw(dir, filename, contents) {
  fs.writeFileSync(path.join(dir, filename), contents, "utf8");
}

// =========================================================================
// readStatuses
// =========================================================================

test("readStatuses: reads and parses every valid *.json status file", () => {
  const dir = makeTmpDir();
  try {
    writeStatus(dir, "%3", validStatus({ pane: "%3", state: "working" }));
    writeStatus(dir, "%12", validStatus({ pane: "%12", state: "done" }));

    const result = readStatuses(dir);

    assert.equal(Array.isArray(result), true);
    assert.equal(result.length, 2);
    const panes = result.map((s) => s.pane).sort();
    assert.deepEqual(panes, ["%12", "%3"]);
    const byPane = Object.fromEntries(result.map((s) => [s.pane, s]));
    assert.equal(byPane["%3"].state, "working");
    assert.equal(byPane["%12"].state, "done");
    assert.equal(byPane["%3"].dir, "/home/u/proj");
    assert.equal(byPane["%3"].summary, "doing a thing");
    assert.equal(byPane["%3"].ts, 1000);
  } finally {
    rmTmpDir(dir);
  }
});

test("readStatuses: missing/nonexistent dir returns [] (no throw)", () => {
  const dir = path.join(os.tmpdir(), "cc-fleet-does-not-exist-" + Date.now());
  assert.doesNotThrow(() => readStatuses(dir));
  assert.deepEqual(readStatuses(dir), []);
});

test("readStatuses: empty dir returns []", () => {
  const dir = makeTmpDir();
  try {
    assert.deepEqual(readStatuses(dir), []);
  } finally {
    rmTmpDir(dir);
  }
});

test("readStatuses: skips files with invalid JSON (no throw)", () => {
  const dir = makeTmpDir();
  try {
    writeStatus(dir, "%1", validStatus({ pane: "%1" }));
    writeRaw(dir, "%2.json", "{ this is not valid json ]");

    const result = readStatuses(dir);

    assert.equal(result.length, 1);
    assert.equal(result[0].pane, "%1");
  } finally {
    rmTmpDir(dir);
  }
});

test("readStatuses: skips files missing a required field (pane)", () => {
  const dir = makeTmpDir();
  try {
    const bad = validStatus();
    delete bad.pane;
    writeStatus(dir, "%bad", bad);
    writeStatus(dir, "%good", validStatus({ pane: "%good" }));

    const result = readStatuses(dir);

    assert.equal(result.length, 1);
    assert.equal(result[0].pane, "%good");
  } finally {
    rmTmpDir(dir);
  }
});

test("readStatuses: skips files missing required fields (state/dir/summary/ts)", () => {
  const dir = makeTmpDir();
  try {
    for (const field of ["state", "dir", "summary", "ts"]) {
      const bad = validStatus({ pane: "%" + field });
      delete bad[field];
      writeStatus(dir, "%" + field, bad);
    }
    writeStatus(dir, "%ok", validStatus({ pane: "%ok" }));

    const result = readStatuses(dir);

    assert.equal(result.length, 1);
    assert.equal(result[0].pane, "%ok");
  } finally {
    rmTmpDir(dir);
  }
});

test("readStatuses: skips files with an unknown state value", () => {
  const dir = makeTmpDir();
  try {
    writeStatus(dir, "%weird", validStatus({ pane: "%weird", state: "explode" }));
    writeStatus(dir, "%ok", validStatus({ pane: "%ok", state: "idle" }));

    const result = readStatuses(dir);

    assert.equal(result.length, 1);
    assert.equal(result[0].pane, "%ok");
  } finally {
    rmTmpDir(dir);
  }
});

test("readStatuses: accepts all four valid state values", () => {
  const dir = makeTmpDir();
  try {
    const states = ["needs-you", "working", "done", "idle"];
    states.forEach((state, i) => {
      writeStatus(dir, "%" + i, validStatus({ pane: "%" + i, state }));
    });

    const result = readStatuses(dir);

    assert.equal(result.length, 4);
    assert.deepEqual(result.map((s) => s.state).sort(), [...states].sort());
  } finally {
    rmTmpDir(dir);
  }
});

test("readStatuses: skips files with non-numeric ts", () => {
  const dir = makeTmpDir();
  try {
    writeStatus(dir, "%str", validStatus({ pane: "%str", ts: "1000" }));
    writeStatus(dir, "%null", validStatus({ pane: "%null", ts: null }));
    writeStatus(dir, "%ok", validStatus({ pane: "%ok", ts: 1234 }));

    const result = readStatuses(dir);

    assert.equal(result.length, 1);
    assert.equal(result[0].pane, "%ok");
  } finally {
    rmTmpDir(dir);
  }
});

test("readStatuses: ignores non-.json files in the dir", () => {
  const dir = makeTmpDir();
  try {
    writeStatus(dir, "%1", validStatus({ pane: "%1" }));
    writeRaw(dir, "notes.txt", "hello");
    writeRaw(dir, "README.md", "# nope");
    writeRaw(dir, "data.json.bak", JSON.stringify(validStatus({ pane: "%x" })));

    const result = readStatuses(dir);

    assert.equal(result.length, 1);
    assert.equal(result[0].pane, "%1");
  } finally {
    rmTmpDir(dir);
  }
});

// =========================================================================
// rank
// =========================================================================

test("rank: orders by state priority needs-you > done > working > idle", () => {
  const input = [
    validStatus({ pane: "%idle", state: "idle", ts: 1 }),
    validStatus({ pane: "%working", state: "working", ts: 1 }),
    validStatus({ pane: "%done", state: "done", ts: 1 }),
    validStatus({ pane: "%needs", state: "needs-you", ts: 1 }),
  ];

  const result = rank(input);

  assert.deepEqual(
    result.map((s) => s.state),
    ["needs-you", "done", "working", "idle"]
  );
});

test("rank: tie-break within same state puts oldest (smaller) ts first", () => {
  const input = [
    validStatus({ pane: "%new", state: "working", ts: 3000 }),
    validStatus({ pane: "%old", state: "working", ts: 1000 }),
    validStatus({ pane: "%mid", state: "working", ts: 2000 }),
  ];

  const result = rank(input);

  assert.deepEqual(
    result.map((s) => s.pane),
    ["%old", "%mid", "%new"]
  );
});

test("rank: priority dominates ts (older idle still ranks below newer needs-you)", () => {
  const input = [
    validStatus({ pane: "%idle-old", state: "idle", ts: 1 }),
    validStatus({ pane: "%needs-new", state: "needs-you", ts: 9999 }),
  ];

  const result = rank(input);

  assert.deepEqual(
    result.map((s) => s.pane),
    ["%needs-new", "%idle-old"]
  );
});

test("rank: combined priority + tie-break ordering", () => {
  const input = [
    validStatus({ pane: "%w2", state: "working", ts: 200 }),
    validStatus({ pane: "%n2", state: "needs-you", ts: 50 }),
    validStatus({ pane: "%w1", state: "working", ts: 100 }),
    validStatus({ pane: "%n1", state: "needs-you", ts: 10 }),
    validStatus({ pane: "%d1", state: "done", ts: 5 }),
  ];

  const result = rank(input);

  assert.deepEqual(
    result.map((s) => s.pane),
    ["%n1", "%n2", "%d1", "%w1", "%w2"]
  );
});

test("rank: returns a NEW array and does not mutate input", () => {
  const input = [
    validStatus({ pane: "%idle", state: "idle", ts: 1 }),
    validStatus({ pane: "%needs", state: "needs-you", ts: 2 }),
  ];
  const inputSnapshot = input.map((s) => ({ ...s }));

  const result = rank(input);

  assert.notEqual(result, input, "should return a new array reference");
  assert.deepEqual(
    input.map((s) => s.pane),
    inputSnapshot.map((s) => s.pane),
    "input order must be unchanged"
  );
  assert.deepEqual(input, inputSnapshot, "input objects must be unchanged");
});

test("rank: empty input returns []", () => {
  const result = rank([]);
  assert.deepEqual(result, []);
});

// =========================================================================
// summarize
// =========================================================================

test("summarize: empty input returns empty string", () => {
  assert.equal(summarize([]), "");
});

test("summarize: single present state emits glyph+count then #[default]", () => {
  const input = [
    validStatus({ state: "needs-you", ts: 1 }),
    validStatus({ state: "needs-you", ts: 2 }),
  ];

  assert.equal(summarize(input), "#[fg=red]●2 #[default]");
});

test("summarize: example {needs-you:2, done:1} from the spec", () => {
  const input = [
    validStatus({ state: "needs-you", ts: 1 }),
    validStatus({ state: "needs-you", ts: 2 }),
    validStatus({ state: "done", ts: 3 }),
  ];

  assert.equal(summarize(input), "#[fg=red]●2 #[fg=green]✓1 #[default]");
});

test("summarize: all four states render in priority order with correct glyphs/colors", () => {
  const input = [
    validStatus({ state: "idle" }),
    validStatus({ state: "working" }),
    validStatus({ state: "done" }),
    validStatus({ state: "needs-you" }),
  ];

  assert.equal(
    summarize(input),
    "#[fg=red]●1 #[fg=green]✓1 #[fg=yellow]◐1 #[fg=brightblack]○1 #[default]"
  );
});

test("summarize: states with zero count are omitted", () => {
  const input = [
    validStatus({ state: "working" }),
    validStatus({ state: "working" }),
    validStatus({ state: "idle" }),
  ];

  // needs-you and done absent -> omitted
  assert.equal(
    summarize(input),
    "#[fg=yellow]◐2 #[fg=brightblack]○1 #[default]"
  );
});

test("summarize: output order is priority order regardless of input order", () => {
  const ordered = [
    validStatus({ state: "needs-you" }),
    validStatus({ state: "done" }),
    validStatus({ state: "working" }),
    validStatus({ state: "idle" }),
  ];
  const shuffled = [
    validStatus({ state: "idle" }),
    validStatus({ state: "needs-you" }),
    validStatus({ state: "working" }),
    validStatus({ state: "done" }),
  ];

  assert.equal(summarize(shuffled), summarize(ordered));
});

test("summarize: counts aggregate correctly per state", () => {
  const input = [
    validStatus({ state: "needs-you" }),
    validStatus({ state: "needs-you" }),
    validStatus({ state: "needs-you" }),
    validStatus({ state: "working" }),
  ];

  assert.equal(summarize(input), "#[fg=red]●3 #[fg=yellow]◐1 #[default]");
});

test("summarize: does not mutate its input", () => {
  const input = [
    validStatus({ state: "working" }),
    validStatus({ state: "needs-you" }),
  ];
  const snapshot = input.map((s) => ({ ...s }));

  summarize(input);

  assert.deepEqual(input, snapshot);
});
