<#
.SYNOPSIS
Executes a paged Azure Resource Graph query and returns all results.

.DESCRIPTION
Wraps Search-AzGraph with automatic pagination via skip tokens so callers receive
all matching rows without needing to implement their own loop.

By default the query runs with -UseTenantScope, which searches across all
subscriptions visible to the signed-in identity regardless of the current Az
context subscription selection. Pass -Subscription or -ManagementGroup to narrow
the scope to specific subscriptions or a management group instead.

KNOWN LIMITATIONS (require direct ARM REST API calls to resolve):
  - authorizationScopeFilter: Search-AzGraph does not expose the
    authorizationScopeFilter query option that controls whether resources from
    elevated (RBAC) vs delegated scopes are included. Use the ARM REST endpoint
    /providers/Microsoft.ResourceGraph/resources directly to set this filter.
  - Facet controls: The facet / facetRequest options supported by the Resource
    Graph REST API are not surfaced through Search-AzGraph. Replace this command
    with direct API calls if facet aggregations are needed.

.PARAMETER Query
The KQL query string to execute against Azure Resource Graph.

.PARAMETER First
Number of rows to request per Search-AzGraph page. Valid range is 1-1000.
Defaults to 1000.

.PARAMETER Subscription
One or more subscription IDs to scope the query to. Cannot be combined with
-UseTenantScope or -ManagementGroup.

.PARAMETER ManagementGroup
One or more management group IDs to scope the query to. Cannot be combined with
-UseTenantScope or -Subscription.

.PARAMETER UseTenantScope
Runs the query across all subscriptions in the tenant. This is the default
when neither -Subscription nor -ManagementGroup is specified.

.PARAMETER AllowPartialScope
When set, results from subscriptions where access is partial or restricted are
included rather than causing the request to fail.

.EXAMPLE
Search-AzooAzGraph -Query "Resources | project id, name, type"

Runs the query tenant-wide and returns all matching resources across all pages.

.EXAMPLE
Search-AzooAzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions'" -Subscription 'sub-id-1', 'sub-id-2'

Runs the query scoped to two specific subscriptions.

.EXAMPLE
Search-AzooAzGraph -Query "Resources | where type =~ 'microsoft.keyvault/vaults'" -ManagementGroup 'mg-root'

Runs the query scoped to a management group.
#>
function Search-AzooAzGraph {
    [CmdletBinding(DefaultParameterSetName = 'TenantScope')]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [ValidateRange(1, 1000)]
        [int]$First = 1000,

        [Parameter(ParameterSetName = 'SubscriptionScope')]
        [string[]]$Subscription,

        [Parameter(ParameterSetName = 'ManagementGroupScope')]
        [string[]]$ManagementGroup,

        [Parameter(ParameterSetName = 'TenantScope')]
        [switch]$UseTenantScope,

        [switch]$AllowPartialScope
    )

    $invokeArgs = @{
        First  = $First
        Query  = $Query
    }

    switch ($PSCmdlet.ParameterSetName) {
        'SubscriptionScope'    { $invokeArgs['Subscription']    = $Subscription }
        'ManagementGroupScope' { $invokeArgs['ManagementGroup'] = $ManagementGroup }
        default                { $invokeArgs['UseTenantScope']  = $true }
    }

    if ($AllowPartialScope) {
        $invokeArgs['AllowPartialScope'] = $true
    }

    $page = Search-AzGraph @invokeArgs
    $results = @()

    if ($null -ne $page.Data) {
        $results += @($page.Data)
    }

    while ($page.SkipToken) {
        Write-Verbose "Received skip token: $($page.SkipToken)"
        $skipArgs = $invokeArgs.Clone()
        $skipArgs['SkipToken'] = $page.SkipToken
        $page = Search-AzGraph @skipArgs
        if ($null -ne $page.Data) {
            $results += @($page.Data)
        }
    }

    $results
}
