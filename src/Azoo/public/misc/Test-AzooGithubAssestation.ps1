
function Test-AzooGithubAssestation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OrgAndRepository
    )

    $fileSum = Get-FileSha256 -Path $Path
    $url = "https://api.github.com/repos/$OrgAndRepository/attestations/sha256:$fileSum"
    $jsonPath = "${Path}.json"

    if ($PSCmdlet.ShouldProcess($Path, "Verify GitHub attestation and write bundle to '$jsonPath'")) {
        $response = Invoke-RestMethod -Method Get -Uri $url -ErrorAction Stop
        $bundle = $response.attestations[0].bundle
        if (-not $bundle) {
            throw "No attestation bundle found for sha256:$fileSum in repo '$OrgAndRepository'."
        }

        $json = $bundle | ConvertTo-Json -Depth 99
        [System.IO.File]::WriteAllText($jsonPath, $json, [System.Text.UTF8Encoding]::new($false))

        gh attestation verify -R $OrgAndRepository $Path -b $jsonPath
    }
}
