#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 2 ]]; then
  echo 'Usage: ask-codex.sh <context_file> "question"' >&2
  exit 2
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
exec "$ROOT_DIR/bin/colleague" ask codex --context "$1" --question "$2" "${@:3}"
