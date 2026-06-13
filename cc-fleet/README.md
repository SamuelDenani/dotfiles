# cc-fleet

Tooling to run and manage ~4 parallel [Claude Code](https://claude.com/claude-code)
sessions in tmux: a 2×2 grid launcher, per-pane status borders, a fleet status
summary in the tmux status bar, desktop toasts when a session needs you, and a
persistent floating scratch popup.

## Pieces

| File | Role |
| --- | --- |
| `bin/claude-grid` | `claude-grid [d1 d2 d3 d4]` — spawn a `cc` session, 2×2 tiled, `claude` per pane (dirs default to `$PWD`). Sets a per-pane state border scoped to that session. |
| `bin/cc-scratch` | Persistent floating scratch on its own tmux socket (`-L cc-scratch`): one `main` session, one window per dir. True toggle via `prefix+Enter`; nesting guarded. |
| `fleet.tmux` | tmux glue: `prefix+Enter` scratch popup, fleet summary appended to `status-right`, fast nav (`prefix+digit` = pane, `prefix+Alt+digit` = window), `pane-base-index 1`. Sourced from `~/.tmux.conf` **after** tpm/catppuccin so it wins. |
| `hook.js` | One Claude hook for `SessionStart`/`UserPromptSubmit`/`Stop`/`Notification` → writes `run/<pane>.json`, sets tmux `@cc_state` (border color), fires a toast on `needs-you`. |
| `status.js` | Pure core: `readStatuses` / `rank` / `summarize`. States: `needs-you` (red ●) > `done` (green ✓) > `working` (yellow ◐) > `idle` (grey ○). |
| `status.test.js` | 24 tests via `node --test` (`npm test`). |
| `summary.js` | `status-right` reader; filters to live panes only. |
| `notify.sh` | Desktop toast — Windows toast via `powershell.exe` on WSL (AUMID trick), `notify-send` fallback. |

`run/` (per-pane state) is runtime-only and gitignored.

## Install

```sh
./install.sh
```

Symlinks the core into `~/.claude/cc-fleet/` and the bins into `~/.local/bin/`,
creates `run/`, and appends the `fleet.tmux` source-line to `~/.tmux.conf` if
missing. Then follow the two manual steps it prints: register the hook in
`~/.claude/settings.json`, and (on a non-`samueldenani` machine) fix the
hardcoded absolute paths in `fleet.tmux`.

## Keys

- `prefix + Enter` — toggle the scratch popup (opens in the current pane's dir).
- `prefix + <digit>` — select pane N (1-indexed, matches the badge).
- `prefix + Alt + <digit>` — select window N.

## Notes

- Claude hooks activate on the **next** session after a `settings.json` edit.
- catppuccin manages `status-right`; the fleet summary is appended. If a
  catppuccin rebuild clobbers it, hardcode the append differently.
- Never run `claude-grid` inside the scratch popup — it refuses, since `$TMUX`
  would point at the scratch socket.
