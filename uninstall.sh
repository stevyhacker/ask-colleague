#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
STATE_DIR="${COLLEAGUE_STATE_DIR:-$HOME/.agent-colleague}"
MANIFEST="$STATE_DIR/install-manifest.tsv"
DRY_RUN=0
FORCE=0

AGENTS_BEGIN_MARK='<!-- BEGIN agent-colleague bridge -->'
AGENTS_END_MARK='<!-- END agent-colleague bridge -->'

usage() {
  cat <<'USAGE'
Usage: colleague uninstall [--prefix DIR] [--force] [--dry-run]
       ./uninstall.sh      [--prefix DIR] [--force] [--dry-run]

By default, uninstall reads ~/.agent-colleague/install-manifest.tsv and removes
only files that this package installed and that have not been modified.

Use --force only for legacy installs without a manifest or to remove modified
agent-colleague files intentionally.
USAGE
}

die() { printf 'uninstall: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

need_value() {
  local opt="$1"
  local val="${2-}"
  if [[ -z "$val" || "$val" == --* ]]; then
    die "$opt requires a value"
  fi
  printf '%s\n' "$val"
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '+ %q' "$1"
    shift
    local arg
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

checksum_file() {
  local file="$1"
  if have sha256sum; then
    sha256sum "$file" | awk '{print $1}'
  elif have shasum; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    cksum "$file" | awk '{print $1 "-" $2}'
  fi
}

strip_agents_block() {
  local agents="$HOME/.codex/AGENTS.md"
  [[ -f "$agents" ]] || return 0
  grep -qF "$AGENTS_BEGIN_MARK" "$agents" || return 0

  local tmp
  tmp="$(mktemp)"
  if ! awk -v begin="$AGENTS_BEGIN_MARK" -v end="$AGENTS_END_MARK" '
    index($0, begin) { skipping = 1; next }
    skipping && index($0, end) { skipping = 0; next }
    !skipping { print }
    END { if (skipping) exit 2 }
  ' "$agents" > "$tmp"; then
    rm -f "$tmp"
    printf 'Refusing to strip incomplete agent-colleague block from %s: missing end marker.\n' "$agents" >&2
    return 1
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    rm -f "$tmp"
    printf '+ strip colleague block from %q\n' "$agents"
    return 0
  fi

  mv "$tmp" "$agents"
}

legacy_force_uninstall() {
  run rm -f "$PREFIX/bin/colleague" "$PREFIX/bin/agent-colleague"
  run rm -f "$HOME/.claude/skills/colleague/SKILL.md"
  run rm -f "$HOME/.agents/skills/colleague/SKILL.md" "$HOME/.agents/skills/colleague/agents/openai.yaml"
  run rmdir "$HOME/.agents/skills/colleague/agents" 2>/dev/null || true
  run rmdir "$HOME/.agents/skills/colleague" 2>/dev/null || true
  run rmdir "$HOME/.claude/skills/colleague" 2>/dev/null || true
  run rm -f "$HOME/.codex/prompts/colleague.md"
  strip_agents_block
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="$(need_value "$1" "${2-}")"; shift 2 ;;
    --force)
      FORCE=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$PREFIX" ]] || die "--prefix cannot be empty"

if [[ ! -f "$MANIFEST" ]]; then
  if [[ "$FORCE" == "1" ]]; then
    printf 'No install manifest found; performing legacy forced uninstall.\n' >&2
    legacy_force_uninstall
    exit 0
  fi
  printf 'No install manifest found at %s.\n' "$MANIFEST" >&2
  printf 'Refusing to remove unknown files. Re-run with --force for a legacy uninstall.\n' >&2
  exit 1
fi

failures=0
while IFS=$'\t' read -r entry_type recorded_checksum path; do
  [[ -n "${entry_type:-}" ]] || continue
  case "$entry_type" in
    file)
      [[ -e "$path" ]] || continue
      if [[ "$FORCE" != "1" ]]; then
        current_checksum="$(checksum_file "$path" 2>/dev/null || true)"
        if [[ -z "$current_checksum" || "$current_checksum" != "$recorded_checksum" ]]; then
          printf 'Leaving modified file in place: %s (use --force to remove)\n' "$path" >&2
          failures=1
          continue
        fi
      fi
      run rm -f "$path"
      ;;
    agents_block)
      if ! strip_agents_block; then
        failures=1
      fi
      ;;
  esac
done < "$MANIFEST"

run rmdir "$HOME/.agents/skills/colleague/agents" 2>/dev/null || true
run rmdir "$HOME/.agents/skills/colleague" 2>/dev/null || true
run rmdir "$HOME/.claude/skills/colleague" 2>/dev/null || true
run rmdir "$HOME/.codex/prompts" 2>/dev/null || true

if [[ "$failures" == "0" ]]; then
  run rm -f "$MANIFEST"
  run rmdir "$STATE_DIR" 2>/dev/null || true
  echo "Removed files tracked by the agent-colleague install manifest."
else
  echo "Uninstall incomplete because one or more tracked files were modified or could not be safely removed." >&2
  exit 1
fi
