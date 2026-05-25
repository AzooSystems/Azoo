function Show-AzooHostfile {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'Medium'
    )]
    param(
        [Switch]$Force,
        $queryLimit = 1000,
        $snowFlakeConfigFile,
        $ignoredResources = @(),
        $ignoredEndpoints = @(),
        # https://techcommunity.microsoft.com/blog/fasttrackforazureblog/how-azure-monitors-implementation-of-private-link-differs-from-other-services/3608938
        # https://cloudjourney.medium.com/azure-monitor-private-link-a8a4544facaf
        # https://techcommunity.microsoft.com/blog/coreinfrastructureandsecurityblog/securing-monitoring-services/4097602
        [Switch]$ignoreAmpls
    )

    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) {
        Write-Verbose "Changing `$ConfirmPreference to None"
        $ConfirmPreference = 'None'
    }

    if (!(Get-AzAccessToken -ErrorAction SilentlyContinue)){
        if (-not $Force) {
            throw "Please authenticate to azure with Connect-AzAccount"
        }
        $NoAuth = $true
    }

    if ($snowFlakeConfigFile) {
        $SnowflakeConfig = Import-PowerShellDataFile -Path $snowFlakeConfigFile
    } else {
        $SnowflakeConfig = @()
    }

    $query = @'
Resources
|where type =~ "microsoft.network/networkInterfaces" and isnotnull(properties) and isnotnull(properties.ipConfigurations) and isnotnull(properties.ipConfigurations[0].properties.privateLinkConnectionProperties)
| project id, name, subscriptionId, properties
| extend privateEndpoint = tostring(properties.privateEndpoint.id)
| mv-expand properties.ipConfigurations
| extend plc = properties_ipConfigurations.properties.privateLinkConnectionProperties
| extend fqdns = iff(array_length(plc.fqdns) > 0, plc.fqdns, dynamic(["none"]))
| mv-expand fqdn=fqdns
| extend IP = properties_ipConfigurations.properties.privateIPAddress
| project privateEndpoint, fqdn, IP
| join kind=fullouter (
resources
| where ['type'] == "microsoft.network/privateendpoints"
| extend privateLinkServiceId = properties.privateLinkServiceConnections[0].properties.privateLinkServiceId
| project id, privateLinkServiceId
) on $left.privateEndpoint == $right.id
| project privateEndpoint, fqdn, IP, privateLinkServiceId
| sort by tostring(fqdn)
'@

    if (-not $NoAuth) {
        $data = Search-AzGraph -First $queryLimit -Query $query
        $privateEndpointNics = $data.Data
        Write-Verbose "Received skip token: $($data.SkipToken ?? "NULL")"
        Write-Verbose "Received lines: $($data.Count)"

        while ($data.SkipToken) {
            $data = Search-AzGraph -First $queryLimit -Query $query -SkipToken $data.SkipToken
            Write-Verbose "Received skip token: $($data.SkipToken ?? "NULL")"
            Write-Verbose "Received lines: $($data.Count)"
            $privateEndpointNics = $privateEndpointNics + $data.Data
        }

        # TODO: sort be resource groups. Even better make a custom sorter that knows how to sort dev/test/prod

        # https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#management-and-governance
        if ($ignoreAmpls) {
            $ignoredEndpoints = $ignoredEndpoints + @(
                # from docs/ deployments
                "monitor.azure.com", #  10 entries
                "oms.opinsights.azure.com", # 1 entry
                "ods.opinsights.azure.com", # 1 entry
                "agentsvc.azure-automation.net", # 1 entry
                "scadvisorcontentpl.blob.core.windows.net" # entry
            )
        }

        $ignoredResources = @(
        )

        $privateEndpointLines = $privateEndpointNics | ForEach-Object {
            if ($_.fqdn) {
                $fqdn = $_.fqdn

                $fqdnCount = ($privateEndpointNics | Where-Object { $_.fqdn -eq $fqdn -and $fqdn -ne "none" }).Count
                if ($fqdnCount -gt 1) {
                    Write-Warning "`$fqdn: $fqdn `$fqdnCount: $fqdnCount"
                }

                $fqdn = $_.fqdn.Replace("vaultcore.azure.net", "vault.azure.net")
                $privateLinkServiceId=$_.privateLinkServiceId
                if ($fqdn -eq "none") {
                    $line = "# {0} none # {1}" -f $_.IP, $_.privateEndpoint
                    Write-Output $line
                } elseif ($ignoredEndpoints.Where{ $fqdn -match $_}) {
                    Write-Warning "$fqdn ignored by `$ignoredEndpoints"
                    $line = "# {0} {1} # {2}" -f $_.IP, $fqdn, $_.privateEndpoint
                } elseif ($ignoredResources.Where{ $privateLinkServiceId -match $_}) {
                    Write-Warning "$fqdn ignored by `$ignoredResources"
                    $line = "# {0} {1} # {2}" -f $_.IP, $fqdn, $_.privateEndpoint
                } else {
                    $line = "{0} {1} # {2}" -f $_.IP, $fqdn, $_.privateEndpoint
                    Write-Output $line
                }
            }
        }
    } else {
        $privateEndpointLines = @()
    }

    $snowflakeLines = $SnowflakeConfig | ForEach-Object {
        Write-Output "##################"
        Write-Output "# $($_.comment)"
        Write-Output "##################"

        Write-Output ""
        Write-Output "# Snowsight FQDN"
        $fqdn = Get-AzooSnowflakeFqdn -type "regionless-snowsight" -identifier $_.id
        Write-Output ("{0} {1} # {2}" -f $_.ip, $fqdn, "regionless-snowsight-privatelink-url")
        Write-Output ("{0} {1} # {2}" -f $_.ip, "app.west-europe.privatelink.snowflakecomputing.com", "snowsight-privatelink-url (Will cause issues on some OS if multiple entries on hosts file)")

        # Snowsight does not support locator
        #$fqdn = Get-AzooSnowflakeFqdn -type "snowsight" -locator $_.locator
        #Write-Output ("{0} {1}" -f $_.ip, $fqdn)

        Write-Output "# Account / API FQDN"
        $fqdn = Get-AzooSnowflakeFqdn -type "regionless-api" -identifier $_.id
        Write-Output ("{0} {1} # {2}" -f $_.ip, $fqdn, "regionless-privatelink-account-url")
        $fqdn = Get-AzooSnowflakeFqdn -type "api" -locator $_.locator -region $_.region
        Write-Output ("{0} {1} # {2}" -f $_.ip, $fqdn, "privatelink-account-url | Snowsight will use this for auth")

        Write-Output "# OCSP"
        $fqdn = Get-AzooSnowflakeFqdn -type "regionless-ocsp" -identifier $_.id
        Write-Output ("{0} {1} # {2}" -f $_.ip, $fqdn, "regionless-privatelink-ocsp-url")
        $fqdn = Get-AzooSnowflakeFqdn -type "ocsp" -locator $_.locator -region $_.region
        Write-Output ("{0} {1} # {2}" -f $_.ip, $fqdn, "privatelink_ocsp-url")
        Write-Output ""
    }
    $date = Get-Date -Format "o"
    $lines = @("# Generated with TBD on $date", "# Native Azure private endpoint resources") + $privateEndpointLines
    if ($SnowflakeConfig ) { 
        $lines = $lines + @("", "# Snowflake") + $snowflakeLines
    }
    $lines = $lines + "#End of generated content"

    $lines -join "`r`n" | Out-String | Write-Output
}
