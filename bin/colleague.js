#!/usr/bin/env node
// npm bin launcher for the Bash CLI in bin/colleague.
//
// npm's Windows shims execute the shebang interpreter directly. For a Bash
// script in PowerShell/cmd.exe that resolves to the WSL bash stub, which fails
// with a cryptic "execvpe(/bin/bash) failed" error when no Linux distribution
// is installed. Routing the bin through Node (always present under npx) lets
// us delegate to a working Bash where one exists and print actionable
// guidance where one does not.
'use strict';

const { spawnSync } = require('child_process');
const path = require('path');

const script = path.join(__dirname, 'colleague');
const args = process.argv.slice(2);

function fail(message) {
  process.stderr.write(message);
  process.exit(1);
}

const WINDOWS_HELP = [
  'ask-colleague: this command needs Bash, which is not available in this Windows shell.',
  '',
  'The Claude Code <-> Codex bridge is a Bash CLI, so on Windows it runs inside',
  'WSL or Git Bash:',
  '',
  '  WSL (recommended):',
  '    1. Install WSL: https://learn.microsoft.com/windows/wsl/install',
  '    2. Open a WSL shell (e.g. Ubuntu) and run: npx ask-colleague@latest install',
  '       The claude / codex CLIs must also be installed inside WSL.',
  '',
  '  Git Bash (best effort):',
  '    Run the same npx command from a Git Bash terminal.',
  '',
  'If you saw a "WSL ... execvpe(/bin/bash) failed" error, Windows invoked the',
  'WSL bash stub without a Linux distribution installed.',
  '',
].join('\n');

if (process.platform === 'win32') {
  // Only proceed with a Bash that understands Windows paths (Git Bash/MSYS,
  // Cygwin). The WSL stub either fails outright (no distro) or cannot read
  // the Windows path of the script we need to hand it.
  const probe = spawnSync('bash', ['-c', 'echo $OSTYPE'], { encoding: 'utf8' });
  const ostype = (probe.stdout || '').trim();
  if (probe.error || probe.status !== 0 || !/^(msys|cygwin)/.test(ostype)) {
    fail(WINDOWS_HELP);
  }
}

const result = spawnSync('bash', [script, ...args], { stdio: 'inherit' });
if (result.error && result.error.code === 'ENOENT') {
  fail('ask-colleague: bash not found in PATH. Install Bash, or on Windows run inside WSL or Git Bash.\n');
}
process.exit(result.status === null ? 1 : result.status);
