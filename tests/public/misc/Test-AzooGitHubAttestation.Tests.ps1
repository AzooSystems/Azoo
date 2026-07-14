Describe 'Test-AzooGitHubAttestation' -Tag 'E2E' {
    BeforeAll {
        $script:SkipE2E = $false
        $script:SkipReason = $null

        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force

        $script:OrgAndRepository = 'AzooSystems/Azoo'
        $script:PackageUrl = 'https://www.powershellgallery.com/api/v2/package/Azoo/0.0.1'
        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("azoo-e2e-" + [System.Guid]::NewGuid().ToString('N'))
        $script:PackagePath = Join-Path $script:TempDir 'Azoo.0.0.1.nupkg'
        $script:JsonPath = "$($script:PackagePath).json"

        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null

        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            $script:SkipE2E = $true
            $script:SkipReason = 'GitHub CLI (gh) was not found in PATH.'
            return
        }

        try {
            Invoke-WebRequest -Uri $script:PackageUrl -OutFile $script:PackagePath -MaximumRedirection 10 -ErrorAction Stop
        }
        catch {
            $script:SkipE2E = $true
            $script:SkipReason = "Package download failed from redirecting PowerShell Gallery URL. Error: $($_.Exception.Message)"
        }
    }

    AfterAll {
        if ($script:TempDir -and (Test-Path -Path $script:TempDir)) {
            #Write-Host "Cleaning up temporary directory: $($script:TempDir)"
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'verifies package attestation from redirected PSGallery URL' {
        if ($script:SkipE2E) {
            Set-ItResult -Skipped -Because $script:SkipReason
            return
        }

        Test-AzooGitHubAttestation -Path $script:PackagePath -OrgAndRepository $script:OrgAndRepository

        $LASTEXITCODE | Should -Be 0
        (Test-Path -Path $script:PackagePath) | Should -BeTrue
        (Test-Path -Path $script:JsonPath) | Should -BeTrue

        { Get-Content -Path $script:JsonPath -Raw | ConvertFrom-Json -ErrorAction Stop } | Should -Not -Throw
    }
}
