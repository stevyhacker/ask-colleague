# Publishing Ask Colleague to npm

This package is designed so the public install path is one command:

```bash
npx ask-colleague@latest install
```

`npx` runs the npm package's executable once. The executable then copies the long-lived `colleague` command and both skill files into the user's home directory, recording checksums in `~/.ask-colleague/install-manifest.tsv`.

## 1. Check package metadata

`package.json` must agree with the rest of the repo before each publish:

- `version` matches `VERSION` in `bin/colleague` and the version checks in `tests/smoke.sh`
- `homepage`, `repository`, and `bugs` point at the public GitHub repo
- `bin` maps both `ask-colleague` and `colleague` to `bin/colleague`

## 2. Run local checks

```bash
npm test
npm pack --dry-run
```

Then build a real local tarball and run it through `npx`:

```bash
tgz="/tmp/$(npm pack --pack-destination /tmp | tail -n 1)"
npx --yes --package "$tgz" ask-colleague --version
npx --yes --package "$tgz" ask-colleague install --dry-run
```

## 3. Inspect package contents

Make sure the npm tarball includes only what users need:

```bash
npm pack --dry-run
```

Expected included paths:

```text
package.json
README.md
LICENSE
CONTRIBUTING.md
bin/colleague
install.sh
uninstall.sh
scripts/ask-codex.sh
scripts/ask-claude.sh
skills/claude/colleague/SKILL.md
skills/codex/colleague/SKILL.md
skills/codex/colleague/agents/openai.yaml
prompts/colleague.md
snippets/AGENTS.md
snippets/CLAUDE.md
templates/context.md
docs/security.md
docs/publishing.md
```

## 4. Publish

```bash
npm login
npm publish --access public
```

For scoped packages, `--access public` is required unless your npm account/org has different defaults.

## 5. Verify public install

After npm finishes publishing:

```bash
npx ask-colleague@latest --version
npx ask-colleague@latest install --dry-run
```

Then do a real install in a clean shell:

```bash
npx ask-colleague@latest install
export PATH="$HOME/.local/bin:$PATH"
colleague doctor
```

Also verify overwrite protection and uninstall behavior:

```bash
colleague uninstall --dry-run
colleague uninstall
```

## 6. Optional AGENTS.md fallback

Do not enable the global Codex AGENTS.md fallback by default in release notes. Users who want it can opt in:

```bash
npx ask-colleague@latest install --agents-md
```

## 7. Release updates

Bump the version before each publish:

```bash
npm version patch
npm publish --access public
```

Use `minor` for new features and `major` for breaking changes.

## Notes

- The package intentionally has no runtime npm dependencies.
- The executable is Bash, so the supported target environments are macOS, Linux, and WSL-like shells.
- `npx ask-colleague@latest install` is a bootstrap. The persistent command after install is `colleague`.
