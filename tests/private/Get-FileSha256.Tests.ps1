$sha256Vectors = @(
    @{
        Name = 'empty string'
        Bytes = [byte[]]@()
        Expected = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    },
    @{
        Name = 'abc'
        Bytes = [System.Text.Encoding]::ASCII.GetBytes('abc')
        Expected = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    },
    @{
        Name = 'quick brown fox'
        Bytes = [System.Text.Encoding]::ASCII.GetBytes('The quick brown fox jumps over the lazy dog')
        Expected = 'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592'
    }
)

Describe 'Get-FileSha256' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force

        $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("azoo-sha256-" + [System.Guid]::NewGuid().ToString('N'))
        New-Item -Path $script:TempDir -ItemType Directory -Force | Out-Null

        # Test vector sources:
        # - FIPS 180-4 (Secure Hash Standard):
        #   https://csrc.nist.gov/publications/detail/fips/180/4/final
        # - RFC 6234 test vectors for SHA-256:
        #   https://www.rfc-editor.org/rfc/rfc6234
    }

    AfterAll {
        if ($script:TempDir -and (Test-Path -Path $script:TempDir)) {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'matches known SHA-256 vectors for <Name>' -ForEach $sha256Vectors {
        param(
            $Name,
            [byte[]]$Bytes,
            [string]$Expected
        )

        $filePath = Join-Path $script:TempDir ("$Name.bin")
        [System.IO.File]::WriteAllBytes($filePath, $Bytes)

        $actual = InModuleScope -ModuleName Azoo -Parameters @{ Path = $filePath } -ScriptBlock {
            param($Path)
            Get-FileSha256 -Path $Path
        }

        $actual | Should -Be $Expected
        $actual.Length | Should -Be 64
        $actual | Should -Match '^[0-9a-f]{64}$'
    }

    It 'throws when file path does not exist' {
        $missingPath = Join-Path $script:TempDir 'missing.bin'

        {
            InModuleScope -ModuleName Azoo -Parameters @{ Path = $missingPath } -ScriptBlock {
                param($Path)
                Get-FileSha256 -Path $Path
            }
        } | Should -Throw
    }
}