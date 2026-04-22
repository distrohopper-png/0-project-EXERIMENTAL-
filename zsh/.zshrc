# ~/.zshrc

# ── Prompt colors (defined early so _reload_colors can call _build_colors) ────
_pc() {
    local h="${1#'#'}"
    printf '%%{\033[38;2;%d;%d;%dm%%}' $((16#${h:0:2})) $((16#${h:2:2})) $((16#${h:4:2}))
}

_build_colors() {
    # Material You "on" colors are pastels — boost sat/val so they look vivid on dark bg
    local _vivid
    _vivid=$(python3 -c "
import colorsys
def boost(hex_in):
    h = hex_in.lstrip('#')
    r,g,b = int(h[0:2],16)/255, int(h[2:4],16)/255, int(h[4:6],16)/255
    hue,sat,val = colorsys.rgb_to_hsv(r,g,b)
    if sat > 0.10:
        sat = max(sat, 0.72)
        val = min(0.92, max(val, 0.80))
    r2,g2,b2 = colorsys.hsv_to_rgb(hue, sat, val)
    return f'#{int(r2*255):02x}{int(g2*255):02x}{int(b2*255):02x}'
print(boost('${ZSH_C1:-#ffb4aa}'))
print(boost('${ZSH_C2:-#e7bdb7}'))
print(boost('${ZSH_C3:-#77ac6c}'))
" 2>/dev/null)
    _VC1=$(echo "$_vivid" | sed -n '1p')
    _VC2=$(echo "$_vivid" | sed -n '2p')
    _VC3=$(echo "$_vivid" | sed -n '3p')
    [[ -n "$_VC1" ]] || _VC1="${ZSH_C1:-#ffb4aa}"
    [[ -n "$_VC2" ]] || _VC2="${ZSH_C2:-#e7bdb7}"
    [[ -n "$_VC3" ]] || _VC3="${ZSH_C3:-#77ac6c}"
    _PC1=$(_pc "$_VC1")
    _PC2=$(_pc "$_VC2")
    _PC3=$(_pc "$_VC3")
    _PC4=$(_pc "${ZSH_C4:-504c50}")
    _PC5=$(_pc "${ZSH_C5:-ffd7d0}")
    _PR=$'%{\033[0m%}'
    _PERR=$'%{\033[38;2;255;80;80m%}'
}

# ── Matugen colors — reloads automatically whenever matugen writes new colors ──
_COLORS_TS=0
_reload_colors() {
    local f="$HOME/.config/zsh/colors.zsh"
    [[ -f "$f" ]] || return
    local ts; ts=$(stat -c %y "$f" 2>/dev/null) || ts=0
    [[ "$ts" == "$_COLORS_TS" ]] && return
    source "$f"
    _COLORS_TS=$ts
    _build_colors
}
_reload_colors

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

# ── matrix rain (transparent ANSI, matugen-synced color) ──────────────────────
cmatrix() {
    python3 "$HOME/.config/scripts/matrix-rain.py" "$@"
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

    # Re-source to pick up latest matugen colors, then rebuild vivid vars
    [[ -f "$colors_file" ]] && source "$colors_file"
    _build_colors

    local c1="${_VC1:-${ZSH_C1:-#ffb4aa}}"
    local c2="${_VC2:-${ZSH_C2:-#e7bdb7}}"
    local c3="${_VC3:-${ZSH_C3:-#77ac6c}}"

    # Rebuild config only if colors changed or config is missing
    if [[ ! -f "$cfg" ]] || [[ "$colors_file" -nt "$cfg" ]]; then
        # Generate 8-color hue wheel from the primary wallpaper color
        local palette
        palette=$(ZSH_PRIMARY="$c1" python3 <<'PYEOF'
import os, colorsys
h = os.environ['ZSH_PRIMARY'].lstrip('#')
r, g, b = int(h[0:2],16)/255, int(h[2:4],16)/255, int(h[4:6],16)/255
hue, sat, val = colorsys.rgb_to_hsv(r, g, b)
sat = max(0.70, sat)
val = max(0.82, val)
parts = []
for i in range(8):
    h2 = (hue + i / 8.0) % 1.0
    r2, g2, b2 = colorsys.hsv_to_rgb(h2, sat, val)
    R, G, B = int(r2*255), int(g2*255), int(b2*255)
    parts.append(f'\\\\e[38;2;{R};{G};{B}m●\\\\e[0m')
print(' '.join(parts))
PYEOF
)

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
    { "type": "shell",  "key": "  shell", "keyColor": "$c3" },
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
    _reload_colors
    local dir="${PWD/#$HOME/~}"
    local colored_dir
    if [[ "$dir" == "~"* ]]; then
        colored_dir="${_PC5}~${_PC1}${dir:1}"
    else
        colored_dir="${_PC1}${dir}"
    fi
    local git=$(_git_info)
    local arrow
    [[ $code -eq 0 ]] && arrow="${_PC3}❯${_PR}" || arrow="${_PERR}❯${_PR}"
    PROMPT="${_PC4}╭─${_PR} ${colored_dir}${_PR}${git}
${_PC4}╰─${_PR}${arrow} "
}

# ── Plugins ────────────────────────────────────────────────────────────────────
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# ── Run fetch on shell start ───────────────────────────────────────────────────
fetch
