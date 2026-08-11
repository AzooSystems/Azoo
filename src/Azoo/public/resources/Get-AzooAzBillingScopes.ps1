<#
.SYNOPSIS
Gets Azure billing scope objects from Microsoft.Billing REST APIs.

.DESCRIPTION
Fetches billing scopes by calling Microsoft.Billing ARM endpoints with Invoke-AzRestMethod.
By default, it returns billing account, billing profile, and invoice section scopes.
Use scope switches to limit returned scope types, and use FilterScript for optional post-filtering.

.PARAMETER BillingAccount
Include billing account scopes.

.PARAMETER BillingProfile
Include billing profile scopes.

.PARAMETER InvoiceSection
Include invoice section scopes.

.PARAMETER Customer
Include customer scopes.

.PARAMETER FilterScript
Optional script block used to filter returned scope objects.

.EXAMPLE
Get-AzooAzBillingScopes

Returns billing accounts, billing profiles, and invoice sections.

.EXAMPLE
Get-AzooAzBillingScopes -BillingAccount -Customer

Returns billing accounts and customers.

.EXAMPLE
Get-AzooAzBillingScopes -InvoiceSection -FilterScript { $_.name -like '*prod*' }

Returns invoice section scopes filtered by name.
#>
function Get-AzooAzBillingScopes {
    [CmdletBinding()]
    param(
        [switch]$BillingAccount,
        [switch]$BillingProfile,
        [switch]$InvoiceSection,
        [switch]$Customer,
        [scriptblock]$FilterScript
    )

    function Invoke-BillingPagedRequest {
        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $nextUri = $Uri
        $items = @()

        while ($nextUri) {
            Write-Verbose "Requesting: $nextUri"
            $response = Invoke-AzRestMethod -Method GET -Path $nextUri

            if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
                throw "Microsoft.Billing request failed with status code $($response.StatusCode): $nextUri"
            }

            $payload = $response.Content | ConvertFrom-Json
            if ($payload.value) {
                $items += @($payload.value)
            }

            $nextUri = $payload.nextLink
        }

        $items
    }

    $hasScopeSwitch = @('BillingAccount', 'BillingProfile', 'InvoiceSection', 'Customer').
        Where({ $PSBoundParameters.ContainsKey($_) }).
        Count -gt 0

    $fetchBillingAccounts = if ($hasScopeSwitch) { $BillingAccount.IsPresent } else { $true }
    $fetchBillingProfiles = if ($hasScopeSwitch) { $BillingProfile.IsPresent } else { $true }
    $fetchInvoiceSections = if ($hasScopeSwitch) { $InvoiceSection.IsPresent } else { $true }
    $fetchCustomers = if ($hasScopeSwitch) { $Customer.IsPresent } else { $false }

    $apiVersion = '2024-04-01'
    $scopes = @()

    $billingAccounts = Invoke-BillingPagedRequest -Uri "/providers/Microsoft.Billing/billingAccounts?api-version=$apiVersion"

    if ($fetchBillingAccounts) {
        $scopes += $billingAccounts | ForEach-Object {
            [pscustomobject]@{
                ScopeType          = 'BillingAccount'
                id                 = $_.id
                name               = $_.name
                displayName        = $_.properties.displayName
                scopeDisplayName   = $_.properties.displayName
                type               = $_.type
                billingAccountName = $_.name
                properties         = $_.properties
            }
        }
    }

    foreach ($account in $billingAccounts) {
        $accountName = $account.name

        if ($fetchBillingProfiles -or $fetchInvoiceSections) {
            $profiles = Invoke-BillingPagedRequest -Uri "/providers/Microsoft.Billing/billingAccounts/$accountName/billingProfiles?api-version=$apiVersion"

            if ($fetchBillingProfiles) {
                $scopes += $profiles | ForEach-Object {
                    [pscustomobject]@{
                        ScopeType          = 'BillingProfile'
                        id                 = $_.id
                        name               = $_.name
                        displayName        = $_.properties.displayName
                        scopeDisplayName   = $_.properties.displayName
                        type               = $_.type
                        billingAccountName = $accountName
                        billingProfileName = $_.name
                        properties         = $_.properties
                    }
                }
            }

            if ($fetchInvoiceSections) {
                foreach ($billingProfile in $profiles) {
                    $profileName = $billingProfile.name
                    $sections = Invoke-BillingPagedRequest -Uri "/providers/Microsoft.Billing/billingAccounts/$accountName/billingProfiles/$profileName/invoiceSections?api-version=$apiVersion"

                    $scopes += $sections | ForEach-Object {
                        [pscustomobject]@{
                            ScopeType          = 'InvoiceSection'
                            id                 = $_.id
                            name               = $_.name
                            displayName        = $_.properties.displayName
                            scopeDisplayName   = $_.properties.displayName
                            type               = $_.type
                            billingAccountName = $accountName
                            billingProfileName = $profileName
                            properties         = $_.properties
                        }
                    }
                }
            }
        }

        if ($fetchCustomers) {
            $customers = Invoke-BillingPagedRequest -Uri "/providers/Microsoft.Billing/billingAccounts/$accountName/customers?api-version=$apiVersion"
            $scopes += $customers | ForEach-Object {
                [pscustomobject]@{
                    ScopeType          = 'Customer'
                    id                 = $_.id
                    name               = $_.name
                    displayName        = $_.properties.displayName
                    scopeDisplayName   = $_.properties.displayName
                    type               = $_.type
                    billingAccountName = $accountName
                    billingProfileName = $null
                    properties         = $_.properties
                }
            }
        }
    }

    if ($FilterScript) {
        $scopes = $scopes | Where-Object -FilterScript $FilterScript
    }

    $scopes
}
