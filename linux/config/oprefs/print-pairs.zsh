#!/usr/bin/env zsh
# Print "key\0value\0" pairs for the named variables, for use by
# linux/config/zsh/secrets.zsh when importing secrets from `op run` without
# eval: NUL-delimited pairs survive values containing spaces, quotes, or
# newlines.
#
# Invoked as a subprocess of `op run`, so the variables are already exported
# into it; ${(P)k} fetches each value by name.

for k in "$@"; do
  print -rn -- "$k"
  print -rn -- $'\0'
  print -rn -- "${(P)k}"
  print -rn -- $'\0'
done