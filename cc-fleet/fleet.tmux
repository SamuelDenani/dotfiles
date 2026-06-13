# cc-fleet — sourced from ~/.tmux.conf AFTER tpm/catppuccin so these win.
# Disable the whole feature by removing the source-file line in ~/.tmux.conf.

# Fleet status summary, appended to whatever catppuccin set.
set -g status-interval 3
set -ga status-right '#[default] #(/home/samueldenani/.claude/cc-fleet/summary.js)'

# Scratch popup: prefix+Enter. Centered ~85%, cd's to the current pane's dir,
# attaches a persistent session on the cc-scratch socket (history survives
# close). Close/hide with prefix+d (detach) — the scratch session persists.
# -d IS format-expanded (the trailing shell-command is NOT), so the popup opens
# in the current pane's dir and cc-scratch reads it from $PWD.
bind Enter display-popup -E -d "#{pane_current_path}" -w 85% -h 85% "/home/samueldenani/.local/bin/cc-scratch"

# Fast nav: prefix+digit selects PANE, prefix+Alt+digit selects WINDOW.
# Panes 1-indexed so the digit matches the badge. Alt+digit is terminal-safe
# (Ctrl+digit is not). Windows move off plain digit onto Alt.
set -g pane-base-index 1
bind 1 select-pane -t 1
bind 2 select-pane -t 2
bind 3 select-pane -t 3
bind 4 select-pane -t 4
bind 5 select-pane -t 5
bind 6 select-pane -t 6
bind 7 select-pane -t 7
bind 8 select-pane -t 8
bind 9 select-pane -t 9
bind M-1 select-window -t 1
bind M-2 select-window -t 2
bind M-3 select-window -t 3
bind M-4 select-window -t 4
bind M-5 select-window -t 5
bind M-6 select-window -t 6
bind M-7 select-window -t 7
bind M-8 select-window -t 8
bind M-9 select-window -t 9
