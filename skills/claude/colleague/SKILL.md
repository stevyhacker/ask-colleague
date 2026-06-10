---
name: colleague
description: Consult Codex as a second local AI coding agent for a one-shot peer review when explicitly requested.
disable-model-invocation: true
argument-hint: "[question]"
---

# Colleague: ask Codex for advice

Use this skill only when the user explicitly asks to "ask Codex", "ask a colleague", or "get a second opinion". It gets a one-shot second opinion from Codex without handing control of the repo to it.

## Workflow

1. Create a private, unpredictable temp file with `mktemp`, and clean it up after use:

   ```bash
   ctx="$(mktemp -t colleague-ctx.XXXXXX.md)"
   trap 'rm -f "$ctx"' EXIT
   ```

2. Write a compact briefing into `$ctx`. Include only what Codex needs:

   - user-facing goal
   - relevant file paths and short snippets
   - what you have already tried
   - exact error, dilemma, or design choice
   - constraints and non-goals

   Do not dump the raw conversation transcript, tool logs, `.env` files, API keys, private URLs, tokens, or credentials. Summarize aggressively.

3. Ask Codex with the installed bridge:

   ```bash
   colleague ask codex \
     --context "$ctx" \
     --question "What is the strongest critique of my current plan?"
   ```

   Use `--model <model>` only when the user asks for a specific model. The bridge runs Codex non-interactively (`codex exec`) in a read-only sandbox by default for the one-shot consult.

4. Treat the response as peer advice, not ground truth. Compare it to your own analysis.

5. In your response to the user, say that you consulted Codex, then explain where you agree, disagree, or remain uncertain. Continue with the implementation or recommendation using your own judgment.

## Good briefing template

```markdown
# Goal

# Relevant files and snippets

# What I tried

# Current error or dilemma

# Constraints / non-goals
```

## When not to use this skill

Do not use it for simple questions you can answer directly. Do not use it to outsource user-private or secret material. Do not start a multi-turn agent-to-agent loop; if the answer misses, improve the briefing and ask once more.
