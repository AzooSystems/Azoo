<#
.SYNOPSIS
Verifies a file's GitHub attestation bundle.

.PARAMETER Path
Path to the file whose GitHub attestation should be verified.

.PARAMETER OrgAndRepository
GitHub repository in owner/name format that contains the attestation.

.PARAMETER VerboseTooling
Enables verbose and debug output from the GitHub attestation API request tooling.

.PARAMETER DebugGhCli
Sets GH_DEBUG=1 before invoking gh attestation verify to enable GitHub CLI debug output.
#>
function Test-AzooGitHubAttestation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OrgAndRepository,

        [Parameter()]
        [switch]$VerboseTooling,

        [Parameter()]
        [switch]$DebugGhCli
    )

    # TODO: Not PS 5.1 compatible, relies on newer PowerShell features
    $toolingDebugPreference = $VerboseTooling.IsPresent ? $true : $false
    $toolingVerbosePreference = $VerboseTooling.IsPresent ? $true : $false

    $ErrorActionPreference = "Stop"

    $ghCommand = Get-command gh -ErrorAction SilentlyContinue
    if ($null -eq $ghCommand) {
        throw "The 'gh' command is not available. Please install the GitHub CLI."
    }

    $fileSum = Get-FileSha256 -Path $Path
    Write-Debug "Computed SHA256 for file '$Path': $fileSum"
    $url = "https://api.github.com/repos/$OrgAndRepository/attestations/sha256:$fileSum"
    $jsonPath = "${Path}.jsonl"

    if ($PSCmdlet.ShouldProcess($Path, "Verify GitHub attestation and write bundle to '$jsonPath'")) {
        Write-Verbose "Calling GitHub API at URL: $url"

        try {
            $response = Invoke-RestMethod -Method Get -Uri $url -ErrorAction Stop -Debug:$toolingDebugPreference -Verbose:$toolingVerbosePreference
        } catch {
            throw "Failed to call GitHub API at URL '$url': $_"
        }

        if ($DebugPreference -eq "Continue") {
            Write-Debug "attestation API Response for '$Path': `n$($response | ConvertTo-Json -Depth 99)"
        }

        # Extract the attestation bundle from the GitHub API response
        $bundle = $response.attestations[0].bundle
        if (-not $response.attestations -or $response.attestations.Count -eq 0) {
            throw "No attestation bundles found for sha256:$fileSum in repo '$OrgAndRepository'."
        }

        $lines = $response.attestations | ForEach-Object {
            $_.bundle | ConvertTo-Json -Depth 100 -Compress
        } #| Set-Content -Path $jsonPath -Encoding utf8NoBOM

        $json = $lines -join "`n"

        try {
            [IO.File]::WriteAllText( $jsonPath, $json, [Text.UTF8Encoding]::new($false))
        } catch {
            throw "Failed to write attestation bundle to '$jsonPath': $_"
        }

        if ($DebugPreference -eq "Continue") {
            $bytes = [IO.File]::ReadAllBytes($jsonPath)

            "CR: " + (
                ($bytes | Where-Object { $_ -eq 13 }).Count
            )

            "LF(``n): " + (
                ($bytes | Where-Object { $_ -eq 10 }).Count
            )
        }

        Write-Host "Verifying attestation for file '$Path' with GitHub repository '$OrgAndRepository' with gh command..."
        # TODO: consider unsing Start-Process. Added on PowerShell 7.4 to avoid process environment pollutions
        $Env:GH_NO_UPDATE_NOTIFIER = "1"
        $Env:GH_NO_EXTENSION_UPDATE_NOTIFIER = "1"
        if ($DebugGhCli.IsPresent) {
            $Env:GH_DEBUG = "1"
        }
        gh attestation verify -R $OrgAndRepository $Path -b $jsonPath
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub CLI attestation verification failed for file '$Path'."
        }
    }
}
