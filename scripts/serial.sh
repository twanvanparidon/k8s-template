#!/usr/bin/env bash
# Run a command, first waiting until no other run with the same name is active.
# Task's watch mode interrupts and then kills its command shortly after
# starting it, so the waiting and the command run as a background job: those
# ignore interrupts and outlive this wrapper. The result is that every change
# gets synced, one run at a time, and the output never overlaps.
#
# Usage: serial.sh <name> <command> [args...]

set -uo pipefail

name=$1
shift

# Kept outside the repo, anything inside it would end up in the pushed artifact.
repo="$(cd "$(dirname "$0")/.." && pwd)"
lock="${TMPDIR:-/tmp}/$name-$(printf '%s' "$repo" | cksum | cut -d' ' -f1).lock"

run() {
  # The lock is held by the pid in it, so it frees itself when the job exits.
  until mkdir "$lock" 2>/dev/null; do
    owner=$(cat "$lock/pid" 2>/dev/null)
    if [[ -n $owner ]] && ! kill -0 "$owner" 2>/dev/null; then
      rm -rf "$lock"
    fi
    sleep 0.2
  done
  echo "$BASHPID" >"$lock/pid"
  "$@"
  local code=$?
  rm -rf "$lock"
  return "$code"
}

run "$@" &
wait $!
