#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

fastfetch --config "$HOME/.config/fastfetch/small.jsonc"

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

alias hyprconf='nano ~/.config/hypr/hyprland.conf'
alias cavaconf='nano ~/.config/cava/config'

# cmatrix with wallpaper-synced color (via matugen)
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
