function Normalize-AzooScopeId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $normalized = $Value.Trim()
    if (-not $normalized.StartsWith('/')) {
        $normalized = "/$normalized"
    }

    if ($normalized.Length -gt 1 -and $normalized.EndsWith('/')) {
        $normalized = $normalized.TrimEnd('/')
    }

    $normalized
}