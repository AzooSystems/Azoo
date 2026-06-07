function Enable-AzooAzPimRole {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Interactive usage")]
    param (
        # The justification for activating the role. The justification will be recorded in the audit logs and can be used for reporting and access reviews.
        [Parameter(Mandatory = $True)]
        [String]
        $justification,
        # The principal ID of the user for whom the role will be activated. If not specified, the currently signed-in user will be used.
        [Parameter()]
        [String]
        $principalId = (Get-AzADUser -SignedIn).Id,
        # The duration for which the role will be activated. The default is 30 minutes. The value should be in ISO 8601 duration format (e.g., "PT1H" for 1 hour).
        [Parameter()]
        [String]
        $expirationDuration = "PT30M",
        # A filter scriptblock to apply to the eligible Azure RBAC roles.
        [Parameter()]
        [Scriptblock]
        $filter,
        # If specified Cmdlet will skill interactive selections with Out-GridView or Out-ConsoleGridView and select all roles that match the filter. If not specified, the user will be prompted to select which eligible roles to activate.
        [Parameter()]
        [Switch]
        $disableInteraction,
        [Parameter()]
        [Switch]
        $force,
        [Parameter()]
        [Switch]
        $forceNonInteractive
    )

    $eligibleAzureRbac = Get-AzRoleEligibilityScheduleInstance -Scope "/" -Filter "asTarget()"

    if ($filter) {
        $filteredAzureRbac = $eligibleAzureRbac | Where-Object $filter
    }
    else {
        $filteredAzureRbac = $eligibleAzureRbac
    }

    if (-not $disableInteraction -and $PSVersionTable.PSEdition -eq "Desktop") {
        Write-Host "Displaying Out-GridView for manual selection"
        $selectedAzureRbac = $filteredAzureRbac | Out-GridView -PassThru
    }
    elseif (-not $disableInteraction) {
        $selectedAzureRbac = $filteredAzureRbac | Select-Object MemberType, PrincipalType, ScopeDisplayName, PrincipalDisplayName, RoleDefinitionDisplayName, id  | Out-ConsoleGridview -Title "Roles to select"
    }
    else {
        $selectedAzureRbac = $filteredAzureRbac
    }

    Write-Debug "$($selectedAzureRbac.Count) rows selected"

    $continueIfInteractionDisabled = if ($disableInteraction) {
        $WhatIfPreference -or $forceNonInteractive -or $PSCmdlet.ShouldContinue("Interaction disabled", "x")
    }
    else {
        $false
    }

    $selectedAzureRbac | ForEach-Object {
        $eligibleRole = $_
        $originalEligibleAzureRbac = $eligibleAzureRbac | Where-Object { $_.Id -eq $eligibleRole.Id }
        $params = @{
            Name                            = New-Guid
            Scope                           = $originalEligibleAzureRbac.Scope
            Justification                   = $justification
            LinkedRoleEligibilityScheduleId = $originalEligibleAzureRbac.RoleEligibilityScheduleId
            PrincipalId                     = $principalId
            RequestType                     = "SelfActivate"
            ExpirationDuration              = $expirationDuration
            ExpirationType                  = "AfterDuration"
            RoleDefinitionId                = $originalEligibleAzureRbac.RoleDefinitionId
        }

        if (($disableInteraction -and $continueIfInteractionDisabled -or -not $disableInteraction) -and `
                $PSCmdlet.ShouldProcess(
                "Enabling RBAC role for $($originalEligibleAzureRbac.RoleEligibilityScheduleId)",
                $null, $null
            )) {
            New-AzRoleAssignmentScheduleRequest @params -Confirm:$false
        }
    }
}