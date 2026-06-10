# Publishing Ask Colleague to npm

This package is designed so the public install path is one command:

```bash
npx ask-colleague@latest install
```

`npx` runs the npm package's executable once. The executable then copies the long-lived `colleague` command and both skill files into the user's home directory, recording checksums in `~/.ask-colleague/install-manifest.tsv`.

## 1. Pick the package name

The starter `package.json` uses:

```json
"name": "ask-colleague"
```

Before publishing, check that the package name is available. If it is taken, use a scoped package name instead:

```json
"name": "@your-scope/ask-colleague"
```

With a scoped name, the install command becomes:

```bash
npx @your-scope/ask-colleague@latest install
```

## 2. Add public repository metadata

This starter package intentionally does not include fake GitHub metadata. Before publishing from your real repo, add fields like:

```json
{
  "homepage": "https://github.com/<owner>/<repo>#readme",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/<owner>/<repo>.git"
  },
  "bugs": {
    "url": "https://github.com/<owner>/<repo>/issues"
  }
}
```

Also replace `<your-ask-colleague-repo-url>` in `README.md`.

## 3. Run local checks

```bash
npm test
npm pack --dry-run
```

Then build a real local tarball and run it through `npx`:

```bash
npm pack --pack-destination /tmp
npx --yes --package /tmp/ask-colleague-0.4.0.tgz ask-colleague --version
npx --yes --package /tmp/ask-colleague-0.4.0.tgz ask-colleague install --dry-run
```

If you changed the package name or version, update the tarball path accordingly.

## 4. Inspect package contents

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

## 5. Publish

```bash
npm login
npm publish --access public
```

For scoped packages, `--access public` is required unless your npm account/org has different defaults.

## 6. Verify public install

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

## 7. Optional AGENTS.md fallback

Do not enable the global Codex AGENTS.md fallback by default in release notes. Users who want it can opt in:

```bash
npx ask-colleague@latest install --agents-md
```

## 8. Release updates

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
