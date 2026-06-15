function Enable-AzooAzPimRoles {
[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $True)]
    [String]
    $justification,
    [Parameter()]
    [String]
    $principalId = (Get-AzADUser -SignedIn).Id,
    [Parameter()]
    [String]
    $expirationDuration = "PT30M",
    [Parameter()]
    [Scriptblock]
    $filter,
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
  } else {
    $filteredAzureRbac = $eligibleAzureRbac
  }

  if (-not $disableInteraction -and $PSVersionTable.PSEdition -eq "Desktop") {
    Write-Host "Displaying Out-GridView for manual selection"
    $selectedAzureRbac = $filteredAzureRbac | Select-Object MemberType, PrincipalType, ScopeDisplayName, PrincipalDisplayName, RoleDefinitionDisplayName, id | Out-GridView -PassThru
  } elseif (-not $disableInteraction) {
    $selectedAzureRbac = $filteredAzureRbac | Select-Object MemberType, PrincipalType, ScopeDisplayName, PrincipalDisplayName, RoleDefinitionDisplayName, id  | Out-ConsoleGridview -Title "Roles to select"
  } else {
    $selectedAzureRbac = $filteredAzureRbac
  }

  Write-Debug "$($selectedAzureRbac.Count) rows selected"

  $continueIfInteractionDisabled = if ($disableInteraction) {
      $WhatIfPreference -or $forceNonInteractive -or $PSCmdlet.ShouldContinue("Interaction disabled", "x")
    } else {
      $false
    }

  $selectedAzureRbac | ForEach-Object {
    $eligibleRole = $_
    $originalEligibleAzureRbac = $eligibleAzureRbac | Where-Object {$_.Id -eq $eligibleRole.Id }
    $params = @{
      Name = New-Guid
      
      Scope = $originalEligibleAzureRbac.Scope
      Justification = $justification
      LinkedRoleEligibilityScheduleId =  $originalEligibleAzureRbac.RoleEligibilityScheduleId
      PrincipalId = $principalId
      RequestType = "SelfActivate"
      ExpirationDuration = "PT8H"
      ExpirationType = "AfterDuration"
      RoleDefinitionId = $originalEligibleAzureRbac.RoleDefinitionId
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