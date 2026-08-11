function Export-AzooAzAppServiceAppAllSettings {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string] $FunctionAppName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [string] $FunctionAppResourcegroupName,

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
        if ($PSCmdlet.ParameterSetName -eq 'ByInputObject' -and $InputObject) {
            if ($InputObject.Kind -like '*functionapp*') {
                $appsToExport += [PSCustomObject]@{
                    Name = $InputObject.Name
                    ResourceGroup = $InputObject.ResourceGroup
                }
            } else {
                Write-Warning "Skipping non-Function App input: $($InputObject.Name)"
            }
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $app = Get-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $FunctionAppResourcegroupName -ErrorAction Stop
            if ($Null -eq $app) {
                throw "Could not find given function app"
            }
            Write-Verbose $app
            $appsToExport += [PSCustomObject]@{
                Name = $app.Name
                ResourceGroup = $app.ResourceGroup
            }
            Write-Verbose $appsToExport[0]
        }

        $appsToExport = $appsToExport | Sort-Object Name -Unique
        $subscriptionId = (Get-AzContext).Subscription.Id

        foreach ($app in $appsToExport) {
            $appDir = Join-Path $OutputDirectory $app.Name
            if (-not (Test-Path $appDir)) {
                New-Item -ItemType Directory -Path $appDir | Out-Null
            }

            $siteResourceId = "/subscriptions/$subscriptionId/resourceGroups/$($app.ResourceGroup)/providers/Microsoft.Web/sites/$($app.Name)"

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
                    $cfgRes = Invoke-AzResourceAction -ResourceId $resId -Action "list" -ErrorAction Stop -Force:$Force
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
                    $profile = Get-AzWebAppPublishingProfile -Name $app.Name -ResourceGroupName $app.ResourceGroup -OutputFile (Join-Path $appDir "publishingProfile.xml") -ErrorAction Stop
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


# "/providers/Microsoft.Web/functionAppStacks?stackOsType=windows&removeHiddenStacks=true&useCanaryFusionServer=false&api-version=2020-10-01"
<#
$res = Invoke-AzRestMethod -Method GET -Uri "https://management.azure.com/providers/Microsoft.Web/functionAppStacks?api-version=2024-11-01"
$dataHT = ($res.Content | ConvertFrom-Json -AsHashtable).value
$data = ($res.Content | ConvertFrom-Json).value

#>