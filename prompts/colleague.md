---
description: Consult Claude Code for a one-shot second opinion
argument-hint: "[question]"
---

# /prompts:colleague — consult Claude Code for a second opinion

You can ask Claude Code, an independent local AI coding agent, for advice. It has no access to this session, so everything it knows must come from a compact briefing you write.

This custom prompt is a legacy compatibility fallback. Prefer the `$colleague` skill on Codex versions that load user skills.

Steps:

1. Create a private temp file and clean it up after use:

   ```bash
   ctx="$(mktemp -t colleague-ctx.XXXXXX.md)"
   trap 'rm -f "$ctx"' EXIT
   ```

2. Write a compact briefing into `$ctx` containing:

   - **Goal** — what the user is ultimately trying to achieve
   - **Relevant files and snippets** — paths plus only the key snippets
   - **What has been tried** — approaches attempted and their results/errors
   - **Current error or dilemma** — exact error, failing test, or design choice
   - **Constraints / non-goals**

   Summarize aggressively. Never paste the raw session transcript, tool logs, `.env` files, API keys, tokens, or credentials.

3. Run:

   ```bash
   colleague ask claude --context "$ctx" --question "$ARGUMENTS"
   ```

   If `colleague` is not on PATH, use `~/.local/bin/colleague`.

4. Treat the response as peer advice, not ground truth: compare it with your own analysis, tell the user where you agree or disagree, then proceed using your own judgment.

Rules: one focused question per consultation; do not start nested agent-to-agent consultation; if the answer misses, improve the briefing and ask once more rather than starting a multi-turn loop; if the `claude` CLI is not installed, say so and continue without it.
