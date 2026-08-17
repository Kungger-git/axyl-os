export ZSH="${HOME}/.oh-my-zsh"

ZSH_THEME="robbyrussell"
HIST_STAMPS="yyyy-mm-dd"
DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT="true"

plugins=(git colored-man-pages zsh-autosuggestions zsh-syntax-highlighting)

source "${ZSH}/oh-my-zsh.sh"

# Aliases
alias ls='ls --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias vi='nvim'
alias vim='nvim'

export EDITOR=nvim
export VISUAL=nvim
export BROWSER=qutebrowser
export LF_COLORS="di=38;2;110;114;144:ln=38;2;217;119;87:ex=38;2;80;250;123:*.jpg=38;2;232;146;124:*.png=38;2;232;146;124:*.gif=38;2;232;146;124:*.mp4=38;2;189;147;249:*.mkv=38;2;189;147;249:*.pdf=38;2;255;85;85"
export TERM=xterm-256color

# zsh-autosuggestions: accept with right arrow
bindkey '^[[C' autosuggest-accept