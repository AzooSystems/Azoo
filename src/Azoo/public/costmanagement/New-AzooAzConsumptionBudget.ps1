<#
.SYNOPSIS
Creates or updates an Azure consumption budget at a scope.

.DESCRIPTION
Creates or updates Microsoft.Consumption budget resources by calling ARM REST endpoints
with Invoke-AzRestMethod. This command supports WhatIf and Confirm.

Payload schema documentation: https://learn.microsoft.com/en-us/rest/api/cost-management/budgets/create-or-update?view=rest-cost-management-2025-03-01&tabs=HTTP#budget

Note that some of the properties in the schema are read-only and will be ignored by ARM when creating or updating a budget. For example, currentSpend and forecastSpend are read-only properties that are calculated by the service and cannot be set by the user.

.PARAMETER ScopeId
Enclosing scope resource ID where the budget is created.

.PARAMETER Name
Budget resource name.

.PARAMETER Properties
Budget properties object sent to ARM under the properties field.
Provide a hashtable or PSCustomObject matching Microsoft.Consumption budget schema.

.PARAMETER Tags
Optional tags object sent to ARM.

.EXAMPLE
$properties = @{
    category = 'Cost'
    amount = 100
    timeGrain = 'Monthly'
    timePeriod = @{
        startDate = '2026-01-01T00:00:00Z'
        endDate = '2030-12-31T00:00:00Z'
    }
}
$resourceId = '/subscriptions/00000000-0000-0000-0000-000000000000'
New-AzooAzConsumptionBudget -ScopeId $resourceId -Name 'monthly-budget' -Properties $properties

Creates a budget at the provided scope.
#>
function New-AzooAzConsumptionBudget {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ScopeId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]$Properties,

        [Parameter()]
        [object]$Tags
    )

    $normalizedScope = $ScopeId.Trim()
    if (-not $normalizedScope.StartsWith('/')) {
        $normalizedScope = "/$normalizedScope"
    }
    if ($normalizedScope.Length -gt 1 -and $normalizedScope.EndsWith('/')) {
        $normalizedScope = $normalizedScope.TrimEnd('/')
    }

    $apiVersion = '2023-03-01'
    $resourceId = "$normalizedScope/providers/Microsoft.Consumption/budgets/$Name"
    $path = "$($resourceId)?api-version=$apiVersion"

    $body = @{
        properties = $Properties
    }

    if ($null -ne $Tags) {
        $body.tags = $Tags
    }

    if ($PSCmdlet.ShouldProcess($resourceId, 'Create or update consumption budget')) {
        $payload = $body | ConvertTo-Json -Depth 100
        $response = Invoke-AzRestMethod -Method PUT -Path $path -Payload $payload

        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
            throw "Microsoft.Consumption create/update failed with status code $($response.StatusCode): $path"
        }

        if ($response.Content) {
            $response.Content | ConvertFrom-Json -Depth 100
        }
    }
}
