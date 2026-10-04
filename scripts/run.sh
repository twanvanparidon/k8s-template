#!/usr/bin/env bash
# Run a command inside a live output window.
# On success the window is cleared and a short message remains; on failure
# the full output is kept on screen so the error can be read.
#
# Usage: run.sh "<title>" <command> [args...]
# Env:   RUN_WINDOW_LINES  number of output lines shown while running (default 10)

set -uo pipefail

title=$1
shift

# Without a TTY (CI, nested in another window, piped) just run plainly.
if [[ ! -t 1 ]]; then
  echo "==> $title"
  "$@"
  exit $?
fi

window=${RUN_WINDOW_LINES:-10}
log=$(mktemp)
frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
drawn=0
pid=

clear_window() {
  if ((drawn > 0)); then
    printf '\033[%dA\033[J' "$drawn"
    drawn=0
  fi
}

cleanup() {
  tput cnorm 2>/dev/null
  rm -f "$log"
}
trap cleanup EXIT

on_interrupt() {
  [[ -n $pid ]] && kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  clear_window
  gum style --foreground 214 "⊘ $title cancelled after ${SECONDS}s"
  exit 130
}
trap on_interrupt INT TERM

render() {
  local frame=$1 cols width line out
  cols=$(tput cols 2>/dev/null || echo 80)
  width=$((cols - 4))

  out=$(printf '\033[38;5;212m%s\033[0m \033[1m%s\033[0m \033[2m(%ss)\033[0m\n' \
    "$frame" "$title" "$SECONDS")
  # Strip colors and carriage returns so line counts and widths stay accurate.
  while IFS= read -r line; do
    out+=$(printf '\n\033[2m  │ %s\033[0m' "${line:0:width}")
  done < <(tr '\r' '\n' <"$log" | sed $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g' | grep -v '^$' | tail -n "$window")

  clear_window
  printf '%s\n' "$out"
  drawn=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
}

SECONDS=0
tput civis 2>/dev/null
"$@" >"$log" 2>&1 &
pid=$!

i=0
while kill -0 "$pid" 2>/dev/null; do
  render "${frames[i++ % ${#frames[@]}]}"
  sleep 0.1
done
wait "$pid"
code=$?
clear_window

if ((code == 0)); then
  gum style --foreground 2 "✓ $title ($((SECONDS))s)"
else
  [[ -s $log ]] && gum style --border rounded --border-foreground 1 --padding "0 1" \
    --width "$(($(tput cols 2>/dev/null || echo 80) - 2))" \
    "$(sed $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g' "$log")"
  gum style --foreground 1 --bold "✗ $title failed with exit code $code (${SECONDS}s)"
fi
exit "$code"
