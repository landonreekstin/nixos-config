# Custom shell aliases for LKP guest environment.
# This file is installed automatically into /etc/profile.d/

alias dmesg='dmesg --decode --nopager --color --ctime'
alias jlog='journalctl -b --all --catalog --no-pager'
alias jlogr='journalctl -b --all --catalog --no-pager --reverse'
alias jlogall='journalctl --all --catalog --merge --no-pager'
alias jlogf='journalctl -f'
alias jlogk='journalctl -b -k --no-pager'

# Add any other aliases you want here...