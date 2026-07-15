<#
.SYNOPSIS
Gets Azure consumption budgets from one or more scopes.

.DESCRIPTION
Gets Microsoft.Consumption budget resources by calling ARM REST endpoints with Invoke-AzRestMethod.
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
        [string]$Name
    )

    function Invoke-ConsumptionGetPaged {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        $nextPath = $Path
        $items = @()

        while ($nextPath) {
            $response = Invoke-AzRestMethod -Method GET -Path $nextPath
            if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
                throw "Microsoft.Consumption request failed with status code $($response.StatusCode): $nextPath"
            }

            $payload = $response.Content | ConvertFrom-Json -Depth 100
            if ($payload.value) {
                $items += @($payload.value)
            }

            $nextPath = $payload.nextLink
        }

        $items
    }

    function Normalize-ScopeId {
        param(
            [Parameter(Mandatory)]
            [string]$Value
        )

        $normalized = $Value.Trim()
        if (-not $normalized.StartsWith('/')) {
            $normalized = "/$normalized"
        }

        if ($normalized.Length -gt 1 -and $normalized.EndsWith('/')) {
            $normalized = $normalized.TrimEnd('/')
        }

        $normalized
    }

    $apiVersion = '2023-03-01'
    $targetScopes = switch ($PSCmdlet.ParameterSetName) {
        'SingleScope' { @($ScopeId) }
        'MultipleScopes' { @($ScopeIds) }
        default {
            @(
                Get-AzooAzScopes | Select-Object -ExpandProperty id
                Get-AzooAzBillingScopes | Select-Object -ExpandProperty id
            )
        }
    }

    $normalizedScopes = $targetScopes |
        Where-Object { $_ } |
        ForEach-Object { Normalize-ScopeId -Value $_ } |
        Select-Object -Unique

    foreach ($scope in $normalizedScopes) {
        if ($Name) {
            $path = "$scope/providers/Microsoft.Consumption/budgets/$($Name)?api-version=$apiVersion"
            $response = Invoke-AzRestMethod -Method GET -Path $path
            if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
                throw "Microsoft.Consumption request failed with status code $($response.StatusCode): $path"
            }

            $item = $response.Content | ConvertFrom-Json -Depth 100
            if ($item) {
                [pscustomobject]@{
                    ScopeId = $scope
                    id = $item.id
                    name = $item.name
                    type = $item.type
                    eTag = $item.eTag
                    properties = $item.properties
                }
            }

            continue
        }

        $path = "$scope/providers/Microsoft.Consumption/budgets?api-version=$apiVersion"
        $budgets = Invoke-ConsumptionGetPaged -Path $path
        foreach ($item in $budgets) {
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
}
