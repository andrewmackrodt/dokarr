#!/usr/bin/env bash
# Container entrypoint for the Claude Code Remote Control host.
# Self-contained: needs nothing from the home volume besides claude login state.
#
# Runs twice: first as root (under tini, from the Dockerfile ENTRYPOINT) to do the
# root-only setup, then re-executes itself as the dev user for everything else.
#   root phase : clear a stale docker.pid, start the inner dockerd, seed CLAUDE.md
#   dev phase  : git/gh config, revive REPL-origin Remote Control sessions, host loop
#
# Manual use:  bash -l entrypoint.sh autoresume [--dry-run]   (resume step only)
#
# Env: RC_DIR RC_NAME RC_SPAWN RC_CAPACITY RC_PERMISSION_MODE  (host, as before)
#      RC_AUTORESUME=0  skip the resume step
#      RC_DOCKER=0      do not start the inner Docker daemon
#      RC_DOCKER_WAIT   seconds to wait for dockerd before continuing (default 60)
#      RC_CLAUDE_MD_OVERWRITE=1  replace ~/.claude/CLAUDE.md from the image on every boot
#                       (default: only seed it when missing)
#      RC_DOCKERD_LOG   dockerd log file (default /var/log/dockerd.log)
#      RC_LOG           file for the host TUI output (default /var/log/claude-rc.log)
set -u

RC_USER="${RC_USER:-dev}"
RC_HOME="${RC_HOME:-/home/$RC_USER}"

if [ "$(id -u)" = 0 ]; then
  # Root here is NOT host root: Sysbox runs this container in a user namespace.

  # Inner Docker daemon. Sysbox makes it possible to run dockerd here, but nothing
  # starts it for us. The container filesystem survives a restart, so a pid file
  # left by the previous boot blocks dockerd ("process with PID N is still running")
  # when that PID happens to belong to some other process now. Clear it first.
  if [ "${RC_DOCKER:-1}" = 1 ] && command -v dockerd >/dev/null 2>&1; then
    rm -f /run/docker.pid
    echo "Starting inner dockerd..."
    dockerd >"${RC_DOCKERD_LOG:-/var/log/dockerd.log}" 2>&1 &
    for _ in $(seq 1 "${RC_DOCKER_WAIT:-60}"); do
      docker info >/dev/null 2>&1 && break
      sleep 1
    done
    if docker info >/dev/null 2>&1; then
      echo "inner dockerd is up"
    else
      echo "WARNING: inner dockerd did not start; continuing without Docker. Last log lines:"
      tail -n 20 "${RC_DOCKERD_LOG:-/var/log/dockerd.log}"
    fi
  fi

  # Seed the workspace CLAUDE.md into the home volume when it is missing. With
  # RC_CLAUDE_MD_OVERWRITE=1 the image copy replaces the home copy on every boot.
  if [ -f /etc/claude-workspace/CLAUDE.md ]; then
    if [ ! -e "$RC_HOME/.claude/CLAUDE.md" ] || [ "${RC_CLAUDE_MD_OVERWRITE:-0}" = 1 ]; then
      install -d -o "$RC_USER" -g "$RC_USER" "$RC_HOME/.claude"
      install -o "$RC_USER" -g "$RC_USER" -m 644 /etc/claude-workspace/CLAUDE.md "$RC_HOME/.claude/CLAUDE.md"
    fi
  fi

  # Bypass mode otherwise asks for a one-time confirmation that nobody can answer here.
  if [ "${RC_PERMISSION_MODE:-acceptEdits}" = "bypassPermissions" ] && [ ! -f "$RC_HOME/.claude/settings.json" ]; then
    install -d -o "$RC_USER" -g "$RC_USER" "$RC_HOME/.claude"
    printf '{\n  "skipDangerousModePermissionPrompt": true\n}\n' > "$RC_HOME/.claude/settings.json"
    chown "$RC_USER:$RC_USER" "$RC_HOME/.claude/settings.json"
  fi

  # Log file for the host TUI (written by the dev phase, see RC_LOG below).
  touch "${RC_LOG:-/var/log/claude-rc.log}" && chown "$RC_USER:$RC_USER" "${RC_LOG:-/var/log/claude-rc.log}"

  # Drop privileges and run the dev phase of this same script.
  # Before your first `claude auth login`, the host loop just retries every 30s.
  exec runuser -u "$RC_USER" -- env HOME="$RC_HOME" bash -l "$0" "$@"
fi

# Git identity + GitHub credentials, shared by every session (state lives in the home volume).
[ -n "${GIT_USER_NAME:-}" ]  && git config --global user.name  "$GIT_USER_NAME"
[ -n "${GIT_USER_EMAIL:-}" ] && git config --global user.email "$GIT_USER_EMAIL"
[ -z "${GH_TOKEN:-}" ] && unset GH_TOKEN
git config --global --replace-all credential.https://github.com.helper ""
git config --global --add credential.https://github.com.helper "!gh auth git-credential"

cd "${RC_DIR:-/sessions}"

# Revive Remote Control sessions that were started with /remote-control from a REPL.
# The host loop below only respawns sessions it created itself. REPL-origin sessions
# must be resumed from their local transcript, which reattaches to the same claude.ai
# session because the transcript carries a "bridge-session" record with its ID.
# Host-spawned transcripts never carry that record, so they are left to the host.
# Idempotent: skips sessions with a live process. No --model, so each conversation
# keeps its own model. No-op on a fresh volume with no transcripts.
rc_autoresume() {
  local dry=0; [ "${1:-}" = "--dry-run" ] && dry=1
  local cdir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" log t id bridge dir f pid live
  log="$cdir/rc-autoresume.log"
  [ -d "$cdir/projects" ] || return 0
  for t in "$cdir"/projects/*/*.jsonl; do
    [ -f "$t" ] || continue
    grep -q '"type":"bridge-session"' "$t" 2>/dev/null || continue
    id=$(basename "$t" .jsonl)
    bridge=$(grep -o '"bridgeSessionId":"[^"]*"' "$t" | tail -1 | cut -d'"' -f4)
    dir=$(grep -m1 -o '"cwd":"[^"]*"' "$t" | cut -d'"' -f4)
    [ -d "${dir:-/nonexistent}" ] || dir="${RC_DIR:-/sessions}"
    live=0
    for f in "$cdir"/sessions/*.json; do
      [ -f "$f" ] && grep -q "\"sessionId\":\"$id\"" "$f" || continue
      pid=$(sed -n 's/.*"pid":\([0-9]*\).*/\1/p' "$f")
      [ -n "$pid" ] && [ -d "/proc/$pid" ] && { live=1; break; }
    done
    if [ "$live" = 1 ]; then
      printf '[%s] skip %s (%s): already running\n' "$(date -u +%FT%TZ)" "$id" "$bridge" | tee -a "$log"; continue
    fi
    if [ "$dry" = 1 ]; then
      printf '[%s] would resume %s (%s) in %s\n' "$(date -u +%FT%TZ)" "$id" "$bridge" "$dir" | tee -a "$log"; continue
    fi
    printf '[%s] resuming %s (%s) in %s\n' "$(date -u +%FT%TZ)" "$id" "$bridge" "$dir" | tee -a "$log"
    ( cd "$dir" && claude --bg --resume "$id" --remote-control \
        --permission-mode "${RC_PERMISSION_MODE:-acceptEdits}" 2>&1 | tr -d '\033' | head -1 | tee -a "$log" )
  done
}

if [ "${1:-}" = "autoresume" ]; then
  rc_autoresume "${2:-}"; exit $?
fi

export RC_AUTORESUME_DONE=1   # tells an older ~/.profile hook, if present, not to repeat this
[ "${RC_AUTORESUME:-1}" = 1 ] && rc_autoresume

# The host draws a full-screen TUI. Run it on its own pseudo-terminal (script) and
# keep that output in a file, so the container log (docker compose logs) only gets
# plain one-line status messages instead of clear-screen escape codes.
RC_LOG="${RC_LOG:-/var/log/claude-rc.log}"
[ -w "$RC_LOG" ] || [ -w "$(dirname "$RC_LOG")" ] || RC_LOG="$HOME/.claude/claude-rc.log"
export TERM="${TERM:-xterm-256color}"
while true; do
  echo "starting claude remote-control (name=${RC_NAME:-claude-dev}, spawn=${RC_SPAWN:-same-dir}); TUI output: $RC_LOG"
  # There is no consent flag, so answer the "Enable Remote Control? (y/n)" prompt via stdin.
  # The log is truncated on each (re)start so it cannot grow without bound.
  script -q -e -f -c "printf 'y\\n' | claude remote-control --name '${RC_NAME:-claude-dev}' \
      --spawn '${RC_SPAWN:-same-dir}' --capacity '${RC_CAPACITY:-8}' \
      --permission-mode '${RC_PERMISSION_MODE:-acceptEdits}'" "$RC_LOG" >/dev/null 2>&1
  echo "claude remote-control exited (rc=$?); last lines:"
  tail -n 5 "$RC_LOG" | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/\x1b\][^\x07]*\x07//g; s/\r//g' | grep -v '^[[:space:]]*$' | tail -n 3
  echo "retrying in 30s"
  sleep 30
done
