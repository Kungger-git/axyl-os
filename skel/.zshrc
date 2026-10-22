# ~/.zshrc
# Axyl Linux Hyprland session

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
  export VISUAL='nvim'
fi

export PATH="$HOME/.local/bin:$PATH"
export HYPRSHOT_DIR="$HOME/Pictures/Screenshots"

# Aliases
alias zshrc="nvim ~/.zshrc"
alias l="ls -rthla"
alias ll="ls -alFh"
alias la="ls -A"
alias hyprconf="nvim ~/.config/hypr/"
alias waybarconf="nvim ~/.config/waybar/"
alias kittyconf="nvim ~/.config/kitty/"
alias nvimconf="nvim ~/.config/nvim/"
alias brave="brave-wayland"
alias files="dolphin"
alias update="sudo pacman -Syu"
alias venv="source ./venv/bin/activate"

# Prompt
eval "$(starship init zsh)"

# Completion
autoload -Uz compinit
compinit

# History-based suggestions
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting (keep this last)
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Ctrl+O: ranger directory picker
bindkey -s '^O' 'ranger --choosedir=$HOME/.rangerdir; cd "$(cat ~/.rangerdir 2>/dev/null)"\n'

# Ctrl+H: start a Hyprland session when one is not already running.
_hyprland_start() {
  if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]] || pgrep -x Hyprland >/dev/null 2>&1; then
    zle backward-delete-char
  else
    BUFFER='Hyprland'
    zle accept-line
  fi
}
zle -N _hyprland_start
bindkey '^H' _hyprland_start
