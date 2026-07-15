function Invoke-AzooAzPagedQuery {
    <#
    .SYNOPSIS
    Invokes a paged Azure Resource Graph query.

    .DESCRIPTION
    Executes a Search-AzGraph query and automatically handles pagination via skip tokens.
    Returns all items across all pages.

    .PARAMETER Query
    The KQL query string to execute.

    .PARAMETER First
    Number of rows to request per page. Valid range is 1-1000. Defaults to 1000.

    .EXAMPLE
    Invoke-AzooAzPagedQuery -Query "Resources | project id, name, type"

    Executes the query and returns all resource items across all pages.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [ValidateRange(1, 1000)]
        [int]$First = 1000
    )

    $page = Search-AzGraph -First $First -Query $Query -UseTenantScope
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
