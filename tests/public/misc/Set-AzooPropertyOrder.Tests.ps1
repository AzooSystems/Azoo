Describe 'Set-AzooPropertyOrder and Get-AzooPropertyOrder' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    It 'passes Select-Object output through unchanged and records order for tag x' {
        $data = [pscustomobject]@{
            x = 1
            y = 2
            z = 3
        }

        $selected = $data | Select-Object x, z, y
        $result = @($selected | Set-AzooPropertyOrder -Tag 'x')

        $result.Count | Should -Be 1
        [object]::ReferenceEquals($selected, $result[0]) | Should -BeTrue
        @($result[0].PSObject.Properties.Name) | Should -Be @('x', 'z', 'y')
        $result[0].x | Should -Be 1
        $result[0].z | Should -Be 3
        $result[0].y | Should -Be 2

        $order = Get-AzooPropertyOrder -Tag 'x'
        @($order) | Should -Be @('x', 'z', 'y')
    }

    It 'keeps Select-Object property order for tabular data rows' {
        $data = @(
            [pscustomobject]@{ x = 'a'; y = 'b'; z = 'c' }
            [pscustomobject]@{ x = 'd'; y = 'e'; z = 'f' }
        )

        $tag = 'tabular-' + [System.Guid]::NewGuid().ToString('N')
        $result = @($data | Select-Object x, z, y | Set-AzooPropertyOrder -Tag $tag)

        $result.Count | Should -Be 2
        foreach ($row in $result) {
            @($row.PSObject.Properties.Name) | Should -Be @('x', 'z', 'y')
        }

        $order = Get-AzooPropertyOrder -Tag $tag
        @($order) | Should -Be @('x', 'z', 'y')
    }

    It 'merges property order from raw tabular rows without Select-Object' {
        $data = @(
            [pscustomobject]@{ b = 'a'; d = 'b'; e = 'c' }
            [pscustomobject]@{ c = 'd'; d = 'e'; e = 'f' }
            [pscustomobject]@{ a = 'd'; b = 'e'; f = 'f' }
        )

        $tag = 'raw-tabular-' + [System.Guid]::NewGuid().ToString('N')
        $result = @($data | Set-AzooPropertyOrder -Tag $tag)

        $result.Count | Should -Be 3
        [object]::ReferenceEquals($data[0], $result[0]) | Should -BeTrue
        [object]::ReferenceEquals($data[1], $result[1]) | Should -BeTrue
        [object]::ReferenceEquals($data[2], $result[2]) | Should -BeTrue

        @($result[0].PSObject.Properties.Name) | Should -Be @('b', 'd', 'e')
        @($result[1].PSObject.Properties.Name) | Should -Be @('c', 'd', 'e')
        @($result[2].PSObject.Properties.Name) | Should -Be @('a', 'b', 'f')

        $order = Get-AzooPropertyOrder -Tag $tag
        @($order) | Should -Be @('a', 'b', 'f', 'c', 'd', 'e')
    }
}
