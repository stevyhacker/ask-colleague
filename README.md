# Ask Colleague

[![npm version](https://img.shields.io/npm/v/ask-colleague.svg)](https://www.npmjs.com/package/ask-colleague)

A tiny, self-contained bridge that lets one local AI coding CLI ask another local AI coding CLI for a one-shot second opinion.

The default flow:

- Claude Code asks Codex with `colleague ask codex ...`
- Codex asks Claude Code with `colleague ask claude ...`
- The primary agent writes a compact context briefing, shells out to the peer once, reads stdout, and folds the advice back into the current session.

This repository packages the pattern as:

- one dependency-free Bash CLI: `bin/colleague`
- one npm package: `ask-colleague`
- one Claude Code skill: `skills/claude/colleague/SKILL.md`
- one Codex skill: `skills/codex/colleague/SKILL.md`
- install/uninstall scripts with a safety manifest
- context templates and fallback instruction snippets

## Why this exists

Both CLIs have headless one-shot modes. Codex supports `codex exec` for non-interactive runs and can read the task from stdin with `codex exec -`. Claude Code supports print mode with `claude -p`, and can combine piped stdin with a prompt.

That makes “ask a colleague” just a local shell bridge:

1. summarize the current task into a small context file
2. invoke the other CLI once
3. treat the answer as peer advice, not ground truth
4. continue in the original session

## Install with npx

```bash
npx ask-colleague@latest install
```

That one command installs:

```text
~/.local/bin/colleague
~/.local/bin/ask-colleague
~/.claude/skills/colleague/SKILL.md
~/.agents/skills/colleague/SKILL.md
~/.agents/skills/colleague/agents/openai.yaml
~/.codex/prompts/colleague.md          # legacy Codex custom prompt fallback
~/.ask-colleague/install-manifest.tsv
```

The installer refuses to overwrite existing files unless they are tracked in the install manifest and have not been modified. Use `--force` only when you intentionally want to replace an existing ask-colleague install.

Make sure `~/.local/bin` is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then check your setup:

```bash
colleague doctor
```

Install only selected parts:

```bash
npx ask-colleague@latest install --bin
npx ask-colleague@latest install --claude
npx ask-colleague@latest install --codex
npx ask-colleague@latest install --prefix "$HOME/bin"
```

### Optional global Codex fallback

By default, install does **not** modify `~/.codex/AGENTS.md`, because that file affects every Codex session. To opt into the fallback block for Codex versions that do not load skills or prompts the way you expect, run:

```bash
npx ask-colleague@latest install --agents-md
```

The AGENTS.md block is marker-delimited and idempotent. `colleague uninstall` removes it only when it was recorded in the install manifest, or when you pass `--force` for a legacy uninstall.

Uninstall:

```bash
colleague uninstall
# or, without relying on the installed command:
npx ask-colleague@latest uninstall
```

Uninstall removes only files recorded in `~/.ask-colleague/install-manifest.tsv` and only if their checksums still match. If you edited an installed skill or prompt, uninstall leaves it in place and tells you to use `--force` if you really want it removed.

### Windows

`colleague` is a Bash CLI. On Windows, run everything — `npx`, the install, and the `claude`/`codex` CLIs — inside WSL (recommended) or Git Bash (best effort). Running `npx ask-colleague@latest install` from PowerShell or cmd.exe prints setup guidance instead of failing on a missing Bash.

## Install from source

```bash
git clone https://github.com/stevyhacker/ask-colleague.git
cd ask-colleague
./install.sh
```

This performs the same install as `npx ask-colleague@latest install`.

## Direct CLI usage

Create a briefing:

```bash
ctx="$(mktemp -t colleague-ctx.XXXXXX.md)"
colleague make-context --output "$ctx"
$EDITOR "$ctx"
```

Ask Codex:

```bash
colleague ask codex \
  --context "$ctx" \
  --question "What is the strongest critique of this implementation plan?"
```

Ask Claude:

```bash
colleague ask claude \
  --context "$ctx" \
  --question "What bug or design flaw am I most likely missing?"
```

Preview the assembled prompt without calling either CLI:

```bash
colleague ask codex \
  --context "$ctx" \
  --question "Review this" \
  --dry-run
```

You can set a default peer:

```bash
export COLLEAGUE_DEFAULT_PEER=codex
colleague ask --context "$ctx" --question "Review this plan"
```

## Using from Claude Code

After install, Claude Code can invoke the skill explicitly as:

```text
/colleague ask Codex to critique my current plan
```

The Claude skill has `disable-model-invocation: true`, so it is explicit-only by default. The skill instructs Claude to:

1. create a private `mktemp` context file
2. write a concise briefing
3. run `colleague ask codex ...`
4. compare Codex’s response with its own analysis
5. proceed using its own judgment

## Using from Codex

The install wires up the Codex → Claude direction in two default ways, plus one opt-in fallback:

1. **Skill** (`~/.agents/skills/colleague`) — preferred on Codex versions that scan user skill locations:

   ```text
   $colleague ask Claude to critique my current plan
   ```

   The Codex skill policy sets `allow_implicit_invocation: false`, so it is explicit-only by default.

2. **Legacy custom prompt** (`~/.codex/prompts/colleague.md`) — compatibility fallback:

   ```text
   /prompts:colleague is optimistic locking the right call for this endpoint?
   ```

3. **AGENTS.md block** — opt-in only:

   ```bash
   npx ask-colleague@latest install --agents-md
   ```

You can also copy `snippets/AGENTS.md` into a project-level `AGENTS.md` if you want the fallback available only in specific repos.

## Options

```text
colleague ask [codex|claude] --context FILE --question TEXT [options]

--cwd DIR             run the peer CLI from this directory
--model MODEL         pass a model override to the peer CLI
--sandbox MODE        Codex sandbox: read-only, workspace-write, danger-full-access
--timeout SECONDS     use timeout/gtimeout when available
--max-bytes BYTES     refuse over-large context files
--allow-large-context disable the size guard
--dry-run             print the prompt, do not call peer CLI
```

Environment defaults:

```bash
export COLLEAGUE_DEFAULT_PEER="codex"
export COLLEAGUE_CODEX_MODEL="gpt-5.4"
export COLLEAGUE_CLAUDE_MODEL="sonnet"
export COLLEAGUE_CODEX_SANDBOX="read-only"
export COLLEAGUE_TIMEOUT="120"
export COLLEAGUE_VERBOSE="1"
export COLLEAGUE_MAX_CONTEXT_BYTES="120000"
export COLLEAGUE_STATE_DIR="$HOME/.ask-colleague"
```

## Safety model

This project intentionally keeps the consultation one-shot and read-oriented.

- Do not paste raw transcripts. They are noisy, expensive, and often contain private data.
- Do not include secrets, `.env` contents, private keys, tokens, or credentials in the briefing.
- The bridge sends the prompt through stdin to avoid shell argument-length and quoting problems.
- Codex is invoked through non-interactive `codex exec` with `--sandbox read-only` by default for the one-shot consult.
- Claude is called with `--bare`, `-p`, `--output-format text`, `--no-session-persistence`, `--max-turns 1`, `--tools ""`, and `--` before the positional prompt.
- Installed skills are explicit-only by default.
- The peer response is advice only. The primary agent remains responsible for verifying, testing, and deciding.

See `docs/security.md` for more detail.

## Good context beats big context

A good briefing is usually under 1,000-2,000 words:

```markdown
# Goal

# Relevant files and snippets

# What I tried

# Current error or dilemma

# Constraints / non-goals
```

Bad briefing:

- entire conversation transcript
- full tool logs
- whole files pasted without explanation
- secrets or environment dumps
- vague question like “thoughts?”

Good question:

- “What edge case does this migration plan miss?”
- “Is there a simpler patch than adding a new abstraction?”
- “Why might this test still be flaky after this fix?”
- “What would you reject in review?”

## Repository layout

```text
ask-colleague/
  bin/colleague                         # main bridge CLI (Bash)
  bin/colleague.js                      # Node launcher for the npm bin (Windows-safe)
  package.json                          # npm package metadata and bin mappings
  scripts/ask-codex.sh                  # compatibility wrapper
  scripts/ask-claude.sh                 # compatibility wrapper
  skills/claude/colleague/SKILL.md      # Claude Code skill, explicit-only
  skills/codex/colleague/SKILL.md       # Codex skill, explicit-only via policy
  prompts/colleague.md                  # legacy Codex custom prompt fallback
  snippets/AGENTS.md                    # optional Codex AGENTS.md block
  snippets/CLAUDE.md                    # fallback Claude instructions
  templates/context.md                  # manual context template
  docs/security.md
  docs/publishing.md
  tests/smoke.sh
```

## Troubleshooting

### `WSL ... execvpe(/bin/bash) failed: No such file or directory` on Windows

Older versions (0.1.0) pointed the npm bin directly at the Bash script, so PowerShell invoked the WSL bash stub, which fails like this when no Linux distribution is installed. Upgrade with `npx ask-colleague@latest install` — current versions detect this and print setup guidance. Then run the bridge inside WSL or Git Bash as described in the Windows section above.

### `colleague: codex CLI not found in PATH`

Install Codex CLI and confirm `codex --version` works in the same shell where Claude Code or Codex is running.

### `colleague: claude CLI not found in PATH`

Install Claude Code and confirm `claude --version` works in the same shell where Codex is running.

### Install refuses to overwrite a file

The file already exists and is not tracked as an unmodified ask-colleague install. Inspect it first. Re-run with `--force` only if it belongs to this package and should be replaced.

### Uninstall leaves a file in place

The file was modified after install, so uninstall refuses to delete it by default. Keep the file, remove it manually, or run `colleague uninstall --force` if you are sure.

### The primary agent does not use the skill

Invoke it explicitly first:

```text
/colleague ask Codex to review this        # in Claude Code
$colleague ask Claude to review this       # in Codex skill
/prompts:colleague ask Claude to review this  # legacy Codex prompt fallback
```

The installed skills are intentionally explicit-only by default. This avoids surprising cross-agent calls from paid/authenticated CLIs.

### The peer answer is generic

The briefing is probably too thin. Add file paths, the exact error, constraints, and a pointed question.

### The peer answer is distracted by irrelevant context

The briefing is probably too large. Remove raw transcript/tool noise and keep only the current decision point.

## Development

Run smoke tests:

```bash
npm test
```

The smoke tests use dry-run and mocked CLI paths, so they do not require authenticated Codex or Claude CLIs.

## npm package details

`package.json` exposes two commands through the `bin` field:

```json
{
  "bin": {
    "ask-colleague": "bin/colleague.js",
    "colleague": "bin/colleague.js"
  }
}
```

`bin/colleague.js` is a tiny Node launcher that delegates to the Bash CLI. It exists because npm's Windows shims would otherwise hand the Bash script to the WSL bash stub, which fails cryptically when no Linux distribution is installed. The launcher runs the script with a real Bash where one exists and prints setup guidance otherwise.

This means:

```bash
npx ask-colleague@latest install
```

runs the package command named `ask-colleague`, while a global install also provides both `ask-colleague` and `colleague` commands:

```bash
npm install --global ask-colleague
colleague doctor
```

The project has no runtime npm dependencies. Node/npm are only used as the distribution mechanism.

## Local npm smoke test

Before publishing, test the exact tarball that npm would distribute:

```bash
npm test
npm pack --dry-run
tgz="/tmp/$(npm pack --pack-destination /tmp | tail -n 1)"
npx --yes --package "$tgz" ask-colleague --version
npx --yes --package "$tgz" ask-colleague install --dry-run
```

## Publish to npm

```bash
npm login
npm publish --access public
```

See `docs/publishing.md` for a pre-publish checklist.

## License

MIT. See `LICENSE`.

## References

- npm package.json documentation: https://docs.npmjs.com/files/package.json/
- npm npx documentation: https://docs.npmjs.com/cli/v8/commands/npx/
- Codex CLI docs: https://developers.openai.com/codex/cli/reference
- Codex skills docs: https://developers.openai.com/codex/skills
- Claude Code CLI docs: https://docs.anthropic.com/en/docs/claude-code/cli-reference
- Claude Code skills docs: https://docs.anthropic.com/en/docs/claude-code/skills
