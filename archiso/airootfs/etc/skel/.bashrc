case $- in *i*) ;; *) return ;; esac

# Claude-palette prompt: coral user, muted separator, accent prompt char
PS1='\[\e[38;2;217;119;87m\]\u\[\e[38;2;110;114;144m\]@\h \[\e[38;2;230;225;216m\]\W\[\e[38;2;217;119;87m\] \$\[\e[0m\] '

alias ls='ls --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias vi='nvim'
alias vim='nvim'

export EDITOR=nvim
export VISUAL=nvim
export BROWSER=firefox
export TERM=xterm-256color