Describe 'Export-AzooAzAppServiceAllSetting' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    BeforeEach {
        $script:functionAppLookupCalls = 0
        $script:siteResourceIds = [System.Collections.Generic.List[string]]::new()

        Mock -CommandName Update-AzConfig -ModuleName Azoo -MockWith {
            [pscustomobject]@{}
        }

        Mock -CommandName Test-Path -ModuleName Azoo -MockWith {
            $true
        }

        Mock -CommandName New-Item -ModuleName Azoo -MockWith {
            [pscustomobject]@{}
        }

        Mock -CommandName Get-AzFunctionApp -ModuleName Azoo -MockWith {
            $script:functionAppLookupCalls++
            [pscustomobject]@{
                Name = 'fn-not-expected'
                ResourceGroup = 'rg-not-expected'
                Id = '/subscriptions/sub-x/resourceGroups/rg-not-expected/providers/Microsoft.Web/sites/fn-not-expected'
            }
        }

        Mock -CommandName Get-AzResource -ModuleName Azoo -MockWith {
            param(
                [string]$ResourceId,
                [switch]$ExpandProperties
            )

            if ($ResourceId -match '^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\.Web/sites/[^/]+$') {
                $script:siteResourceIds.Add($ResourceId)
                return [pscustomobject]@{
                    Properties = [pscustomobject]@{
                        serverFarmId = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/serverfarms/asp-a'
                    }
                }
            }

            [pscustomobject]@{
                Properties = [pscustomobject]@{}
            }
        }

        Mock -CommandName Invoke-AzResourceAction -ModuleName Azoo -MockWith {
            [pscustomobject]@{
                Properties = [pscustomobject]@{}
            }
        }

        Mock -CommandName Out-File -ModuleName Azoo -MockWith {
            param(
                [string]$FilePath,
                [string]$Encoding
            )
        }
    }

    It 'accepts Function App resource id directly' {
        $resourceId = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/sites/fn-app-a'

        Export-AzooAzAppServiceAllSetting -ResourceId $resourceId -OutputDirectory $TestDrive

        $script:functionAppLookupCalls | Should -Be 0
        @($script:siteResourceIds) | Should -Contain $resourceId
    }

    It 'accepts Function App resource id from pipeline input' {
        $resourceId = '/subscriptions/sub-b/resourceGroups/rg-b/providers/Microsoft.Web/sites/fn-app-b'

        $resourceId | Export-AzooAzAppServiceAllSetting -OutputDirectory $TestDrive

        $script:functionAppLookupCalls | Should -Be 0
        @($script:siteResourceIds) | Should -Contain $resourceId
    }
}
