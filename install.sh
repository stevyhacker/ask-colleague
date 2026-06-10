#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
STATE_DIR="${COLLEAGUE_STATE_DIR:-$HOME/.ask-colleague}"
MANIFEST="$STATE_DIR/install-manifest.tsv"
INSTALL_BIN=0
INSTALL_CLAUDE=0
INSTALL_CODEX=0
INSTALL_AGENTS_MD=0
DRY_RUN=0
FORCE=0

AGENTS_BEGIN_MARK='<!-- BEGIN ask-colleague bridge -->'
AGENTS_END_MARK='<!-- END ask-colleague bridge -->'

usage() {
  cat <<'USAGE'
Usage: colleague install [--all] [--bin] [--claude] [--codex] [--prefix DIR] [--agents-md] [--force] [--dry-run]
       ./install.sh        [--all] [--bin] [--claude] [--codex] [--prefix DIR] [--agents-md] [--force] [--dry-run]

Default with no component flags is --all.

Installs:
  bin/colleague                         -> $PREFIX/bin/colleague
  bin/colleague                         -> $PREFIX/bin/ask-colleague
  skills/claude/colleague/SKILL.md      -> ~/.claude/skills/colleague/SKILL.md
  skills/codex/colleague/SKILL.md       -> ~/.agents/skills/colleague/SKILL.md
  skills/codex/.../agents/openai.yaml   -> ~/.agents/skills/colleague/agents/openai.yaml
  prompts/colleague.md                  -> ~/.codex/prompts/colleague.md  (legacy custom prompt)

Optional:
  --agents-md                           append snippets/AGENTS.md once to ~/.codex/AGENTS.md
                                         (opt-in because it affects all Codex sessions)

Safety:
  Existing files are overwritten only if they are tracked in the
  ~/.ask-colleague install manifest and have not been modified.
  Use --force to overwrite intentionally.

Set PREFIX=/some/path or pass --prefix DIR to choose the binary location.
USAGE
}

log() { printf '%s\n' "$*"; }
die() { printf 'install: %s\n' "$*" >&2; exit 1; }
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

manifest_file_matches() {
  local path="$1"
  [[ -f "$MANIFEST" && -f "$path" ]] || return 1
  local entry_type recorded_checksum recorded_path current_checksum
  current_checksum="$(checksum_file "$path" 2>/dev/null || true)"
  [[ -n "$current_checksum" ]] || return 1
  while IFS=$'\t' read -r entry_type recorded_checksum recorded_path; do
    if [[ "$entry_type" == "file" && "$recorded_path" == "$path" && "$recorded_checksum" == "$current_checksum" ]]; then
      return 0
    fi
  done < "$MANIFEST"
  return 1
}

manifest_record() {
  local entry_type="$1"
  local recorded_checksum="$2"
  local path="$3"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '+ record %q %q in %q\n' "$entry_type" "$path" "$MANIFEST"
    return 0
  fi

  mkdir -p "$STATE_DIR"
  local tmp
  tmp="$(mktemp)"
  if [[ -f "$MANIFEST" ]]; then
    awk -F '\t' -v path="$path" '$3 != path { print }' "$MANIFEST" > "$tmp"
  else
    : > "$tmp"
  fi
  printf '%s\t%s\t%s\n' "$entry_type" "$recorded_checksum" "$path" >> "$tmp"
  mv "$tmp" "$MANIFEST"
}

safe_copy_file() {
  local src="$1"
  local dst="$2"
  local mode="${3:-}"
  [[ -f "$src" ]] || die "missing packaged file: $src"

  if [[ -e "$dst" ]]; then
    [[ -f "$dst" ]] || die "refusing to overwrite non-file path: $dst"
    if [[ "$FORCE" != "1" ]] && ! manifest_file_matches "$dst"; then
      cat >&2 <<MSG
Refusing to overwrite existing file: $dst
It is not tracked as an unmodified ask-colleague install.
Re-run with --force if this file belongs to ask-colleague and should be replaced.
MSG
      exit 1
    fi
  fi

  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  if [[ -n "$mode" ]]; then
    run chmod "$mode" "$dst"
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    manifest_record file "dry-run" "$dst"
  else
    manifest_record file "$(checksum_file "$dst")" "$dst"
  fi
}

append_agents_block() {
  local agents="$HOME/.codex/AGENTS.md"
  local snippet="$ROOT_DIR/snippets/AGENTS.md"
  [[ -f "$snippet" ]] || die "missing packaged file: $snippet"

  if [[ -f "$agents" ]] && grep -qF "$AGENTS_BEGIN_MARK" "$agents"; then
    if ! grep -qF "$AGENTS_END_MARK" "$agents"; then
      die "$agents contains the ask-colleague begin marker but no end marker"
    fi
    log "Codex AGENTS.md already contains the colleague block"
    manifest_record agents_block present "$agents"
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    printf '+ append %q to %q\n' "$snippet" "$agents"
  else
    mkdir -p "$HOME/.codex"
    {
      if [[ -s "$agents" ]]; then printf '\n'; fi
      cat "$snippet"
    } >> "$agents"
  fi
  manifest_record agents_block present "$agents"
  log "Appended colleague block to ~/.codex/AGENTS.md"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      INSTALL_BIN=1; INSTALL_CLAUDE=1; INSTALL_CODEX=1; shift ;;
    --bin)
      INSTALL_BIN=1; shift ;;
    --claude)
      INSTALL_CLAUDE=1; shift ;;
    --codex)
      INSTALL_CODEX=1; shift ;;
    --prefix)
      PREFIX="$(need_value "$1" "${2-}")"; shift 2 ;;
    --agents-md)
      INSTALL_AGENTS_MD=1; shift ;;
    --no-agents-md)
      # Accepted for compatibility with older releases. It is now the default.
      INSTALL_AGENTS_MD=0; shift ;;
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

if [[ "$INSTALL_BIN$INSTALL_CLAUDE$INSTALL_CODEX" == "000" ]]; then
  INSTALL_BIN=1; INSTALL_CLAUDE=1; INSTALL_CODEX=1
fi

if [[ "$INSTALL_BIN" == "1" ]]; then
  safe_copy_file "$ROOT_DIR/bin/colleague" "$PREFIX/bin/colleague" "+x"
  safe_copy_file "$ROOT_DIR/bin/colleague" "$PREFIX/bin/ask-colleague" "+x"
  log "Installed colleague binary to $PREFIX/bin/colleague"
  log "Installed ask-colleague alias to $PREFIX/bin/ask-colleague"
fi

if [[ "$INSTALL_CLAUDE" == "1" ]]; then
  safe_copy_file "$ROOT_DIR/skills/claude/colleague/SKILL.md" "$HOME/.claude/skills/colleague/SKILL.md"
  log "Installed Claude Code skill to ~/.claude/skills/colleague/SKILL.md"
fi

if [[ "$INSTALL_CODEX" == "1" ]]; then
  safe_copy_file "$ROOT_DIR/skills/codex/colleague/SKILL.md" "$HOME/.agents/skills/colleague/SKILL.md"
  safe_copy_file "$ROOT_DIR/skills/codex/colleague/agents/openai.yaml" "$HOME/.agents/skills/colleague/agents/openai.yaml"
  log "Installed Codex skill to ~/.agents/skills/colleague/SKILL.md"

  # Older Codex versions may still support custom prompts. Keep this as a
  # compatibility fallback, but prefer the skill on versions that support skills.
  safe_copy_file "$ROOT_DIR/prompts/colleague.md" "$HOME/.codex/prompts/colleague.md"
  log "Installed legacy Codex custom prompt to ~/.codex/prompts/colleague.md"

  if [[ "$INSTALL_AGENTS_MD" == "1" ]]; then
    append_agents_block
  else
    log "Skipped ~/.codex/AGENTS.md fallback block. Pass --agents-md to opt in."
  fi
fi

cat <<NEXT_STEPS

Next steps:
1. Ensure $PREFIX/bin is in your PATH.
2. Run: colleague doctor
3. In Claude Code, invoke: /colleague ask Codex to critique this plan
4. In Codex, invoke: \$colleague ask Claude to critique my current plan
   Legacy custom prompt fallback: /prompts:colleague should I use a queue or cron here?

For one-command public installs after publishing to npm:
  npx ask-colleague@latest install

Optional global Codex AGENTS.md fallback:
  npx ask-colleague@latest install --agents-md
NEXT_STEPS
