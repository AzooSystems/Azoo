
function Test-AzooGithubAssestation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Path,
        [Parameter(Mandatory)]
        $OrgAndRepository
    )

    $file_sum = Get-FileSha256  -Path $Path
    $url = "https://api.github.com/repos/${OrgAndRepository}/attestations/sha256:${file_sum}"
    $attest_json = (Invoke-RestMethod -Method Get -Uri $url).attestations[0].bundle
    $attest_json | ConvertTo-Json -depth 99 | Set-Content -Force -Path "${Path}.json"

    gh attestation verify -R "AzooSystems/Azoo" $Path -b  "${Path}.json"
}
