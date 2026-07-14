---
description: "Generate or update Azoo Pester tests for a command/helper change, following repo test layout, E2E tagging, and vector-source documentation rules."
name: "Generate Azoo Tests"
argument-hint: "Target file or function and test intent (unit/E2E)"
agent: "agent"
---
Generate or update tests for this Azoo change:

{{input}}

Requirements:
- Use Pester test files under tests/.
- Follow repository layout:
  - Public command tests: tests/public/<category>/<Command>.Tests.ps1
  - Private helper tests: tests/private/<Helper>.Tests.ps1
- For deterministic local tests, avoid external network/tool dependencies.
- For tests that require network, GitHub CLI, Azure, or other external tools, tag tests with E2E and include clear skip logic when prerequisites are missing.
- For cryptographic or algorithmic validation, use well-known vectors and document vector source URLs in test comments.
- Prefer stable assertions (avoid brittle output formatting checks).
- If current repo test scaffolding is unclear, ask one concise clarifying question before writing files.

After edits:
- Run or propose a Pester command suitable for the updated tests.
- Summarize which files were created or changed.
