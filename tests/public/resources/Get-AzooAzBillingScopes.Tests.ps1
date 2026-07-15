Describe 'Get-AzooAzBillingScopes' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    It 'fetches billing account, billing profile and invoice section scopes by default and handles continuation' {
        $script:paths = @()

        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string]$Path
            )

            $script:paths += $Path

            switch -Regex ($Path) {
                '/providers/Microsoft\.Billing/billingAccounts\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/providers/Microsoft.Billing/billingAccounts/ba1","name":"ba1","type":"Microsoft.Billing/billingAccounts","properties":{"displayName":"Billing Account 1"}}]}'
                    }
                }
                '/providers/Microsoft\.Billing/billingAccounts/ba1/billingProfiles\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/providers/Microsoft.Billing/billingAccounts/ba1/billingProfiles/bp1","name":"bp1","type":"Microsoft.Billing/billingProfiles","properties":{"displayName":"Billing Profile 1"}}],"nextLink":"https://management.azure.com/providers/Microsoft.Billing/billingAccounts/ba1/billingProfiles?page=2&api-version=2024-04-01"}'
                    }
                }
                'https://management\.azure\.com/providers/Microsoft\.Billing/billingAccounts/ba1/billingProfiles\?page=2&api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/providers/Microsoft.Billing/billingAccounts/ba1/billingProfiles/bp2","name":"bp2","type":"Microsoft.Billing/billingProfiles","properties":{"displayName":"Billing Profile 2"}}]}'
                    }
                }
                '/providers/Microsoft\.Billing/billingAccounts/ba1/billingProfiles/bp1/invoiceSections\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/providers/Microsoft.Billing/billingAccounts/ba1/billingProfiles/bp1/invoiceSections/is1","name":"is1","type":"Microsoft.Billing/invoiceSections","properties":{"displayName":"Invoice Section 1"}}]}'
                    }
                }
                '/providers/Microsoft\.Billing/billingAccounts/ba1/billingProfiles/bp2/invoiceSections\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/providers/Microsoft.Billing/billingAccounts/ba1/billingProfiles/bp2/invoiceSections/is2","name":"is2","type":"Microsoft.Billing/invoiceSections","properties":{"displayName":"Invoice Section 2"}}]}'
                    }
                }
                default {
                    throw "Unexpected billing path: $Path"
                }
            }
        }

        $result = @(Get-AzooAzBillingScopes)

        @($result.ScopeType) | Should -Be @(
            'BillingAccount',
            'BillingProfile',
            'BillingProfile',
            'InvoiceSection',
            'InvoiceSection'
        )
        @($script:paths | Where-Object { $_ -match 'page=2' }).Count | Should -Be 1
    }

    It 'fetches only customer scopes when customer switch is used' {
        $script:paths = @()

        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string]$Path
            )

            $script:paths += $Path

            switch -Regex ($Path) {
                '/providers/Microsoft\.Billing/billingAccounts\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/providers/Microsoft.Billing/billingAccounts/ba1","name":"ba1","type":"Microsoft.Billing/billingAccounts","properties":{"displayName":"Billing Account 1"}}]}'
                    }
                }
                '/providers/Microsoft\.Billing/billingAccounts/ba1/customers\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/providers/Microsoft.Billing/billingAccounts/ba1/customers/c1","name":"c1","type":"Microsoft.Billing/customers","properties":{"displayName":"Customer 1"}}]}'
                    }
                }
                default {
                    throw "Unexpected billing path: $Path"
                }
            }
        }

        $result = @(Get-AzooAzBillingScopes -Customer)

        $result.Count | Should -Be 1
        $result[0].ScopeType | Should -Be 'Customer'
        @($script:paths | Where-Object { $_ -match 'billingProfiles' }).Count | Should -Be 0
    }

    It 'applies optional script block filtering to returned billing scopes' {
        Mock -CommandName Invoke-AzRestMethod -ModuleName Azoo -MockWith {
            param(
                [string]$Method,
                [string]$Path
            )

            switch -Regex ($Path) {
                '/providers/Microsoft\.Billing/billingAccounts\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[{"id":"/providers/Microsoft.Billing/billingAccounts/prod","name":"prod","type":"Microsoft.Billing/billingAccounts","properties":{"displayName":"prod-account"}},{"id":"/providers/Microsoft.Billing/billingAccounts/dev","name":"dev","type":"Microsoft.Billing/billingAccounts","properties":{"displayName":"dev-account"}}]}'
                    }
                }
                '/providers/Microsoft\.Billing/billingAccounts/prod/billingProfiles\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[]}'
                    }
                }
                '/providers/Microsoft\.Billing/billingAccounts/dev/billingProfiles\?api-version=2024-04-01$' {
                    return [pscustomobject]@{
                        StatusCode = 200
                        Content = '{"value":[]}'
                    }
                }
                default {
                    throw "Unexpected billing path: $Path"
                }
            }
        }

        $result = @(Get-AzooAzBillingScopes -BillingAccount -FilterScript { $_.name -eq 'prod' })

        $result.Count | Should -Be 1
        $result[0].name | Should -Be 'prod'
        $result[0].ScopeType | Should -Be 'BillingAccount'
    }
}
