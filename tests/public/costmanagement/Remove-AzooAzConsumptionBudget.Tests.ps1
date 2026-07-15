Describe 'Remove-AzooAzConsumptionBudget' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    It 'removes budget by resource id' {
        $script:lastInvocation = $null
        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string]$Path
            )

            $script:lastInvocation = [pscustomobject]@{
                Method = $Method
                Path = $Path
            }

            [pscustomobject]@{
                StatusCode = 204
                Content = ''
            }
        }

        $resourceId = '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly'
        Remove-AzooAzConsumptionBudget -ResourceId $resourceId -Confirm:$false

        $script:lastInvocation.Method | Should -Be 'DELETE'
        $script:lastInvocation.Path | Should -Be '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly?api-version=2023-03-01'
    }

    It 'supports WhatIf and skips REST call' {
        $script:calls = 0
        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            $script:calls++
            [pscustomobject]@{
                StatusCode = 204
                Content = ''
            }
        }

        $resourceId = '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly'
        Remove-AzooAzConsumptionBudget -ResourceId $resourceId -WhatIf

        $script:calls | Should -Be 0
    }

    It 'throws when resource id is not a Microsoft.Consumption budget resource id' {
        $invalidResourceId = '/subscriptions/sub-a/resourceGroups/rg-a'
        { Remove-AzooAzConsumptionBudget -ResourceId $invalidResourceId -Confirm:$false } | Should -Throw '*Microsoft.Consumption budget resource*'
    }
}
