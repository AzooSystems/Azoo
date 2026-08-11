<#
.SYNOPSIS
Exports Azure Function App settings and related configuration to files.

.DESCRIPTION
Exports site, server farm, and known configuration payloads for one or more
App Service site resources. Targets can be provided by name/resource group, by resource ID,
or by pipeline input objects.

.PARAMETER SiteName
Name of the site resource when using the ByName parameter set.

.PARAMETER SiteResourceGroupName
Resource group name of the site resource when using the ByName parameter set.

.PARAMETER ResourceId
One or more App Service site resource IDs.
Accepts pipeline input by value and by property name.
Example:
/subscriptions/<subscriptionId>/resourceGroups/<resourceGroup>/providers/Microsoft.Web/sites/<siteName>

.PARAMETER InputObject
Input object for site resource resolution. When present, the function tries to
resolve from Id/ResourceId first, then falls back to Name/ResourceGroup for
site objects.

.PARAMETER OutputDirectory
Directory where the exported files are written.

.PARAMETER IncludeDiagnostics
Includes diagnostic settings export.

.PARAMETER IncludePublishingProfile
Includes publishing profile export.

.PARAMETER IncludeSlots
Includes deployment slot export.

.PARAMETER Force
Passes Force to list action resource calls.

.EXAMPLE
$fas = Get-AzFunctionApp
$fas[0].Id | Export-AzooAzAppServiceAllSetting -OutputDirectory "gg" -IncludeDiagnostics -IncludePublishingProfile -IncludeSlots

.EXAMPLE
$fas = Get-AzFunctionApp
$fas | Export-AzooAzAppServiceAllSetting -OutputDirectory "gg" -IncludeDiagnostics -IncludePublishingProfile -IncludeSlots

.EXAMPLE
$apps = Get-AzWebApp
$apps | Export-AzooAzAppServiceAllSetting -OutputDirectory "gg" -IncludeDiagnostics -IncludePublishingProfile -IncludeSlots

.EXAMPLE
Export-AzooAzAppServiceAllSetting -OutputDirectory "gg" -IncludeDiagnostics -IncludePublishingProfile -IncludeSlots

#>
function Export-AzooAzAppServiceAllSetting {
    [CmdletBinding(DefaultParameterSetName = 'ByInputObject')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [Alias('FunctionAppName')]
        [string] $SiteName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [Alias('FunctionAppResourcegroupName')]
        [string] $SiteResourceGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string[]] $ResourceId,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = 'ByInputObject')]
        [object] $InputObject,

        [Parameter(Mandatory = $true)]
        [string] $OutputDirectory,

        [switch] $IncludeDiagnostics,
        [switch] $IncludePublishingProfile,
        [switch] $IncludeSlots,
        [switch] $Force
    )

    begin {
        $appsToExport = @()

        function Resolve-AzooFunctionAppFromResourceId {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Value
            )

            $resourceIdPattern = '^/subscriptions/(?<SubscriptionId>[^/]+)/resourceGroups/(?<ResourceGroup>[^/]+)/providers/Microsoft\.Web/sites/(?<Name>[^/]+)$'
            if ($Value -match $resourceIdPattern) {
                [PSCustomObject]@{
                    Name = $Matches.Name
                    ResourceGroup = $Matches.ResourceGroup
                    SubscriptionId = $Matches.SubscriptionId
                    SiteResourceId = $Value
                }
                return
            }

            $null
        }

        $knownConfigTypes = @(
            "basicPublishingCredentialsPolicies",
            "errorpages",
            "config/authsettings",
            "config/authsettingsV2",
            "config/configreferences/appsettings",
            "config/configreferences/connectionstrings"
            "config/logs",
            "config/slotConfigNames",
            "config/configreferences/appsettings",
            "config/web"
        )

        $knownConfigTypesWithListAction = @(
            "config/azureStorageAccounts",
            "config/appsettings"
            "config/connectionstrings",
            "config/metadata"
        )

        if (-not (Test-Path $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }

        Update-AzConfig -Scope Process -DisplayBreakingChangeWarning $false | Out-Null
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByResourceId') {
            foreach ($id in @($ResourceId)) {
                if (-not $id) {
                    continue
                }

                $resolvedApp = Resolve-AzooFunctionAppFromResourceId -Value $id
                if ($null -ne $resolvedApp) {
                    $appsToExport += $resolvedApp
                } else {
                    Write-Warning "Skipping invalid App Service site resource ID: $id"
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'ByInputObject' -and $InputObject) {
            $candidateId = $null
            if ($InputObject -is [string]) {
                $candidateId = $InputObject
            }
            else {
                $candidateId = $InputObject.Id
                if (-not $candidateId) {
                    $candidateId = $InputObject.ResourceId
                }
            }

            if ($candidateId) {
                $resolvedApp = Resolve-AzooFunctionAppFromResourceId -Value $candidateId
                if ($null -ne $resolvedApp) {
                    $appsToExport += $resolvedApp
                } else {
                    Write-Warning "Skipping input object with invalid App Service site resource ID: $candidateId"
                }
            } else {
                Write-Warning "Skipping non-site input: $($InputObject.Name). No resolveable Id/ResourceId property found."
            }
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            # Get-AzWebApp returns both Web Apps and Function Apps
            $app = Get-AzWebApp -Name $SiteName -ResourceGroupName $SiteResourceGroupName -ErrorAction Stop
            if ($Null -eq $app) {
                throw "Could not find given site resource"
            }
            Write-Verbose $app
            $resolvedByName = Resolve-AzooFunctionAppFromResourceId -Value $app.Id

            $appsToExport += [PSCustomObject]@{
                Name = $app.Name
                ResourceGroup = $app.ResourceGroup
                SiteResourceId = $app.Id
                SubscriptionId = if ($resolvedByName) { $resolvedByName.SubscriptionId } else { $null }
            }
            Write-Verbose $appsToExport[0]
        }

        $appsToExport = $appsToExport | Sort-Object SiteResourceId, Name -Unique

        foreach ($app in $appsToExport) {
            $appDir = Join-Path $OutputDirectory $app.Name
            if (-not (Test-Path $appDir)) {
                New-Item -ItemType Directory -Path $appDir | Out-Null
            }

            $siteResourceId = $app.SiteResourceId
            if (-not $siteResourceId) {
                $subscriptionId = $app.SubscriptionId

                if (-not $subscriptionId -and $app.Subscription -and $app.Subscription.Id) {
                    $subscriptionId = $app.Subscription.Id
                }

                if (-not $subscriptionId -and $app.Id) {
                    $resolvedFromId = Resolve-AzooFunctionAppFromResourceId -Value $app.Id
                    if ($resolvedFromId) {
                        $subscriptionId = $resolvedFromId.SubscriptionId
                    }
                }

                if (-not $subscriptionId) {
                    throw "Could not resolve subscription ID from input for app '$($app.Name)'. Provide -ResourceId or pipeline input containing a site resource ID."
                }

                $siteResourceId = "/subscriptions/$subscriptionId/resourceGroups/$($app.ResourceGroup)/providers/Microsoft.Web/sites/$($app.Name)"
            }

            # Base site config
            try {
                Write-Host "=========="
                Write-Host "Fetching data for $siteResourceId"
                Write-Host "=========="
                $site = Get-AzResource -ResourceId $siteResourceId -ExpandProperties -ErrorAction Stop
                $site | ConvertTo-Json -Depth 10 | Out-File (Join-Path $appDir 'site.json') -Encoding UTF8
                Write-Host "✅ $($app.Name): site.json"
            } catch {
                Write-Warning "❌ $($app.Name): Failed to get site config."
            }

            # ASP
            try {
                $aspResourceId = $site.Properties.serverFarmId
                Write-Host "=========="
                Write-Host "Fetching data for $aspResourceId"
                Write-Host "=========="
                $site = Get-AzResource -ResourceId $aspResourceId -ExpandProperties -ErrorAction Stop
                $site.Properties | ConvertTo-Json -Depth 10 | Out-File (Join-Path $appDir 'serverfarm.json') -Encoding UTF8
                Write-Host "✅ $($app.Name): serverfarm.json"
            } catch {
                Write-Warning "❌ $($app.Name): Failed to get serverfarm config."
            }


            foreach ($cfg in $knownConfigTypesWithListAction) {
                try {
                    $filename = $cfg.Replace("config/", "").Replace("/", "_")
                    $resId = "$siteResourceId/$cfg"
                    Write-Verbose "Fetching data with list action for $resId"
                    $cfgRes = Invoke-AzResourceAction -ResourceId $resId -Action "list" -ErrorAction Stop -Force:$True
                    $cfgRes.Properties | ConvertTo-Json -Depth 10 | Out-File (Join-Path $appDir "$filename.json") -Encoding UTF8
                    Write-Host "✅ $($app.Name): $filename.json"
                } catch {
                    Write-Verbose "⚠️ $($app.Name): $cfg config not found"
                }
            }

            # All known config types
            foreach ($cfg in $knownConfigTypes) {
                try {
                    $filename = $cfg.Replace("config/", "").Replace("/", "_")
                    $resId = "$siteResourceId/$cfg"
                    Write-Verbose "Fetching data for $resId"
                    $cfgRes = Get-AzResource -ResourceId $resId -ExpandProperties -ErrorAction Stop
                    if ($cfg -eq "basicPublishingCredentialsPolicies") {
                        $cfgRes |  Select-Object name, Properties | ConvertTo-Json -Depth 10 | Out-File (Join-Path $appDir "$filename.json") -Encoding UTF8
                    } else {
                        $cfgRes.Properties | ConvertTo-Json -Depth 10 | Out-File (Join-Path $appDir "$filename.json") -Encoding UTF8
                    }
                    Write-Host "✅ $($app.Name): $filename.json"
                } catch {
                    Write-Verbose "⚠️ $($app.Name): $cfg config not found"
                }
            }

            # Diagnostic settings (if enabled)
            if ($IncludeDiagnostics) {
                try {
                    Write-Verbose "Fetching data for diagnosticsSettings"
                    $diag = Get-AzDiagnosticSetting -ResourceId $siteResourceId -ErrorAction Stop
                    $diag | ConvertTo-Json -Depth 10 | Out-File (Join-Path $appDir "diagnostics.json") -Encoding UTF8
                    Write-Host "✅ $($app.Name): diagnostics.json"
                } catch {
                    Write-Warning "⚠️ $($app.Name): No diagnostics found"
                }
            }

            # Publishing profile (if enabled)
            if ($IncludePublishingProfile) {
                try {
                    Write-Verbose "Fetching data for publishingProfile"
                    Get-AzWebAppPublishingProfile -Name $app.Name -ResourceGroupName $app.ResourceGroup -OutputFile (Join-Path $appDir "publishingProfile.xml") -ErrorAction Stop | Out-Null
                    Write-Host "✅ $($app.Name): publishingProfile.xml"
                } catch {
                    Write-Warning "⚠️ $($app.Name): Could not get publishing profile"
                }
            }

            # Deployment slots (if enabled)
            if ($IncludeSlots) {
                try {
                    Write-Verbose "Fetching data for slots"
                    $slots = Get-AzWebAppSlot -ResourceGroupName $app.ResourceGroup -Name $app.Name
                    foreach ($slot in $slots) {
                        $slotDir = Join-Path $appDir "slots\$($slot.Name)"
                        New-Item -ItemType Directory -Path $slotDir -Force | Out-Null
                        $slotId = $slot.Id

                        try {
                            $slot | ConvertTo-Json -Depth 10 | Out-File (Join-Path $slotDir "slot.json") -Encoding UTF8
                            foreach ($cfg in $knownConfigTypes) {
                                $slotCfgResId = "$slotId/config/$cfg"
                                $slotCfg = Get-AzResource -ResourceId $slotCfgResId -ExpandProperties -ErrorAction Stop
                                $slotCfg.Properties | ConvertTo-Json -Depth 10 | Out-File (Join-Path $slotDir "$cfg.json") -Encoding UTF8
                            }
                            Write-Host "✅ $($app.Name): Slot '$($slot.Name)' exported"
                        } catch {
                            Write-Warning "⚠️ $($app.Name): Failed to export slot '$($slot.Name)'"
                        }
                    }
                } catch {
                    Write-Warning "⚠️ $($app.Name): No slots or error fetching slots"
                }
            }
        }
    }
}
