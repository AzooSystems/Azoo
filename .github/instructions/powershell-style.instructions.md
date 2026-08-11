---
description: "Use when creating or editing Azoo public PowerShell command files, advanced functions, parameter blocks, or ShouldProcess behavior in src/Azoo/public/**/*.ps1."
applyTo: "src/Azoo/public/**/*.ps1"
---

# Azoo Public Command Style

- Use one function per file, and match filename to function name.
- Use the naming pattern Verb-AzooNoun for public functions.
- Start functions as advanced functions with CmdletBinding().
- For state-changing operations, use CmdletBinding(SupportsShouldProcess) and guard side effects with $PSCmdlet.ShouldProcess(...).
- Prefer explicit parameter design:
  - Mandatory for required inputs.
  - ValidateSet for constrained string values.
  - ParameterSetName when inputs are mutually exclusive.
- Keep parameter names and behavior compatible with existing public commands unless a breaking change is explicitly requested.
- Avoid interactive-only flows unless needed; if interaction is required, keep Desktop/Core compatibility checks.
- Keep implementation focused and minimal; move reusable internals to private helpers under src/Azoo/private/.
- Architectural decisions driven by Powershell 5.1 support must be documented in the code comments, and any workarounds must be clearly explained.

## Quick Pattern

```powershell
function Set-AzooExample {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($PSCmdlet.ShouldProcess("resource $Name", "Set configuration")) {
        # side effect here
    }
}
```