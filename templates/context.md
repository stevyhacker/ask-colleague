# Colleague briefing

Use this with a private temp file, for example:

```bash
ctx="$(mktemp -t colleague-ctx.XXXXXX.md)"
trap 'rm -f "$ctx"' EXIT
colleague make-context --output "$ctx"
```

## Goal

Explain the user-facing goal in 2-5 sentences.

## Relevant files and snippets

Include file paths and only the snippets needed for the peer to reason.
Summarize large files rather than dumping them.

```text
path/to/file.ext
short snippet or description
```

## What has been tried

- Attempt 1:
- Attempt 2:

## Current error, dilemma, or design choice

Paste the exact error message or the decision being debated.

## Constraints and non-goals

- Runtime / framework / compatibility constraints:
- Security or privacy constraints:
- Non-goals:

## Question for the peer

What should the primary agent double-check, change, or avoid?
