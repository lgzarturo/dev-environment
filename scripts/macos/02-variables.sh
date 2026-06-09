#!/usr/bin/env zsh

export EDITOR='code -w --new-window'

# Enable persistent REPL history for `node`.
export NODE_REPL_HISTORY=~/.node_history

# Allow 32³ entries; the default is 1000.
export NODE_REPL_HISTORY_SIZE='32768'

# Use sloppy mode by default, matching web browsers.
export NODE_REPL_MODE='sloppy'

# Make Python use UTF-8 encoding for output to stdin, stdout, and stderr.
export PYTHONIOENCODING='UTF-8'

# Increase Bash history size. Allow 32³ entries; the default is 500.
export HISTSIZE='32768'

export HISTFILESIZE="${HISTSIZE}"

# Omit duplicates and commands that begin with a space from history.
export HISTCONTROL='ignoreboth'

# Highlight section titles in manual pages.
export LESS_TERMCAP_md="${yellow}"

# Hide the “default interactive shell is now zsh” warning on macOS.
export BASH_SILENCE_DEPRECATION_WARNING=1

# SSH Copy ID
export PATH="/opt/homebrew/opt/ssh-copy-id/bin:$PATH"

# Environment Revenatium
export RUNTIME_HOME="$HOME/.runtime"

export REVENATIUM_HOME="${RUNTIME_HOME}/environment"

export PATH="${REVENATIUM_HOME}:${PATH}"

# Krew

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Python

export LC_ALL=en_US.UTF-8

export LANG=en_US.UTF-8

export PYTHON=$(pyenv which python)

export PIP=$(pyenv which pip)

if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi