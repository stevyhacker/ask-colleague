<!-- BEGIN agent-colleague bridge -->
## Colleague bridge

A `colleague` CLI may be available for a one-shot second opinion from Claude Code. Use it only when the user explicitly asks to "ask Claude", "ask a colleague", or after you have made a concrete attempt and are genuinely blocked.

Procedure:

1. Create a private temp file and clean it up after use:

   ```bash
   ctx="$(mktemp -t colleague-ctx.XXXXXX.md)"
   trap 'rm -f "$ctx"' EXIT
   ```

2. Write a compact context briefing into `$ctx`. Include the goal, relevant file paths/snippets, what has been tried, the exact error or dilemma, and constraints. Do not include secrets or raw transcripts.

3. Run:

   ```bash
   colleague ask claude --context "$ctx" --question "your specific question"
   ```

4. Treat Claude's response as advice from a peer, not ground truth. Compare it to your own analysis before acting. Do not start a nested or multi-turn agent-to-agent loop.
<!-- END agent-colleague bridge -->
