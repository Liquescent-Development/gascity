#!/usr/bin/env bash
# Shared step engine for the interactive Gas City tutorials.
# Sourced by 01-your-first-fleet.sh and 02-superpowers-factory.sh.

set -euo pipefail

BOLD=$'\033[1m'
DIM=$'\033[2m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RESET=$'\033[0m'

# heading "title" — start a numbered tutorial section.
heading() {
  printf '\n%s%s══ %s ══%s\n\n' "$BOLD" "$CYAN" "$1" "$RESET"
}

# say "text..." — narration, one paragraph per call.
say() {
  printf '%s\n\n' "$*" | fold -s -w 78
}

# pause — wait for Enter before continuing.
pause() {
  read -rp "${DIM}[Enter to continue]${RESET} " _ </dev/tty
}

# run "command" — show a command, then Enter=run / s=skip / q=quit.
# The command runs in the caller's shell state (cd persists via subshell? no:
# we eval in-process so `cd` sticks for later steps).
run() {
  local cmd="$1"
  printf '%s$ %s%s\n' "$GREEN" "$cmd" "$RESET"
  local answer
  read -rp "${DIM}[Enter=run  s=skip  q=quit]${RESET} " answer </dev/tty
  case "$answer" in
    q) echo "Leaving the tutorial. Re-run this script to pick up where you left off."; exit 0 ;;
    s) echo "${YELLOW}skipped${RESET}"; return 0 ;;
  esac
  if ! eval "$cmd"; then
    local status=$?
    printf '%scommand failed (exit %s)%s\n' "$YELLOW" "$status" "$RESET"
    read -rp "${DIM}[Enter=continue the tutorial anyway  q=quit]${RESET} " answer </dev/tty
    [ "$answer" = "q" ] && exit 1
  fi
  return 0
}

# watch "command" — run a blocking observer (--watch/--follow/attach).
# Ctrl-C stops the observer and returns to the tutorial instead of killing it.
watch() {
  local cmd="$1"
  printf '%s$ %s%s\n' "$GREEN" "$cmd" "$RESET"
  local answer
  read -rp "${DIM}[Enter=run (Ctrl-C returns to the tutorial)  s=skip]${RESET} " answer </dev/tty
  [ "$answer" = "s" ] && { echo "${YELLOW}skipped${RESET}"; return 0; }
  trap ':' INT
  bash -c "$cmd" || true
  trap - INT
  echo
}

# write_file <path> — heredoc body on stdin; shows the content, confirms, writes.
write_file() {
  local path="$1"
  local content
  content="$(cat)"
  printf '%sWriting %s:%s\n' "$BOLD" "$path" "$RESET"
  printf '%s\n' "$content" | sed 's/^/    /'
  local answer
  read -rp "${DIM}[Enter=write  s=skip]${RESET} " answer </dev/tty
  [ "$answer" = "s" ] && { echo "${YELLOW}skipped${RESET}"; return 0; }
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path"
  echo "${GREEN}wrote $path${RESET}"
}

# ask_value "prompt" VAR_NAME — read a value (e.g. a bead ID) from the user.
ask_value() {
  local prompt="$1" var="$2" value=""
  while [ -z "$value" ]; do
    read -rp "${BOLD}${prompt}${RESET} " value </dev/tty
  done
  printf -v "$var" '%s' "$value"
}

# require_bin name... — fail fast if a required binary is missing.
require_bin() {
  local missing=0 b
  for b in "$@"; do
    if ! command -v "$b" >/dev/null 2>&1; then
      echo "Missing required binary: $b" >&2
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || exit 1
}
