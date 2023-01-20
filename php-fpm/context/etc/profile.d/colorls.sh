# color-ls initialization

# Skip all for noninteractive shells.
[ ! -t 0 ] && return

alias ll='ls -l --color=auto' 2>/dev/null
alias l.='ls -d .* --color=auto' 2>/dev/null
alias ls='ls --color=auto' 2>/dev/null
