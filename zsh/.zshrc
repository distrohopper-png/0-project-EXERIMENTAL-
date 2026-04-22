# ~/.zshrc

fastfetch --config "$HOME/.config/fastfetch/small.jsonc"

# ── Matugen colors ────────────────────────────────────────────────────────────
[[ -f "$HOME/.config/zsh/colors.zsh" ]] && source "$HOME/.config/zsh/colors.zsh"

# ── Options ───────────────────────────────────────────────────────────────────
setopt AUTO_CD HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY PROMPT_SUBST
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# ── Completion ────────────────────────────────────────────────────────────────
autoload -Uz compinit && compinit -u
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Keys ──────────────────────────────────────────────────────────────────────
bindkey -e
bindkey '^R' history-incremental-search-backward
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# ── Aliases ───────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias hyprconf='nano ~/.config/hypr/hyprland.conf'
alias cavaconf='nano ~/.config/cava/config'

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"

# ── cmatrix (matugen-synced color) ────────────────────────────────────────────
cmatrix() {
    local col
    col=$(python3 - <<'PYEOF' 2>/dev/null
import os
f = os.path.expanduser("~/.config/cmatrix/color")
try:
    hex = open(f).read().strip().lstrip('#')
    r,g,b = int(hex[0:2],16)/255, int(hex[2:4],16)/255, int(hex[4:6],16)/255
    mx,mn = max(r,g,b), min(r,g,b); d = mx-mn
    if d < 0.05: print("white"); raise SystemExit
    if mx==r: hue=(60*((g-b)/d)+360)%360
    elif mx==g: hue=60*((b-r)/d)+120
    else: hue=60*((r-g)/d)+240
    pairs=[("red",0),("yellow",60),("green",120),("cyan",180),("blue",240),("magenta",300),("red",360)]
    print(min(pairs,key=lambda c:min(abs(hue-c[1]),360-abs(hue-c[1])))[0])
except: print("green")
PYEOF
    )
    command cmatrix -C "${col:-green}" "$@"
}

# ── Prompt ────────────────────────────────────────────────────────────────────
# Converts hex (with or without #) to a zero-width zsh prompt fg escape
_pc() {
    local h="${1#'#'}"
    printf '%%{\033[38;2;%d;%d;%dm%%}' $((16#${h:0:2})) $((16#${h:2:2})) $((16#${h:4:2}))
}

_build_colors() {
    _PC1=$(_pc "${ZSH_C1:-ffb4aa}")   # primary   → directory
    _PC2=$(_pc "${ZSH_C2:-dfc38c}")   # secondary → git branch
    _PC3=$(_pc "${ZSH_C3:-77ac6c}")   # tertiary  → success ❯
    _PC4=$(_pc "${ZSH_C4:-504c50}")   # outline   → ╭─ ╰─
    _PR=$'%{\033[0m%}'
    _PERR=$'%{\033[38;2;255;80;80m%}'
}
_build_colors

_git_info() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || \
    branch=$(git rev-parse --short HEAD 2>/dev/null) || return
    git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null \
        && printf '  %s%s%s' "$_PC2" "$branch" "$_PR" \
        || printf '  %s%s ±%s' "$_PC2" "$branch" "$_PR"
}

precmd() {
    local code=$?
    local dir="${PWD/#$HOME/~}"
    local git=$(_git_info)
    local arrow
    [[ $code -eq 0 ]] && arrow="${_PC3}❯${_PR}" || arrow="${_PERR}❯${_PR}"
    PROMPT="${_PC4}╭─${_PR} ${_PC1}${dir}${_PR}${git}
${_PC4}╰─${_PR}${arrow} "
}

# ── Plugins (auto-loaded if installed via pacman) ─────────────────────────────
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
