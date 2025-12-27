#!/usr/bin/env bash

# -----------------------------------------------------------------------------
##? FZF Configuration
#?? 1.0.0
##?
##? Require:
##?   fzf
##? Usage:
##?   source 05-fzf.sh
#docs::eval "$@"
# -----------------------------------------------------------------------------

# Setup fzf
# ---------
if [[ ! "$PATH" == *~/.fzf/bin* ]]; then
  export PATH="${PATH:+${PATH}:}~/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "~/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "~/.fzf/shell/key-bindings.zsh"