---
name: colleague
description: Consult Claude Code as a second local AI coding agent for a one-shot peer review when explicitly requested.
argument-hint: "[question]"
---

# Colleague: ask Claude Code for advice

Use this skill only when the user explicitly asks to "ask Claude", "ask a colleague", or "get a second opinion". It gets a one-shot second opinion from Claude Code without letting it take over the repo.

## Workflow

1. Create a private, unpredictable temp file with `mktemp`, and clean it up after use:

   ```bash
   ctx="$(mktemp -t colleague-ctx.XXXXXX.md)"
   trap 'rm -f "$ctx"' EXIT
   ```

2. Write a compact briefing into `$ctx`. Include only what Claude needs:

   - user-facing goal
   - relevant file paths and short snippets
   - what you have already tried
   - exact error, dilemma, or design choice
   - constraints and non-goals

   Do not dump the raw conversation transcript, tool logs, `.env` files, API keys, private URLs, tokens, or credentials. Summarize aggressively.

3. Ask Claude with the installed bridge:

   ```bash
   colleague ask claude \
     --context "$ctx" \
     --question "What is the strongest critique of my current plan?"
   ```

   Use `--model <model>` only when the user asks for a specific model. The bridge calls Claude in print mode with no session persistence, one max turn, `--bare`, and `--tools ""`.

4. Treat the response as peer advice, not ground truth. Compare it to your own analysis.

5. In your response to the user, say that you consulted Claude, then explain where you agree, disagree, or remain uncertain. Continue with the implementation or recommendation using your own judgment.

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
