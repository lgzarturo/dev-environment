#!/usr/bin/env zsh

# Navigation

alias ..="cd .."

alias ...="cd ../.."

alias ....="cd ../../.."

alias .....="cd ../../../.."

alias ~="cd ~"

alias -- -="cd -"

# Kubernetes

alias k=kubectl

# List files alias

alias la="ls -lAF ${colorflag}"

alias l="ls -CF ${colorflag}"

alias lh="ls -lh ${colorflag}"

alias lsdir="ls -thord */ ${colorflag}"

alias lss="ls -thor ${colorflag}"

alias lsd="ls -lF ${colorflag} | grep --color=never '^d'"

# System alias

alias cwd="basename \"$(pwd)\""

alias paux='ps aux | grep'

# Get week number

alias week='date +%V'

# ZSH Aliases

alias bp='code ~/.zshrc'

alias sa='source ~/.zshrc; echo "🚀 ZSH configuration sourced."'
