<#
.SYNOPSIS
Removes an Azure consumption budget by resource ID.

.DESCRIPTION
Removes a Microsoft.Consumption budget resource by resource ID using ARM REST.
This command supports WhatIf and Confirm.

.PARAMETER ResourceId
Full budget resource ID to delete.
The resource ID must point to a Microsoft.Consumption/budgets resource.

.EXAMPLE
$resourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Consumption/budgets/monthly-budget'
Remove-AzooAzConsumptionBudget -ResourceId $resourceId -Confirm:$false

Removes the budget identified by $resourceId.
#>
function Remove-AzooAzConsumptionBudget {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceId
    )

    process {
        $normalizedResourceId = $ResourceId.Trim()
        if (-not $normalizedResourceId.StartsWith('/')) {
            $normalizedResourceId = "/$normalizedResourceId"
        }
        if ($normalizedResourceId.Length -gt 1 -and $normalizedResourceId.EndsWith('/')) {
            $normalizedResourceId = $normalizedResourceId.TrimEnd('/')
        }

        if ($normalizedResourceId -notmatch '/providers/Microsoft\.Consumption/budgets/[^/]+$') {
            throw "ResourceId must reference a Microsoft.Consumption budget resource: $normalizedResourceId"
        }

        $apiVersion = '2023-03-01'
        $path = "$($normalizedResourceId)?api-version=$apiVersion"
        if ($PSCmdlet.ShouldProcess($normalizedResourceId, 'Remove consumption budget')) {
            $response = Invoke-AzRestMethod -Method DELETE -Path $path
            if ($response.StatusCode -notin @(200, 202, 204)) {
                throw "Microsoft.Consumption delete failed with status code $($response.StatusCode): $path"
            }
        }
    }
}
