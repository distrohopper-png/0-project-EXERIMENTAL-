# ~/.zshrc

# ── Matugen colors (sourced first so fetch() has them immediately) ─────────────
[[ -f "$HOME/.config/zsh/colors.zsh" ]] && source "$HOME/.config/zsh/colors.zsh"

# ── Options ───────────────────────────────────────────────────────────────────
setopt AUTO_CD PROMPT_SUBST
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE
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

# ── cd: auto-ls after changing directory ──────────────────────────────────────
cd() { builtin cd "$@" && ls --color=auto; }

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

# ── qcopy: fzf file picker → clipboard ───────────────────────────────────────
qcopy() {
    if ! command -v wl-copy &>/dev/null; then echo "Error: install wl-clipboard"; return 1; fi
    if ! command -v fzf &>/dev/null; then echo "Error: install fzf"; return 1; fi
    local preview_cmd="cat {}"
    command -v bat &>/dev/null && preview_cmd="bat --style=numbers --color=always {}"
    local selected
    selected=$(find . -type f -not -path "*/\.git/*" 2>/dev/null | fzf --multi \
        --layout=reverse \
        --preview="$preview_cmd" \
        --preview-window=right:60%:wrap \
        --prompt="Select files > " \
        --header="TAB to select, ENTER to copy, ESC to cancel")
    [[ -z "$selected" ]] && { echo "Cancelled."; return 0; }
    local tmp; tmp=$(mktemp)
    while IFS= read -r file; do
        echo "file name: ${file#./}" >> "$tmp"
        echo "file contents:" >> "$tmp"
        cat "$file" >> "$tmp"
        printf '\n----------------------------------------\n\n' >> "$tmp"
    done <<< "$selected"
    cat "$tmp" | wl-copy
    echo "Copied $(echo "$selected" | wc -l) file(s) to clipboard."
    rm -f "$tmp"
}

# ── pasteimg: paste clipboard image to file ───────────────────────────────────
pasteimg() {
    local name="${1:-clipboard.png}"
    [[ "$name" != *.png ]] && name="$name.png"
    wl-paste --type image/png > "$name" && echo "Saved to $name"
}

# ── fetch: matugen-colored fastfetch with arch_small logo + palette ────────────
fetch() {
    local colors_file="$HOME/.config/zsh/colors.zsh"
    local cfg="/tmp/zsh_fastfetch.jsonc"

    # Re-source to pick up latest matugen colors
    [[ -f "$colors_file" ]] && source "$colors_file"

    local c1="${ZSH_C1:-#ffb4aa}"
    local c2="${ZSH_C2:-#e7bdb7}"
    local c3="${ZSH_C3:-#77ac6c}"

    # Rebuild config only if colors changed or config is missing
    if [[ ! -f "$cfg" ]] || [[ "$colors_file" -nt "$cfg" ]]; then
        # Build ANSI palette strip from 8 matugen swatches
        local palette=""
        for hex in "${ZSH_P1:-$c1}" "${ZSH_P2:-$c2}" "${ZSH_P3:-$c3}" \
                   "${ZSH_P4:-$c1}" "${ZSH_P5:-$c2}" "${ZSH_P6:-$c3}" \
                   "${ZSH_P7:-#ff5055}" "${ZSH_P8:-#aaaaaa}"; do
            local h="${hex#'#'}"
            local r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))
            palette+="\\\\e[38;2;${r};${g};${b}m●\\\\e[0m "
        done

        cat > "$cfg" <<EOF
{
  "\$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "arch_small",
    "color": { "1": "$c1", "2": "$c2" },
    "padding": { "top": 1, "left": 1, "right": 2 }
  },
  "display": { "separator": "  " },
  "modules": [
    "break",
    {
      "type": "title",
      "format": "{user-name}@{host-name}",
      "color": { "user": "$c1", "host": "$c2" }
    },
    "break",
    { "type": "os",     "key": "  os",  "keyColor": "$c1" },
    { "type": "cpu",    "key": "  cpu", "keyColor": "$c2" },
    { "type": "gpu",    "key": "  gpu", "keyColor": "$c2",
      "detectionMethod": "pci", "hideType": "integrated" },
    { "type": "memory", "key": "  ram", "keyColor": "$c3" },
    "break",
    { "type": "command", "key": "  ", "keyColor": "$c1",
      "text": "echo -e '$palette'" }
  ]
}
EOF
    fi

    fastfetch -c "$cfg"
}

# ── Prompt ────────────────────────────────────────────────────────────────────
_pc() {
    local h="${1#'#'}"
    printf '%%{\033[38;2;%d;%d;%dm%%}' $((16#${h:0:2})) $((16#${h:2:2})) $((16#${h:4:2}))
}

_build_colors() {
    _PC1=$(_pc "${ZSH_C1:-ffb4aa}")
    _PC2=$(_pc "${ZSH_C2:-e7bdb7}")
    _PC3=$(_pc "${ZSH_C3:-77ac6c}")
    _PC4=$(_pc "${ZSH_C4:-504c50}")
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

# ── Plugins ────────────────────────────────────────────────────────────────────
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ── Run fetch on shell start ───────────────────────────────────────────────────
fetch
