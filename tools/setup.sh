#!/usr/bin/env bash
#
# Sets up this tools/ folder so scripts like tfclean can be run as a bare
# command (e.g. `tfclean plan`) from anywhere in bash/zsh.
#
# Adds this folder to PATH via your shell rc file (~/.bashrc and/or
# ~/.zshrc, whichever exist). Safe to re-run - it won't add a duplicate
# entry if already set up.
#
# Usage:
#   ./setup.sh

set -euo pipefail

tools_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
marker="# devops-cheatsheet tools"
line="export PATH=\"\$PATH:$tools_dir\""

chmod +x "$tools_dir/tfclean" "$tools_dir/tfclean.sh" 2>/dev/null || true

rc_files=()
[ -f "$HOME/.bashrc" ] && rc_files+=("$HOME/.bashrc")
[ -f "$HOME/.zshrc" ] && rc_files+=("$HOME/.zshrc")

if [ "${#rc_files[@]}" -eq 0 ]; then
    rc_files=("$HOME/.bashrc")
fi

for rc in "${rc_files[@]}"; do
    if [ -f "$rc" ] && grep -qF "$tools_dir" "$rc" 2>/dev/null; then
        echo "Already set up: '$tools_dir' is already referenced in $rc"
        continue
    fi
    {
        echo ""
        echo "$marker"
        echo "$line"
    } >> "$rc"
    echo "Added '$tools_dir' to PATH in $rc"
done

export PATH="$PATH:$tools_dir"

if [ "${BASH_SOURCE[0]:-$0}" != "$0" ]; then
    echo "It's active in this session now - try: tfclean plan"
else
    echo "Restart your shell (or run: source $rc) to use it here too."
    echo "Or run 'source ./setup.sh' instead of './setup.sh' to activate it in this session."
fi
