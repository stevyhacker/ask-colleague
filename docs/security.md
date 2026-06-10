# Security notes

`agent-colleague` is a convenience bridge, not a trust boundary. It sends whatever you put in the context file to another local AI CLI authenticated as you.

## Principles

1. **Minimize context.** A short, hand-written briefing is safer and more useful than a raw transcript.
2. **No secrets.** Never include `.env` files, private keys, API tokens, cookies, credentials, proprietary customer data, or raw production logs.
3. **One-shot by default.** Avoid agent-to-agent loops. If the answer is bad, rewrite the briefing and ask again.
4. **Read-oriented.** Codex is invoked with `--sandbox read-only` by default. Claude is invoked with `--bare`, print mode, no session persistence, one max turn, `--tools ""`, and `--` before its positional prompt.
5. **Explicit-only skills.** The installed Claude and Codex skills are configured so the user or primary agent must invoke them intentionally.
6. **Advice, not authority.** The primary agent/human reviews the peer’s answer before making changes.

## Prompt injection

The bridge wraps the context in `<session_context>` and instructs the peer to treat it as untrusted. That helps, but it is not a formal security guarantee. Do not include hostile or sensitive data unless you are comfortable with the peer model reading it.

The consulting prompt also tells the peer not to start nested colleague calls, not to spawn tools, and not to modify files. Treat this as defense-in-depth, not as a hard sandbox.

## Temporary files

Skills and snippets use `mktemp` instead of a fixed predictable temp path. This avoids collisions and reduces accidental exposure on shared machines.

Recommended pattern:

```bash
ctx="$(mktemp -t colleague-ctx.XXXXXX.md)"
trap 'rm -f "$ctx"' EXIT
```

## Sandboxing

Codex defaults to:

```bash
codex exec --color never --ephemeral --skip-git-repo-check --sandbox read-only -
```

You can opt into broader access with `--sandbox workspace-write` or `--sandbox danger-full-access`, but this is not recommended for a consultation bridge.

Claude Code is called with:

```bash
claude --bare -p --output-format text --no-session-persistence --max-turns 1 --tools "" -- "Read the consulting request from stdin and answer it directly."
```

`--bare` avoids MCP auto-discovery, `--tools ""` disables built-in Claude Code tools for the consultant call, and `--` prevents the positional prompt from being consumed by the variadic `--tools` option. The bridge passes the consulting package on stdin.

## Install and uninstall safety

`install.sh` writes a manifest to:

```text
~/.agent-colleague/install-manifest.tsv
```

The manifest records installed files and checksums. Reinstall overwrites only files that are tracked and unmodified. Uninstall removes only tracked, unmodified files. Use `--force` for legacy installs or intentional replacement/removal.

The installer does not modify `~/.codex/AGENTS.md` by default. Pass `--agents-md` to opt into that global fallback.

## Recommended team policy

For shared or public repos, keep the installed skill instruction-only and require normal shell approval on first use. Teams can add their own allow rules after reviewing the scripts.
