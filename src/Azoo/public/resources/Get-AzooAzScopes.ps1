<#
.SYNOPSIS
Gets Azure scope objects from Azure Resource Graph.

.DESCRIPTION
Fetches scope objects from ResourceContainers and/or Resources with Search-AzGraph.
By default, it returns management group, subscription, and resource group scopes.
Use scope switches to limit results, and use FilterScript for optional post-filtering.

.PARAMETER ManagementGroup
Include management group scopes.

.PARAMETER Subscription
Include subscription scopes.

.PARAMETER ResourceGroup
Include resource group scopes.

.PARAMETER Resource
Include resource scopes from the Resources table.

.PARAMETER First
Number of rows to request per Search-AzGraph page. Valid range is 1-1000.

.PARAMETER FilterScript
Optional script block used to filter the returned scope objects.

.EXAMPLE
Get-AzooAzScopes

Returns management group, subscription, and resource group scopes.

.EXAMPLE
Get-AzooAzScopes -Subscription -ResourceGroup

Returns only subscription and resource group scopes.

.EXAMPLE
Get-AzooAzScopes -Resource -FilterScript { $_.type -like 'microsoft.keyvault/*' }

Returns resource scopes and filters to Key Vault resource types.
#>
function Get-AzooAzScopes {
    [CmdletBinding()]
    param(
        [switch]$ManagementGroup,
        [switch]$Subscription,
        [switch]$ResourceGroup,
        [switch]$Resource,
        [ValidateRange(1, 1000)]
        [int]$First = 1000,
        [scriptblock]$FilterScript
    )

    function Invoke-PagedAzGraphQuery {
        param(
            [Parameter(Mandatory)]
            [string]$Query
        )

        $page = Search-AzGraph -First $First -Query $Query
        $results = @()

        if ($null -ne $page.Data) {
            $results += @($page.Data)
        }

        while ($page.SkipToken) {
            Write-Verbose "Received skip token: $($page.SkipToken)"
            $page = Search-AzGraph -First $First -Query $Query -SkipToken $page.SkipToken
            if ($null -ne $page.Data) {
                $results += @($page.Data)
            }
        }

        $results
    }

    $hasScopeSwitch = @('ManagementGroup', 'Subscription', 'ResourceGroup', 'Resource').
        Where({ $PSBoundParameters.ContainsKey($_) }).
        Count -gt 0

    $fetchManagementGroups = if ($hasScopeSwitch) { $ManagementGroup.IsPresent } else { $true }
    $fetchSubscriptions = if ($hasScopeSwitch) { $Subscription.IsPresent } else { $true }
    $fetchResourceGroups = if ($hasScopeSwitch) { $ResourceGroup.IsPresent } else { $true }
    $fetchResources = if ($hasScopeSwitch) { $Resource.IsPresent } else { $false }

    $scopes = @()

    if ($fetchManagementGroups -or $fetchSubscriptions -or $fetchResourceGroups) {
        $containerTypes = @()

        if ($fetchManagementGroups) {
            $containerTypes += "'microsoft.management/managementgroups'"
        }

        if ($fetchSubscriptions) {
            $containerTypes += "'microsoft.resources/subscriptions'"
        }

        if ($fetchResourceGroups) {
            $containerTypes += "'microsoft.resources/subscriptions/resourcegroups'"
        }

        $containerTypeFilter = $containerTypes -join ', '
        $containerQuery = @"
ResourceContainers
| where type in~ ($containerTypeFilter)
| extend ScopeType = case(
    type =~ 'microsoft.management/managementgroups', 'ManagementGroup',
    type =~ 'microsoft.resources/subscriptions', 'Subscription',
    type =~ 'microsoft.resources/subscriptions/resourcegroups', 'ResourceGroup',
    'Unknown')
| project ScopeType, id, name, type, subscriptionId, tenantId
"@

        $scopes += Invoke-PagedAzGraphQuery -Query $containerQuery
    }

    if ($fetchResources) {
        $resourceQuery = @'
Resources
| project ScopeType = 'Resource', id, name, type, subscriptionId, resourceGroup, location
'@
        $scopes += Invoke-PagedAzGraphQuery -Query $resourceQuery
    }

    if ($FilterScript) {
        $scopes = $scopes | Where-Object -FilterScript $FilterScript
    }

    $scopes
}
