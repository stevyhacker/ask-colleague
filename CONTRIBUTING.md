# Contributing

Thanks for improving Ask Colleague.

## Local checks

```bash
npm test
npm pack --dry-run
bash -n bin/colleague install.sh uninstall.sh scripts/ask-codex.sh scripts/ask-claude.sh
```

For an end-to-end local `npx` check:

```bash
tgz="/tmp/$(npm pack --pack-destination /tmp | tail -n 1)"
npx --yes --package "$tgz" ask-colleague --version
npx --yes --package "$tgz" ask-colleague install --dry-run
```

## Design constraints

- Keep the bridge one-shot and stateless.
- Avoid runtime npm dependencies; npm is only the distribution channel.
- Do not add defaults that grant write access to the peer agent.
- Keep installed skills explicit-only unless users intentionally edit their local copy.
- Keep prompts short and explicit.
- Preserve compatibility with macOS, Linux, WSL, and Git Bash where possible.
- Use `mktemp` for context files; do not document fixed predictable temp paths.

## Pull requests

Please include:

- why the change is needed
- before/after example command
- any security implications
- local test output
