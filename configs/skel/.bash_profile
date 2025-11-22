# .bash_profile

# Get the aliases and functions
[[ -f ~/.bashrc ]] && source ~/.bashrc

# Load Xresources when applicable
if [[ -n $DISPLAY && -f ~/.Xresources ]]; then
    xrdb -merge ~/.Xresources 2>/dev/null
fi
