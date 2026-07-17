Describe 'New-AzooAzConsumptionBudget' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    It 'creates a budget by scope resource id' {
        $script:lastInvocation = $null
        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string]$Path,
                [string]$Payload
            )

            $script:lastInvocation = [pscustomobject]@{
                Method = $Method
                Path = $Path
                Payload = $Payload
            }

            [pscustomobject]@{
                StatusCode = 201
                Content = '{"id":"/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly","name":"monthly"}'
            }
        }

        $properties = @{
            category = 'Cost'
            amount = 100
            timeGrain = 'Monthly'
            timePeriod = @{
                startDate = '2026-01-01T00:00:00Z'
                endDate = '2030-12-31T00:00:00Z'
            }
        }

        $result = New-AzooAzConsumptionBudget -ScopeId '/subscriptions/sub-a' -Name 'monthly' -Properties $properties -Confirm:$false

        $result.name | Should -Be 'monthly'
        $script:lastInvocation.Method | Should -Be 'PUT'
        $script:lastInvocation.Path | Should -Be '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly?api-version=2023-03-01'
        $script:lastInvocation.Payload | Should -Match '"category"\s*:\s*"Cost"'
    }

    It 'supports WhatIf and skips REST call' {
        $script:calls = 0
        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            $script:calls++
            [pscustomobject]@{
                StatusCode = 200
                Content = '{}'
            }
        }

        $properties = @{
            category = 'Cost'
            amount = 100
            timeGrain = 'Monthly'
            timePeriod = @{
                startDate = '2026-01-01T00:00:00Z'
                endDate = '2030-12-31T00:00:00Z'
            }
        }

        $null = New-AzooAzConsumptionBudget -ScopeId '/subscriptions/sub-a' -Name 'monthly' -Properties $properties -WhatIf

        $script:calls | Should -Be 0
    }
}
