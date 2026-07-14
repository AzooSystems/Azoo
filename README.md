# Azoo - Collection of Azure related powershell commands

## Installation

### Regular installation

Please don't use!:

```powershell
Install-Module Azoo -AllowPrerelease -Force
```

```powershell
Install-PSResource Azoo -TrustRepository
```

### Modern installation

List available versions:

```powershell
Find-PSResource -Name Azoo -Version * | Select-Object Version, Prerelease, PublishedDate, UpdatedDate
```

Select the version you want to install. Because PowerShell ecosystem does offer any SCM security at least do following:

* check the release dates. Is to too new?
* then select the version you want to install

Download .nupkg:

```powershell
Save-PSResource -AsNupkg -Name Azoo -Version <version> -SkipDependencyCheck
$f = Get-ChildItem -Filter "Azoo*.nupkg" ; $f
```

Check the Github attestation if using release version:

```powershell
Test-AzooGithubAssestation -OrgAndRepository "AzooSystems/Azoo" -Path ./Azoo.0.0.1.nupkg
```

or not already using the module

```powershell
function Get-FileSha256 {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = $sha.ComputeHash($stream)
            ($bytes | ForEach-Object { $_.ToString("x2") }) -join ''
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

if ($f.Count -ne 1) { Write-Error "Error" }
$file_sum = Get-FileSha256  -Path $f.Name
$url = "https://api.github.com/repos/AzooSystems/Azoo/attestations/sha256:${file_sum}"
$attest_json = (Invoke-RestMethod -Method Get -Uri $url).attestations[0].bundle
$attest_json | ConvertTo-Json -depth 99 | Set-Content -path "$($f.name).json"

gh attestation verify -R "AzooSystems/Azoo" "$($f.name)" -b  "$($f.name).json" "--format=json"
```

Install module

```powershell
$temp = ([System.IO.Path]::GetRandomFileName())
$temp_folder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $temp
New-Item -Path $temp_folder -ItemType Directory > $null
Register-PSResourceRepository -Name $temp -Uri $temp_folder -Trusted
Copy-Item -LiteralPath ./Azoo/Azoo.0.0.1.nupkg -Destination $temp_folder
Find-PSResource -Repository $temp -Name Azoo
Install-PSResource -Repository $temp -Name Azoo
Unregister-PSResourceRepository -name $temp
```

## Testing

Current state:

- Pester configuration is defined in `pester.config.psd1`.
- Test discovery path is `tests`.
- Code coverage path is `src\Azoo`.

Run all tests directly from the tests folder:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path ./tests -Output Detailed"
```

Run tests using `pester.config.psd1` via `New-PesterConfiguration`:

```powershell
pwsh -NoProfile -Command "$cfg = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile ./pester.config.psd1); Invoke-Pester -Configuration $cfg"
```

Run only E2E tests:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path ./tests -TagFilter E2E -Output Detailed"
```

Run only E2E tests using `New-PesterConfiguration`:

```powershell
pwsh -NoProfile -Command "$cfg = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile ./pester.config.psd1); $cfg.Filter.Tag = @('E2E'); Invoke-Pester -Configuration $cfg"
```

Test layout:

- `tests/public/<category>/<Command>.Tests.ps1` for public commands
- `tests/private/<Helper>.Tests.ps1` for private helpers

