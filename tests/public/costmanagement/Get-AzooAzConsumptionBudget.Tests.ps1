Describe 'Get-AzooAzConsumptionBudget' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    It 'gets budgets by a single scope via ARM batch requests' {
        $script:batchUrls = @()
        $script:batchInvocations = 0

        Mock -CommandName New-AzureBatchRequest -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string[]]$Url,
                [string]$Name
            )

            $script:batchUrls += $Url
            [pscustomobject]@{
                Name = $Name
                HttpMethod = $Method
                Url = $Url[0]
            }
        }

        Mock -CommandName Invoke-AzureBatchRequest -ModuleName Azoo -MockWith {
            param([object[]]$BatchRequest)
            $script:batchInvocations++

            @(
                [pscustomobject]@{
                    RequestName = 'scope_0'
                    id = '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/b1'
                    name = 'b1'
                    type = 'Microsoft.Consumption/budgets'
                    properties = @{ category = 'Cost' }
                }
                [pscustomobject]@{
                    RequestName = 'scope_0'
                    id = '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/b2'
                    name = 'b2'
                    type = 'Microsoft.Consumption/budgets'
                    properties = @{ category = 'Cost' }
                }
            )
        }

        $result = @(Get-AzooAzConsumptionBudget -ScopeId '/subscriptions/sub-a')

        $result.Count | Should -Be 2
        @($result.name) | Should -Be @('b1', 'b2')
        $script:batchInvocations | Should -Be 1
        $script:batchUrls[0] | Should -Be '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets?api-version=2023-03-01'
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
                [pscustomobject]@{
                    id = '/providers/Microsoft.Billing/billingAccounts/ba1'
                    type = 'Microsoft.Billing/billingAccounts'
                    properties = [pscustomobject]@{ agreementType = 'MicrosoftOnlineServicesProgram' }
                }
                [pscustomobject]@{
                    id = '/providers/Microsoft.Billing/billingAccounts/ba2'
                    type = 'Microsoft.Billing/billingAccounts'
                    properties = [pscustomobject]@{ agreementType = 'EnterpriseAgreement' }
                }
            )
        }

        $script:batchUrls = @()
        Mock -CommandName New-AzureBatchRequest -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string[]]$Url,
                [string]$Name
            )

            $script:batchUrls += $Url
            [pscustomobject]@{
                Name = $Name
                HttpMethod = $Method
                Url = $Url[0]
            }
        }

        Mock -CommandName Invoke-AzureBatchRequest -ModuleName Azoo -MockWith { @() }

        $warnings = @(
            Get-AzooAzConsumptionBudget 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
        )

        $script:batchUrls.Count | Should -Be 3
        @($script:batchUrls | Where-Object { $_ -match '^/subscriptions/sub-a/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' }).Count | Should -Be 1
        @($script:batchUrls | Where-Object { $_ -match '^/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' }).Count | Should -Be 1
        @($script:batchUrls | Where-Object { $_ -match '^/providers/Microsoft\.Billing/billingAccounts/ba1/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' }).Count | Should -Be 0
        @($script:batchUrls | Where-Object { $_ -match '^/providers/Microsoft\.Billing/billingAccounts/ba2/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' }).Count | Should -Be 1
        $warnings.Count | Should -Be 1
        $warnings[0].Message | Should -Match 'MicrosoftOnlineServicesProgram agreement types do not support budgets'
        $warnings[0].Message | Should -Match '/providers/Microsoft.Billing/billingAccounts/ba1'
    }

    It 'includes filtered billing scopes when DisableFilter is used' {
        Mock -CommandName Get-AzooAzScopes -ModuleName Azoo -MockWith {
            @(
                [pscustomobject]@{ id = '/subscriptions/sub-a' }
            )
        }

        Mock -CommandName Get-AzooAzBillingScopes -ModuleName Azoo -MockWith {
            @(
                [pscustomobject]@{
                    id = '/providers/Microsoft.Billing/billingAccounts/ba1'
                    type = 'Microsoft.Billing/billingAccounts'
                    properties = [pscustomobject]@{ agreementType = 'MicrosoftOnlineServicesProgram' }
                }
            )
        }

        $script:batchUrls = @()
        Mock -CommandName New-AzureBatchRequest -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string[]]$Url,
                [string]$Name
            )

            $script:batchUrls += $Url
            [pscustomobject]@{
                Name = $Name
                HttpMethod = $Method
                Url = $Url[0]
            }
        }

        Mock -CommandName Invoke-AzureBatchRequest -ModuleName Azoo -MockWith { @() }

        $warnings = @(
            Get-AzooAzConsumptionBudget -DisableFilter 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
        )

        @($script:batchUrls | Where-Object { $_ -match '^/providers/Microsoft\.Billing/billingAccounts/ba1/providers/Microsoft\.Consumption/budgets\?api-version=2023-03-01$' }).Count | Should -Be 1
        $warnings.Count | Should -Be 0
    }

    It 'gets a single budget name per scope' {
        $script:batchUrls = @()
        Mock -CommandName New-AzureBatchRequest -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string[]]$Url,
                [string]$Name
            )

            $script:batchUrls += $Url
            [pscustomobject]@{
                Name = $Name
                HttpMethod = $Method
                Url = $Url[0]
            }
        }

        Mock -CommandName Invoke-AzureBatchRequest -ModuleName Azoo -MockWith {
            @(
                [pscustomobject]@{
                    RequestName = 'scope_0'
                    id = '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly'
                    name = 'monthly'
                    type = 'Microsoft.Consumption/budgets'
                    properties = @{ category = 'Cost' }
                }
            )
        }

        $result = @(Get-AzooAzConsumptionBudget -ScopeId '/subscriptions/sub-a' -Name 'monthly')

        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'monthly'
        $script:batchUrls[0] | Should -Be '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly?api-version=2023-03-01'
    }

    It 'emits a warning when ARM batch response cannot be mapped back to scope' {
        Mock -CommandName New-AzureBatchRequest -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string[]]$Url,
                [string]$Name
            )

            [pscustomobject]@{
                Name = $Name
                HttpMethod = $Method
                Url = $Url[0]
            }
        }

        Mock -CommandName Invoke-AzureBatchRequest -ModuleName Azoo -MockWith {
            @(
                [pscustomobject]@{
                    RequestName = 'unknown_scope'
                    id = '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/monthly'
                    name = 'monthly'
                    type = 'Microsoft.Consumption/budgets'
                    properties = @{ category = 'Cost' }
                }
            )
        }

        $warnings = @(
            Get-AzooAzConsumptionBudget -ScopeId '/subscriptions/sub-a' -Name 'monthly' 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
        )

        $warnings.Count | Should -BeGreaterOrEqual 1
        $warnings[0].Message | Should -Match 'Unable to map Microsoft.Consumption response to scope'
    }

    It 'gets budgets from InputObject passed as parameter' {
        $script:batchUrls = @()
        Mock -CommandName New-AzureBatchRequest -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string[]]$Url,
                [string]$Name
            )

            $script:batchUrls += $Url
            [pscustomobject]@{
                Name = $Name
                HttpMethod = $Method
                Url = $Url[0]
            }
        }

        Mock -CommandName Invoke-AzureBatchRequest -ModuleName Azoo -MockWith {
            @(
                [pscustomobject]@{
                    RequestName = 'scope_0'
                    id = '/subscriptions/sub-a/providers/Microsoft.Consumption/budgets/b1'
                    name = 'b1'
                    type = 'Microsoft.Consumption/budgets'
                    properties = @{ category = 'Cost' }
                }
            )
        }

        $scopeObjects = @(
            [pscustomobject]@{ id = '/subscriptions/sub-a'; ScopeType = 'Subscription'; subscriptionName = 'Sub A' }
            [pscustomobject]@{ id = '/subscriptions/sub-b'; ScopeType = 'Subscription'; subscriptionName = 'Sub B' }
        )

        $result = @(Get-AzooAzConsumptionBudget -InputObject $scopeObjects)

        $script:batchUrls.Count | Should -Be 2
        @($script:batchUrls | Where-Object { $_ -match '^/subscriptions/sub-a/' }).Count | Should -Be 1
        @($script:batchUrls | Where-Object { $_ -match '^/subscriptions/sub-b/' }).Count | Should -Be 1
        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'b1'
        $result[0].scopeDisplayName | Should -Be 'Sub A'
        $result[0].scopeType | Should -Be 'Subscription'
    }

    It 'gets budgets from InputObject passed via pipeline' {
        $script:batchUrls = @()
        Mock -CommandName New-AzureBatchRequest -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string[]]$Url,
                [string]$Name
            )

            $script:batchUrls += $Url
            [pscustomobject]@{
                Name = $Name
                HttpMethod = $Method
                Url = $Url[0]
            }
        }

        Mock -CommandName Invoke-AzureBatchRequest -ModuleName Azoo -MockWith { @() }

        $scopeObjects = @(
            [pscustomobject]@{ id = '/subscriptions/sub-a' }
            [pscustomobject]@{ id = '/subscriptions/sub-b' }
        )

        $null = @($scopeObjects | Get-AzooAzConsumptionBudget)

        $script:batchUrls.Count | Should -Be 2
        @($script:batchUrls | Where-Object { $_ -match '^/subscriptions/sub-a/' }).Count | Should -Be 1
        @($script:batchUrls | Where-Object { $_ -match '^/subscriptions/sub-b/' }).Count | Should -Be 1
    }

    It 'filters MOSP billing accounts from InputObject by default' {
        $script:batchUrls = @()
        Mock -CommandName New-AzureBatchRequest -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string[]]$Url,
                [string]$Name
            )

            $script:batchUrls += $Url
            [pscustomobject]@{
                Name = $Name
                HttpMethod = $Method
                Url = $Url[0]
            }
        }

        Mock -CommandName Invoke-AzureBatchRequest -ModuleName Azoo -MockWith { @() }

        $scopeObjects = @(
            [pscustomobject]@{
                id = '/providers/Microsoft.Billing/billingAccounts/ba-mosp'
                type = 'Microsoft.Billing/billingAccounts'
                properties = [pscustomobject]@{ agreementType = 'MicrosoftOnlineServicesProgram' }
            }
            [pscustomobject]@{
                id = '/providers/Microsoft.Billing/billingAccounts/ba-ea'
                type = 'Microsoft.Billing/billingAccounts'
                properties = [pscustomobject]@{ agreementType = 'EnterpriseAgreement' }
            }
        )

        $warnings = @(
            Get-AzooAzConsumptionBudget -InputObject $scopeObjects 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
        )

        @($script:batchUrls | Where-Object { $_ -match 'ba-mosp' }).Count | Should -Be 0
        @($script:batchUrls | Where-Object { $_ -match 'ba-ea' }).Count | Should -Be 1
        $warnings.Count | Should -Be 1
        $warnings[0].Message | Should -Match 'MicrosoftOnlineServicesProgram agreement types do not support budgets'
        $warnings[0].Message | Should -Match 'ba-mosp'
    }
}
