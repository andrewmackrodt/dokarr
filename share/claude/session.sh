#!/usr/bin/env bash
# session: cloud-style sessions. Each session gets a fresh clone in /sessions/<id>/<repo>.
set -euo pipefail

WORK="${WORK_ROOT:-/work}"
SESSIONS="${SESSIONS_ROOT:-/sessions}"

usage() {
  cat >&2 <<'USAGE'
usage:
  session new <repo> [ref] [id]   fresh clone into /sessions/<id>/<repo>, on branch agent/<id>; prints the path
                                  <repo> = owner/name | https://... URL | folder name under /work
                                  [ref]  = branch/tag/sha to start from (default: the repo's default branch)
  session ls                      list sessions (path, branch)
  session rm <id> [-f]            delete a session folder (refuses if dirty or unpushed unless -f)
USAGE
  exit 2
}

cmd="${1:-}"; shift || true

case "$cmd" in
  new)
    spec="${1:-}"; [ -n "$spec" ] || usage
    ref="${2:-}"
    id="${3:-$(date +%y%m%d-%H%M%S)-$(head -c2 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
    case "$id" in *[!A-Za-z0-9._-]*|"") echo "session: bad id '$id'" >&2; exit 1;; esac

    if [ -d "$WORK/$spec/.git" ]; then
      src="$WORK/$spec"; name="$spec"
      origin_url="$(git -C "$src" remote get-url origin 2>/dev/null || true)"
    elif [[ "$spec" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
      src="https://github.com/$spec.git"; name="${spec##*/}"; origin_url=""
    else
      src="$spec"; name="$(basename "${spec%.git}")"; origin_url=""
    fi

    dest="$SESSIONS/$id/$name"
    [ ! -e "$dest" ] || { echo "session: $dest already exists" >&2; exit 1; }
    mkdir -p "$SESSIONS/$id"
    git clone -q --no-hardlinks "$src" "$dest" >&2

    if [ -n "$origin_url" ]; then          # local source: point origin back at the real remote
      git -C "$dest" remote set-url origin "$origin_url"
      git -C "$dest" fetch -q origin >&2 || echo "session: warning: could not fetch origin" >&2
    fi

    if [ -n "$ref" ]; then
      if git -C "$dest" rev-parse -q --verify "origin/$ref" >/dev/null; then
        git -C "$dest" checkout -q --no-track -b "agent/$id" "origin/$ref" >&2
      else
        git -C "$dest" checkout -q -b "agent/$id" "$ref" >&2
      fi
    else
      git -C "$dest" checkout -q -b "agent/$id" >&2
    fi
    echo "$dest"
    ;;
  ls)
    [ -d "$SESSIONS" ] || exit 0
    for d in "$SESSIONS"/*/*/; do
      [ -e "${d}.git" ] || continue
      d="${d%/}"
      printf '%s\t%s\n' "$d" "$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    done
    ;;
  rm)
    id="${1:-}"; [ -n "$id" ] || usage
    case "$id" in */*|*..*) echo "session: bad id" >&2; exit 1;; esac
    force="${2:-}"
    for d in "$SESSIONS/$id"/*/; do
      [ -e "${d}.git" ] || continue
      d="${d%/}"
      if [ "$force" != "-f" ]; then
        if [ -n "$(git -C "$d" status --porcelain)" ]; then
          echo "session: $d has uncommitted changes (use -f to delete anyway)" >&2; exit 1
        fi
        if [ -z "$(git -C "$d" branch -r --contains HEAD 2>/dev/null)" ]; then
          echo "session: $d has commits not pushed to origin (use -f to delete anyway)" >&2; exit 1
        fi
      fi
    done
    rm -rf "${SESSIONS:?}/$id"
    ;;
  *)
    usage
    ;;
esac

