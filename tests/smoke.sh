#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT_DIR/bin/colleague"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected output to contain: $needle" >&2
    echo "actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "expected output not to contain: $needle" >&2
    echo "actual output:" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_fails() {
  if "$@" >"$TMP_DIR/assert-fails.out" 2>"$TMP_DIR/assert-fails.err"; then
    echo "expected command to fail: $*" >&2
    cat "$TMP_DIR/assert-fails.out" >&2 || true
    cat "$TMP_DIR/assert-fails.err" >&2 || true
    exit 1
  fi
}

bash -n "$BIN" "$ROOT_DIR/install.sh" "$ROOT_DIR/uninstall.sh" \
  "$ROOT_DIR/scripts/ask-codex.sh" "$ROOT_DIR/scripts/ask-claude.sh"

help_out="$($BIN --help)"
assert_contains "$help_out" "colleague ask [codex|claude]"
assert_contains "$help_out" "--agents-md"
assert_contains "$help_out" "--force"

version_out="$($BIN --version)"
assert_contains "$version_out" "0.4.1"

# The npm bin launcher must delegate to the Bash CLI with identical behavior.
if command -v node >/dev/null 2>&1; then
  node --check "$ROOT_DIR/bin/colleague.js"
  launcher_out="$(node "$ROOT_DIR/bin/colleague.js" --version)"
  assert_contains "$launcher_out" "0.4.1"
  launcher_status=0
  node "$ROOT_DIR/bin/colleague.js" ask codex --context /nonexistent --question "x" --dry-run >/dev/null 2>&1 || launcher_status=$?
  if [[ "$launcher_status" -eq 0 ]]; then
    echo "expected launcher to propagate nonzero exit status" >&2
    exit 1
  fi
fi

ctx="$TMP_DIR/context.md"
make_out="$($BIN make-context --output "$ctx")"
[[ "$make_out" == "$ctx" ]]
[[ -s "$ctx" ]]

prompt_out="$($BIN ask codex --context "$ctx" --question "Review this" --dry-run)"
assert_contains "$prompt_out" "<session_context>"
assert_contains "$prompt_out" "Review this"
assert_contains "$prompt_out" "Do not consult another AI agent"
assert_contains "$prompt_out" "## Key recommendation"

prompt_default_peer="$(COLLEAGUE_DEFAULT_PEER=codex $BIN ask --context "$ctx" --question "Default peer" --dry-run)"
assert_contains "$prompt_default_peer" "Peer being invoked: codex"
assert_contains "$prompt_default_peer" "Default peer"

prompt_out_claude="$($BIN ask claude --context "$ctx" --question "Find flaws" --dry-run)"
assert_contains "$prompt_out_claude" "Peer being invoked: claude"
assert_contains "$prompt_out_claude" "Find flaws"

install_dry_run="$($BIN install --dry-run --prefix "$TMP_DIR/prefix")"
assert_contains "$install_dry_run" "Installed colleague binary"
assert_contains "$install_dry_run" "Installed Claude Code skill"
assert_contains "$install_dry_run" "Installed legacy Codex custom prompt"
assert_contains "$install_dry_run" "Skipped ~/.codex/AGENTS.md fallback block"
assert_not_contains "$install_dry_run" "Appended colleague block"
assert_contains "$install_dry_run" "npx ask-colleague@latest install"

install_agents_dry_run="$($BIN install --dry-run --codex --agents-md --prefix "$TMP_DIR/prefix")"
assert_contains "$install_agents_dry_run" "append"
assert_contains "$install_agents_dry_run" "AGENTS.md"

uninstall_dry_run_no_manifest="$(HOME="$TMP_DIR/no-manifest-home" PREFIX="$TMP_DIR/no-manifest-prefix" $BIN uninstall --dry-run --force 2>&1)"
assert_contains "$uninstall_dry_run_no_manifest" "legacy forced uninstall"
assert_contains "$uninstall_dry_run_no_manifest" "rm"

assert_fails "$BIN" ask codex --context "$ctx" --question "x" --sandbox nope --dry-run
assert_fails "$BIN" ask codex --context "$ctx" --question "x" --timeout nope --dry-run
assert_fails "$BIN" ask codex --context "$ctx" --question "x" --max-bytes nope --dry-run
assert_fails "$BIN" ask codex --context --question "missing value" --dry-run
assert_fails "$BIN" ask --context "$ctx" --question "no default peer" --dry-run

large_ctx="$TMP_DIR/large.md"
printf 'abcdef\n' > "$large_ctx"
assert_fails "$BIN" ask codex --context "$large_ctx" --question "x" --max-bytes 1 --dry-run

# Real install/uninstall into isolated HOME and PREFIX. This exercises the
# manifest-backed fallback uninstall in the copied ~/.local/bin/colleague.
real_home="$TMP_DIR/real-home"
real_prefix="$TMP_DIR/real-prefix"
mkdir -p "$real_home"
real_install_out="$(HOME="$real_home" PREFIX="$real_prefix" $BIN install)"
assert_contains "$real_install_out" "Installed colleague binary"
[[ -x "$real_prefix/bin/colleague" ]]
[[ -x "$real_prefix/bin/ask-colleague" ]]
[[ -f "$real_home/.claude/skills/colleague/SKILL.md" ]]
[[ -f "$real_home/.agents/skills/colleague/SKILL.md" ]]
[[ -f "$real_home/.agents/skills/colleague/agents/openai.yaml" ]]
[[ -f "$real_home/.codex/prompts/colleague.md" ]]
[[ -f "$real_home/.ask-colleague/install-manifest.tsv" ]]
[[ ! -f "$real_home/.codex/AGENTS.md" ]]

doctor_out="$(HOME="$real_home" PATH="$real_prefix/bin:$PATH" "$real_prefix/bin/colleague" doctor)"
assert_contains "$doctor_out" "manifest: installed"
assert_contains "$doctor_out" "Claude skill: installed"
assert_contains "$doctor_out" "Codex AGENTS.md block: absent"

uninstall_out="$(HOME="$real_home" PATH="$real_prefix/bin:$PATH" "$real_prefix/bin/colleague" uninstall)"
assert_contains "$uninstall_out" "Removed files tracked"
[[ ! -e "$real_prefix/bin/colleague" ]]
[[ ! -e "$real_prefix/bin/ask-colleague" ]]
[[ ! -e "$real_home/.claude/skills/colleague/SKILL.md" ]]
[[ ! -e "$real_home/.agents/skills/colleague/SKILL.md" ]]
[[ ! -e "$real_home/.codex/prompts/colleague.md" ]]
[[ ! -e "$real_home/.ask-colleague/install-manifest.tsv" ]]

# Opt-in AGENTS.md install records and removes the marker block.
agents_home="$TMP_DIR/agents-home"
agents_prefix="$TMP_DIR/agents-prefix"
mkdir -p "$agents_home"
HOME="$agents_home" PREFIX="$agents_prefix" $BIN install --agents-md >/dev/null
[[ -f "$agents_home/.codex/AGENTS.md" ]]
grep -q "BEGIN ask-colleague bridge" "$agents_home/.codex/AGENTS.md"
HOME="$agents_home" PATH="$agents_prefix/bin:$PATH" "$agents_prefix/bin/colleague" uninstall >/dev/null
if [[ -f "$agents_home/.codex/AGENTS.md" ]] && grep -q "BEGIN ask-colleague bridge" "$agents_home/.codex/AGENTS.md"; then
  echo "expected uninstall to remove AGENTS.md block" >&2
  exit 1
fi

# A malformed AGENTS.md marker must not cause uninstall to delete user content
# after the begin marker.
broken_agents_home="$TMP_DIR/broken-agents-home"
mkdir -p "$broken_agents_home/.codex" "$broken_agents_home/.ask-colleague"
cat > "$broken_agents_home/.codex/AGENTS.md" <<'BROKEN_AGENTS'
user content before
<!-- BEGIN ask-colleague bridge -->
partial colleague block
user content after malformed block
BROKEN_AGENTS
printf 'agents_block\tpresent\t%s\n' "$broken_agents_home/.codex/AGENTS.md" > "$broken_agents_home/.ask-colleague/install-manifest.tsv"
assert_fails env HOME="$broken_agents_home" PREFIX="$TMP_DIR/broken-agents-prefix" "$BIN" uninstall
grep -q "user content after malformed block" "$broken_agents_home/.codex/AGENTS.md"
[[ -f "$broken_agents_home/.ask-colleague/install-manifest.tsv" ]]

# Overwrite protection.
protect_home="$TMP_DIR/protect-home"
protect_prefix="$TMP_DIR/protect-prefix"
mkdir -p "$protect_home" "$protect_prefix/bin"
printf 'user owned\n' > "$protect_prefix/bin/colleague"
assert_fails env HOME="$protect_home" PREFIX="$protect_prefix" "$BIN" install --bin
force_out="$(HOME="$protect_home" PREFIX="$protect_prefix" $BIN install --bin --force)"
assert_contains "$force_out" "Installed colleague binary"

# Mock peer CLIs to verify argv and stdin plumbing without requiring auth.
mock_bin="$TMP_DIR/mock-bin"
mock_capture="$TMP_DIR/mock-capture"
mkdir -p "$mock_bin" "$mock_capture"
cat > "$mock_bin/codex" <<'MOCK_CODEX'
#!/usr/bin/env bash
: "${MOCK_CAPTURE:?}"
for arg in "$@"; do printf '[%s]\n' "$arg"; done > "$MOCK_CAPTURE/codex.args"
cat > "$MOCK_CAPTURE/codex.prompt"
printf 'CODEX_OK\n'
MOCK_CODEX
cat > "$mock_bin/claude" <<'MOCK_CLAUDE'
#!/usr/bin/env bash
: "${MOCK_CAPTURE:?}"
for arg in "$@"; do printf '[%s]\n' "$arg"; done > "$MOCK_CAPTURE/claude.args"
cat > "$MOCK_CAPTURE/claude.prompt"
printf 'CLAUDE_OK\n'
MOCK_CLAUDE
chmod +x "$mock_bin/codex" "$mock_bin/claude"

codex_mock_out="$(MOCK_CAPTURE="$mock_capture" PATH="$mock_bin:$PATH" $BIN ask codex --context "$ctx" --question "mock codex")"
assert_contains "$codex_mock_out" "CODEX_OK"
assert_contains "$(cat "$mock_capture/codex.args")" "[exec]"
assert_contains "$(cat "$mock_capture/codex.args")" "[--ephemeral]"
assert_not_contains "$(cat "$mock_capture/codex.args")" "[--ask-for-approval]"
assert_contains "$(cat "$mock_capture/codex.args")" "[--sandbox]"
assert_contains "$(cat "$mock_capture/codex.args")" "[read-only]"
assert_contains "$(cat "$mock_capture/codex.args")" "[-]"
assert_contains "$(cat "$mock_capture/codex.prompt")" "mock codex"

claude_mock_out="$(MOCK_CAPTURE="$mock_capture" PATH="$mock_bin:$PATH" $BIN ask claude --context "$ctx" --question "mock claude")"
assert_contains "$claude_mock_out" "CLAUDE_OK"
assert_contains "$(cat "$mock_capture/claude.args")" "[--bare]"
assert_contains "$(cat "$mock_capture/claude.args")" "[--tools]"
assert_contains "$(cat "$mock_capture/claude.args")" "[]"
assert_contains "$(cat "$mock_capture/claude.args")" "[--]"
assert_contains "$(cat "$mock_capture/claude.args")" "[--max-turns]"
assert_contains "$(cat "$mock_capture/claude.args")" "[1]"
assert_contains "$(cat "$mock_capture/claude.prompt")" "mock claude"

# A failing peer CLI must propagate its exit status and surface its error
# output, even when the peer prints the error to stdout.
cat > "$mock_bin/codex" <<'MOCK_CODEX_FAIL'
#!/usr/bin/env bash
cat >/dev/null
printf 'mock codex failure on stdout\n'
exit 3
MOCK_CODEX_FAIL
chmod +x "$mock_bin/codex"
fail_status=0
fail_err="$(PATH="$mock_bin:$PATH" $BIN ask codex --context "$ctx" --question "fail" 2>&1 >/dev/null)" || fail_status=$?
if [[ "$fail_status" -ne 3 ]]; then
  echo "expected exit status 3 from failing peer, got $fail_status" >&2
  exit 1
fi
assert_contains "$fail_err" "mock codex failure on stdout"

if command -v node >/dev/null 2>&1; then
  node -e "const p=require('$ROOT_DIR/package.json'); if (p.version !== '0.4.1' || !p.bin || p.bin['ask-colleague'] !== 'bin/colleague.js' || p.bin.colleague !== 'bin/colleague.js') { console.error('package.json mismatch: expected version 0.4.1 with ask-colleague/colleague bin entries pointing at bin/colleague.js, got version ' + p.version); process.exit(1); }"
fi

if command -v npm >/dev/null 2>&1; then
  (cd "$ROOT_DIR" && npm pack --dry-run >/dev/null)
  pack_name="$(cd "$ROOT_DIR" && npm pack --pack-destination "$TMP_DIR" 2>/dev/null | tail -n 1)"
  tgz="$TMP_DIR/$pack_name"
  [[ -f "$tgz" ]]
  npx_version="$(npx --yes --package "$tgz" ask-colleague --version)"
  assert_contains "$npx_version" "0.4.1"
  npx_install_dry_run="$(npx --yes --package "$tgz" ask-colleague install --dry-run --prefix "$TMP_DIR/npx-prefix")"
  assert_contains "$npx_install_dry_run" "Installed colleague binary"
  assert_contains "$npx_install_dry_run" "Skipped ~/.codex/AGENTS.md fallback block"
fi

printf 'smoke tests passed\n'
