# Personal fish config, kept in dotfiles and sourced from ~/.config/fish/config.fish
# Adapted from the old .zshrc. Base config (eza aliases, etc.) comes from
# cachyos-config.fish; starship is initialised in the real config.fish.

# --- PATH ---------------------------------------------------------------
# fish_add_path is idempotent (dedupes like zsh's `typeset -U path`) and
# skips directories that don't exist, so re-sourcing is harmless.
fish_add_path -g \
    $HOME/bin \
    $HOME/.local/bin \
    /usr/local/bin \
    /usr/local/go/bin \
    $HOME/go/bin \
    /opt/nvim

# --- Aliases ------------------------------------------------------------
alias h=herdr
alias v=nvim

# --- zoxide -------------------------------------------------------------
# Provides `z`/`zi`; `cd` is remapped to `z` and `code` jumps into ~/code.
if command -q zoxide
    zoxide init fish | source
    alias cd=z
    alias code='z ~/code'
end

# --- fzf ----------------------------------------------------------------
# Key bindings + completions (replaces the old ~/.fzf.zsh source line).
if command -q fzf
    fzf --fish | source
end
