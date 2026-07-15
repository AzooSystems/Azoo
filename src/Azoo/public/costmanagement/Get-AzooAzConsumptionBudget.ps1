<#
.SYNOPSIS
Gets Azure consumption budgets from one or more scopes.

.DESCRIPTION
Gets Microsoft.Consumption budget resources by calling ARM batch endpoints through
New-AzureBatchRequest and Invoke-AzureBatchRequest (AzureCommonStuff module).
You can query a single scope, multiple scopes, or allow automatic scope discovery.
Automatic scope discovery uses Get-AzooAzScopes and Get-AzooAzBillingScopes and, by default,
includes management groups, subscriptions, resource groups, and billing scopes.

.PARAMETER ScopeId
Single enclosing scope resource ID to query budgets from.
Examples: /subscriptions/<subscriptionId>, /providers/Microsoft.Management/managementGroups/<managementGroupId>

.PARAMETER ScopeIds
One or more enclosing scope resource IDs to query budgets from.

.PARAMETER Name
Optional budget name. When provided, gets a single budget per scope.
When omitted, lists all budgets per scope.

.PARAMETER DisableFilter
Disables built-in scope filters used during automatic scope discovery.
By default, billing account scopes with agreementType MicrosoftOnlineServicesProgram
are excluded because those agreements do not support budgets.

.EXAMPLE
$resourceId = '/subscriptions/00000000-0000-0000-0000-000000000000'
Get-AzooAzConsumptionBudget -ScopeId $resourceId

Lists all budgets from the given subscription scope.

.EXAMPLE
$resourceIds = @(
    '/subscriptions/00000000-0000-0000-0000-000000000000',
    '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-prod'
)
Get-AzooAzConsumptionBudget -ScopeIds $resourceIds

Lists budgets from multiple scopes.

.EXAMPLE
Get-AzooAzConsumptionBudget -Name 'monthly-budget'

Gets budget named monthly-budget from all discovered scopes.

.EXAMPLE
$budgets = Get-AzooAzConsumptionBudget
$null = $budgets | Expand-ObjectProperty -propertyName properties
$null = $budgets | Expand-ObjectProperty -propertyName timePeriod
$budgets | Select-Object id, category, amount, currentSpend, forecastSpend, startDate, endDate | Out-HtmlView -DefaultSortColumn endDate -PrettifyObject

Gets all budgets from all discovered scopes, expands the properties and timePeriod objects, and outputs a table view of selected budget properties.
#>
function Get-AzooAzConsumptionBudget {
    [CmdletBinding(DefaultParameterSetName = 'AutoScopes')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'SingleScope')]
        [ValidateNotNullOrEmpty()]
        [string]$ScopeId,

        [Parameter(Mandatory, ParameterSetName = 'MultipleScopes')]
        [ValidateNotNullOrEmpty()]
        [string[]]$ScopeIds,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [switch]$DisableFilter
    )

    $apiVersion = '2023-03-01'
    Write-Verbose "Resolving target scopes (parameter set: $($PSCmdlet.ParameterSetName))."
    $targetScopes = switch ($PSCmdlet.ParameterSetName) {
        'SingleScope' { @($ScopeId) }
        'MultipleScopes' { @($ScopeIds) }
        default {
            Write-Verbose 'Fetching Azure resource scopes via Get-AzooAzScopes.'
            $resourceScopes = @(Get-AzooAzScopes | Select-Object -ExpandProperty id)
            Write-Verbose "Fetched $($resourceScopes.Count) resource scope(s)."

            Write-Verbose 'Fetching Azure billing scopes via Get-AzooAzBillingScopes (this may take a while).'
            $billingScopeObjects = @(Get-AzooAzBillingScopes)
            Write-Verbose "Fetched $($billingScopeObjects.Count) billing scope object(s)."

            if (-not $DisableFilter) {
                $ignoredBillingScopeObjects = @(
                    $billingScopeObjects |
                        Where-Object {
                            $_.type -ieq 'Microsoft.Billing/billingAccounts' -and
                            $_.properties -and
                            $_.properties.agreementType -ieq 'MicrosoftOnlineServicesProgram'
                        }
                )

                if ($ignoredBillingScopeObjects.Count -gt 0) {
                    $ignoredScopeIds = @(
                        $ignoredBillingScopeObjects |
                            Where-Object { $_.id } |
                            Select-Object -ExpandProperty id
                    )
                    $ignoredScopeList = if ($ignoredScopeIds.Count -gt 0) {
                        ($ignoredScopeIds -join ', ')
                    } else {
                        '<unknown>'
                    }

                    Write-Warning "Ignoring $($ignoredBillingScopeObjects.Count) billing scope(s) because MicrosoftOnlineServicesProgram agreement types do not support budgets. Use -DisableFilter to include these scopes. Ignored scope(s): $ignoredScopeList"
                }

                $billingScopeObjects = @(
                    $billingScopeObjects |
                        Where-Object {
                            -not (
                                $_.type -ieq 'Microsoft.Billing/billingAccounts' -and
                                $_.properties -and
                                $_.properties.agreementType -ieq 'MicrosoftOnlineServicesProgram'
                            )
                        }
                )
            }

            $billingScopes = @($billingScopeObjects | Select-Object -ExpandProperty id)
            Write-Verbose "Fetched $($billingScopes.Count) billing scope(s)."

            @($resourceScopes + $billingScopes)
        }
    }

    $normalizedScopes = @(
        $targetScopes |
            Where-Object { $_ } |
            ForEach-Object { Normalize-AzooScopeId -Value $_ } |
            Select-Object -Unique
    )
    Write-Verbose "Resolved $($normalizedScopes.Count) unique normalized scope(s)."

    if (-not $normalizedScopes) {
        Write-Verbose 'No scopes resolved. Exiting without issuing requests.'
        return
    }

    $requestScopeMap = @{}
    $batchRequests = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $normalizedScopes.Count; $index++) {
        $scope = $normalizedScopes[$index]
        $path = if ($Name) {
            "$scope/providers/Microsoft.Consumption/budgets/$($Name)?api-version=$apiVersion"
        } else {
            "$scope/providers/Microsoft.Consumption/budgets?api-version=$apiVersion"
        }

        $requestName = "scope_$index"
        $requestScopeMap[$requestName] = $scope

        Write-Verbose "Adding batch request '$requestName' for scope '$scope'."
        $request = New-AzureBatchRequest -Method GET -Url $path -Name $requestName
        foreach ($item in @($request)) {
            $batchRequests.Add($item)
        }
    }

    Write-Verbose "Prepared $($batchRequests.Count) ARM batch request item(s)."
    Write-Verbose 'Invoking ARM batch request.'
    $batchResult = @(Invoke-AzureBatchRequest -BatchRequest $batchRequests)
    Write-Verbose "Received $($batchResult.Count) response item(s) from ARM batch request."
    foreach ($item in $batchResult) {
        $scope = $requestScopeMap[$item.RequestName]
        if (-not $scope) {
            throw "Unable to map Microsoft.Consumption response to scope. RequestName: '$($item.RequestName)'."
        }

        [pscustomobject]@{
            ScopeId = $scope
            id = $item.id
            name = $item.name
            type = $item.type
            eTag = $item.eTag
            properties = $item.properties
        }
    }
}
