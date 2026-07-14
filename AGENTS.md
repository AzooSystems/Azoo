# AGENTS.md

This repository contains a script-based PowerShell module for Azure administration helpers.

## Project At A Glance

- Language: PowerShell
- Module root: src/Azoo
- Manifest: src/Azoo/Azoo.psd1
- Module loader: src/Azoo/Azoo.psm1
- Public commands: src/Azoo/public/**/*.ps1
- Private helpers: src/Azoo/private/**/*.ps1
- Examples: examples/
- Release workflow: .github/workflows/release.yml

## How The Module Is Wired

- src/Azoo/Azoo.psm1 dot-sources all scripts under public/ and private/ recursively.
- Exported commands are derived from script basenames under public/.
- Keep one function per .ps1 file.

## Function Authoring Conventions

- Use Verb-AzooNoun naming for new public functions.
- Place new public functions in the most relevant category folder under src/Azoo/public/ (misc, network, pim, shared).
- Use CmdletBinding() for advanced functions.
- For state-changing commands, use CmdletBinding(SupportsShouldProcess) and guard execution with ShouldProcess.
- Use explicit parameter validation where it improves safety (Mandatory, ValidateSet, ParameterSetName).
- Keep private helper utilities under src/Azoo/private/.

## Validation And Release

- Tests are implemented with Pester (v6 in local dev at time of writing).
- Test discovery is configured in `pester.config.psd1` with `TestSuite.Path = tests`.
- Keep test files under `tests/`, mirroring source intent:
  - Public command tests: `tests/public/<category>/<Command>.Tests.ps1`
  - Private helper tests: `tests/private/<Helper>.Tests.ps1`
- Use test tags intentionally:
  - `E2E` for network/CLI/external dependency tests.
  - Omit `E2E` for deterministic local unit tests.
- Useful test runs:
  - `pwsh -NoProfile -Command "Invoke-Pester -Path ./tests -Output Detailed"`
  - `pwsh -NoProfile -Command "Invoke-Pester -Path ./tests -TagFilter E2E -Output Detailed"`
- For deterministic algorithm tests (for example hashing), prefer well-known vectors and document the vector source URLs in test comments.
- Run static checks when available:
  - VS Code task: PSRule: Run analysis
- Release is tag-driven via GitHub Actions:
  - Push tag format: vX.Y.Z or vX.Y.Z-prerelease
  - Workflow updates manifest version, builds .nupkg, and publishes

## Environment Notes

- Manifest targets PowerShell 5.1 minimum.
- Some commands require Azure context and Az modules (for example, Get-AzADUser and role scheduling cmdlets).
- Some interactive flows use Out-GridView (Desktop) or Out-ConsoleGridView (Core).

## Link, Do Not Duplicate

- Install and package verification guidance: [README.md](README.md)
- Local containerized PowerShell notes: [.local-notes/Containers.md](.local-notes/Containers.md)
- Example data/config pattern: [examples/SnowflakeConfig.psd1](examples/SnowflakeConfig.psd1)
- Release behavior and publishing details: [.github/workflows/release.yml](.github/workflows/release.yml)

## Safe Change Checklist For Agents

- Confirm function file placement and naming match existing patterns.
- If a public command is added, ensure its basename matches the exported function name.
- Add or update tests under `tests/` for changed behavior.
- If tests rely on network or external tools, tag them `E2E` and keep a skip path with a clear reason.
- Avoid changing release semantics unless explicitly requested.
- Keep edits minimal and scoped; do not refactor unrelated files.
