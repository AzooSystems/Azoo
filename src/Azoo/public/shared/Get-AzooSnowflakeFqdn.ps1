function Get-AzooSnowflakeFqdn {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'identifier')]
        [string]
        $identifier,
        [Parameter(Mandatory, ParameterSetName = 'locator')]
        [string]
        $locator,
        [Parameter(ParameterSetName = 'identifier')]
        [Parameter(ParameterSetName = 'locator')]
        [ValidateSet("api", "regionless-api", "snowsight","regionless-snowsight", "ocsp", "regionless-ocsp")]
        [string]
        $type,
        [string]
        $region
    )
    if ($type -like "regionless-*") {
        if ($PSCmdlet.ParameterSetName -eq "locator") {
            throw "regionless types does not support locator"
        }
    } else {
        if ($PSCmdlet.ParameterSetName -eq "identifier") {
            throw "region types does not support locator"
        }

        if (-not $region) {
            throw "region musrt be supplied for region types"
        }
    }
    switch ($type) {
        "api" {
            return "${locator}.${region}.privatelink.snowflakecomputing.com"
        }
        "regionless-api" {
            return "${identifier}.privatelink.snowflakecomputing.com"
        }
        "snowsight" {
            throw "Unsupported config"
        }
        "regionless-snowsight" {
            return "app-${identifier}.privatelink.snowflakecomputing.com"
        }
        "ocsp" {
            return "ocsp.${locator}.${region}.privatelink.snowflakecomputing.com"
        }
        "regionless-ocsp" {
            return "ocsp.${identifier}.privatelink.snowflakecomputing.com"
        }
    }
}