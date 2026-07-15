Describe 'Get-AzooAzConsumptionBudget' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    It 'gets budgets by a single scope and handles continuation links' {
        $script:paths = @()
        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string]$Path
            )

            $script:paths += $Path
            switch -Regex ($Path) {
                '^/subscriptions/sub-a/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/b1","name":"b1","type":"Microsoft.Consumption/budgets","properties":{"category":"Cost"}}],"nextLink":"https://management.azure.com/subscriptions/sub-a/providers/Microsoft.Consumption/budgets?page=2&api-version=2023-03-01"}'
                    }
                }
                '^https://management\.azure\.com/subscriptions/sub-a/providers/Microsoft\.Consumption/budgets\?page=2&api-version=2023-03-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/b2","name":"b2","type":"Microsoft.Consumption/budgets","properties":{"category":"Cost"}}]}'
                    }
                }
                default {
                    throw "Unexpected path: $Path"
                }
            }
        }

        $result = @(Get-AzooAzConsumptionBudget -ScopeId '/subscriptions/sub-a')

        $result.Count | Should -Be 2
        @($result.name) | Should -Be @('b1', 'b2')
        @($script:paths | Where-Object { $_ -match 'page=2' }).Count | Should -Be 1
    }

    It 'gets budgets from discovered scopes by default' {
        Mock -CommandName Get-AzooAzScopes -ModuleName Azoo -MockWith {
            @(
                [pscustomobject]@{ id = '/subscriptions/sub-a' }
                [pscustomobject]@{ id = '/subscriptions/sub-a/resourceGroups/rg-a' }
            )
        }

        Mock -CommandName Get-AzooAzBillingScopes -ModuleName Azoo -MockWith {
            @(
                [pscustomobject]@{ id = '/providers/Microsoft.Billing/billingAccounts/ba1' }
            )
        }

        $script:paths = @()
        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string]$Path
            )

            $script:paths += $Path
            [pscustomobject]@{
                StatusCode = 200
                Content = '{"value":[]}'
            }
        }

        $null = @(Get-AzooAzConsumptionBudget)

        $script:paths.Count | Should -Be 3
        @($script:paths | Where-Object { $_ -match '^/subscriptions/sub-a/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' }).Count | Should -Be 1
        @($script:paths | Where-Object { $_ -match '^/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' }).Count | Should -Be 1
        @($script:paths | Where-Object { $_ -match '^/providers/Microsoft\.Billing/billingAccounts/ba1/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' }).Count | Should -Be 1
    }

    It 'gets a single budget name per scope' {
        $script:paths = @()
        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string]$Path
            )

            $script:paths += $Path
            [pscustomobject]@{
                StatusCode = 200
                Content = '{"id":"/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly","name":"monthly","type":"Microsoft.Consumption/budgets","properties":{"category":"Cost"}}'
            }
        }

        $result = @(Get-AzooAzConsumptionBudget -ScopeId '/subscriptions/sub-a' -Name 'monthly')

        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'monthly'
        $script:paths[0] | Should -Be '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly?api-version=2023-03-01'
    }
}
