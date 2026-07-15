Describe 'Get-AzooAzScopes' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    It 'fetches management group, subscription and resource group scopes by default and handles continuation token' {
        $script:Invocations = @()

        Mock -CommandName Search-AzGraph -ModuleName Azoo -MockWith {
            param(
                [int]$First,
                [string]$Query,
                [string]$SkipToken
            )

            $script:Invocations += [pscustomobject]@{
                Query = $Query
                SkipToken = $SkipToken
            }

            if ($Query -notmatch '^ResourceContainers') {
                throw 'Unexpected query table for default scope fetch'
            }

            if (-not $SkipToken) {
                return [pscustomobject]@{
                    Data = @(
                        [pscustomobject]@{ ScopeType = 'ManagementGroup'; id = '/providers/Microsoft.Management/managementGroups/mg-a'; name = 'mg-a'; type = 'microsoft.management/managementgroups'; subscriptionId = $null; tenantId = 'tenant-a' }
                        [pscustomobject]@{ ScopeType = 'Subscription'; id = '/subscriptions/sub-a'; name = 'sub-a'; type = 'microsoft.resources/subscriptions'; subscriptionId = 'sub-a'; tenantId = 'tenant-a' }
                    )
                    SkipToken = 'next-page'
                }
            }

            if ($SkipToken -ne 'next-page') {
                throw "Unexpected continuation token '$SkipToken'"
            }

            [pscustomobject]@{
                Data = @(
                    [pscustomobject]@{ ScopeType = 'ResourceGroup'; id = '/subscriptions/sub-a/resourceGroups/rg-a'; name = 'rg-a'; type = 'microsoft.resources/subscriptions/resourcegroups'; subscriptionId = 'sub-a'; tenantId = 'tenant-a' }
                )
                SkipToken = $null
            }
        }

        $result = @(Get-AzooAzScopes)

        $result.Count | Should -Be 3
        @($result.ScopeType) | Should -Be @('ManagementGroup', 'Subscription', 'ResourceGroup')
        $script:Invocations.Count | Should -Be 2
        @($script:Invocations | Where-Object { $_.SkipToken -eq 'next-page' }).Count | Should -Be 1
    }

    It 'fetches only resources when the resource switch is used' {
        $script:Invocations = @()

        Mock -CommandName Search-AzGraph -ModuleName Azoo -MockWith {
            param(
                [int]$First,
                [string]$Query,
                [string]$SkipToken
            )

            $script:Invocations += [pscustomobject]@{
                Query = $Query
                SkipToken = $SkipToken
            }

            [pscustomobject]@{
                Data = @(
                    [pscustomobject]@{
                        ScopeType = 'Resource'
                        id = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.KeyVault/vaults/kv-a'
                        name = 'kv-a'
                        type = 'microsoft.keyvault/vaults'
                        subscriptionId = 'sub-a'
                        resourceGroup = 'rg-a'
                        location = 'westeurope'
                    }
                )
                SkipToken = $null
            }
        } -ParameterFilter { $Query -match '^Resources' }

        Mock -CommandName Search-AzGraph -ModuleName Azoo -MockWith {
            throw 'Resource container query should not be executed when only resources are requested'
        } -ParameterFilter { $Query -match '^ResourceContainers' }

        $result = @(Get-AzooAzScopes -Resource)

        $result.Count | Should -Be 1
        $result[0].ScopeType | Should -Be 'Resource'
        @($script:Invocations | Where-Object { $_.Query -match '^Resources' }).Count | Should -Be 1
        @($script:Invocations | Where-Object { $_.Query -match '^ResourceContainers' }).Count | Should -Be 0
    }

    It 'applies optional script block filtering to the returned scopes' {
        Mock -CommandName Search-AzGraph -ModuleName Azoo -MockWith {
            [pscustomobject]@{
                Data = @(
                    [pscustomobject]@{ ScopeType = 'ManagementGroup'; id = '/providers/Microsoft.Management/managementGroups/prod'; name = 'prod-mg'; type = 'microsoft.management/managementgroups'; subscriptionId = $null; tenantId = 'tenant-a' }
                    [pscustomobject]@{ ScopeType = 'Subscription'; id = '/subscriptions/dev'; name = 'dev-sub'; type = 'microsoft.resources/subscriptions'; subscriptionId = 'dev'; tenantId = 'tenant-a' }
                )
                SkipToken = $null
            }
        }

        $result = @(Get-AzooAzScopes -FilterScript { $_.name -like 'prod-*' })

        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'prod-mg'
    }
}
