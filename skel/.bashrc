#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim
export VISUAL=nvim

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -rthla'
alias vi='nvim'
alias vim='nvim'
alias brave='brave-wayland'
alias files='dolphin'

# Starship prompt when installed
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
else
  PS1='[\u@\h \W]\$ '
fi
