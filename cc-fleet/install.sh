#!/usr/bin/env bash
# cc-fleet installer — symlinks the tracked tooling into the live locations the
# Claude hook + tmux expect:
#   ~/.claude/cc-fleet/*   (hook.js, summary.js, fleet.tmux, ...)
#   ~/.local/bin/{claude-grid,cc-scratch}
# Idempotent. Re-run after pulling updates. Never edits settings.json for you —
# it prints the hook block to paste (see README).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CC_DIR="$HOME/.claude/cc-fleet"
BIN_DIR="$HOME/.local/bin"
TMUX_CONF="$HOME/.tmux.conf"

mkdir -p "$CC_DIR/run" "$BIN_DIR"

link() { ln -sfn "$1" "$2"; echo "  $2 -> $1"; }

echo "Linking cc-fleet core into $CC_DIR"
for f in fleet.tmux hook.js notify.sh status.js status.test.js summary.js package.json; do
  link "$REPO_DIR/$f" "$CC_DIR/$f"
done

echo "Linking bins into $BIN_DIR"
for b in claude-grid cc-scratch; do
  link "$REPO_DIR/bin/$b" "$BIN_DIR/$b"
done

# Ensure ~/.tmux.conf sources fleet.tmux (must come AFTER tpm/catppuccin).
SRC_LINE='source-file ~/.claude/cc-fleet/fleet.tmux'
if [ -f "$TMUX_CONF" ] && grep -qF "$SRC_LINE" "$TMUX_CONF"; then
  echo "tmux source-line already present in $TMUX_CONF"
else
  printf '\n# cc-fleet — sourced last so it overrides plugin status-right. Remove to disable.\n%s\n' "$SRC_LINE" >> "$TMUX_CONF"
  echo "Appended fleet.tmux source-line to $TMUX_CONF"
fi

cat <<'NOTE'

Done. Two manual steps remain:

1. Register the Claude hook in ~/.claude/settings.json (under "hooks"):

   "SessionStart":      [ { "hooks": [ { "type": "command", "command": "<HOME>/.claude/cc-fleet/hook.js" } ] } ],
   "UserPromptSubmit":  [ { "hooks": [ { "type": "command", "command": "<HOME>/.claude/cc-fleet/hook.js" } ] } ],
   "Stop":              [ { "hooks": [ { "type": "command", "command": "<HOME>/.claude/cc-fleet/hook.js" } ] } ],
   "Notification":      [ { "hooks": [ { "type": "command", "command": "<HOME>/.claude/cc-fleet/hook.js" } ] } ]

   (Replace <HOME> with your home dir. Hooks take effect on the next session.)

2. fleet.tmux hardcodes absolute paths for summary.js and cc-scratch
   (/home/samueldenani/...). On a different machine, edit those two paths.

Reload tmux:  tmux source-file ~/.tmux.conf
NOTE
