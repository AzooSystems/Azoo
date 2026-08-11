Describe 'Export-AzooAzAppServiceAllSetting' {
    BeforeAll {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $manifestPath = Join-Path $repoRoot 'src/Azoo/Azoo.psd1'

        Import-Module $manifestPath -Force
    }

    BeforeEach {
        $script:functionAppLookupCalls = 0
        $script:siteResourceIds = [System.Collections.Generic.List[string]]::new()
        $script:listActionResourceIds = [System.Collections.Generic.List[string]]::new()
        $script:diagnosticResourceIds = [System.Collections.Generic.List[string]]::new()
        $script:publishingProfileRequests = [System.Collections.Generic.List[object]]::new()

        Mock -CommandName Update-AzConfig -ModuleName Azoo -MockWith {
            [pscustomobject]@{}
        }

        Mock -CommandName Test-Path -ModuleName Azoo -MockWith {
            param(
                [string]$Path
            )

            Microsoft.PowerShell.Management\Test-Path -Path $Path
        }

        Mock -CommandName New-Item -ModuleName Azoo -MockWith {
            param(
                [string]$Path,
                [string]$ItemType,
                [switch]$Force
            )

            Microsoft.PowerShell.Management\New-Item -Path $Path -ItemType $ItemType -Force:$Force
        }

        Mock -CommandName Get-AzFunctionApp -ModuleName Azoo -MockWith {
            $script:functionAppLookupCalls++
            [pscustomobject]@{
                Name = 'fn-not-expected'
                ResourceGroup = 'rg-not-expected'
                Id = '/subscriptions/sub-x/resourceGroups/rg-not-expected/providers/Microsoft.Web/sites/fn-not-expected'
            }
        }

        Mock -CommandName Get-AzResource -ModuleName Azoo -MockWith {
            param(
                [string]$ResourceId,
                [switch]$ExpandProperties
            )

            if ($ResourceId -match '^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\.Web/sites/[^/]+$') {
                $script:siteResourceIds.Add($ResourceId)
                return [pscustomobject]@{
                    Properties = [pscustomobject]@{
                        serverFarmId = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/serverfarms/asp-a'
                    }
                }
            }

            [pscustomobject]@{
                Properties = [pscustomobject]@{}
            }
        }

        Mock -CommandName Invoke-AzResourceAction -ModuleName Azoo -MockWith {
            param(
                [string]$ResourceId,
                [string]$Action,
                [switch]$Force
            )

            $script:listActionResourceIds.Add($ResourceId)
            [pscustomobject]@{
                Properties = [pscustomobject]@{}
            }
        }

        Mock -CommandName Get-AzWebAppSlot -ModuleName Azoo -MockWith {
            @(
                [pscustomobject]@{
                    Name = 'staging'
                    Id = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/sites/fn-app-a/slots/staging'
                }
            )
        }

        Mock -CommandName Get-AzDiagnosticSetting -ModuleName Azoo -MockWith {
            param(
                [string]$ResourceId
            )

            $script:diagnosticResourceIds.Add($ResourceId)
            [pscustomobject]@{}
        }

        Mock -CommandName Get-AzWebAppPublishingProfile -ModuleName Azoo -MockWith {
            param(
                [string]$Name,
                [string]$ResourceGroupName,
                [string]$Slot,
                [string]$OutputFile
            )

            $script:publishingProfileRequests.Add([pscustomobject]@{
                Name = $Name
                ResourceGroupName = $ResourceGroupName
                Slot = $Slot
                OutputFile = $OutputFile
            })
            [pscustomobject]@{}
        }

        Mock -CommandName Out-File -MockWith { }
    }

    It 'accepts Function App resource id directly' {
        $resourceId = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/sites/fn-app-a'

        Export-AzooAzAppServiceAllSetting -ResourceId $resourceId -OutputDirectory $TestDrive

        $script:functionAppLookupCalls | Should -Be 0
        @($script:siteResourceIds) | Should -Contain $resourceId
    }

    It 'accepts Function App resource id from pipeline input' {
        $resourceId = '/subscriptions/sub-b/resourceGroups/rg-b/providers/Microsoft.Web/sites/fn-app-b'

        $resourceId | Export-AzooAzAppServiceAllSetting -OutputDirectory $TestDrive

        $script:functionAppLookupCalls | Should -Be 0
        @($script:siteResourceIds) | Should -Contain $resourceId
    }

    It 'exports slot list-action configs when IncludeSlots is used' {
        $resourceId = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/sites/fn-app-a'

        Export-AzooAzAppServiceAllSetting -ResourceId $resourceId -OutputDirectory $TestDrive -IncludeSlots

        @($script:listActionResourceIds) | Should -Contain '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/sites/fn-app-a/slots/staging/config/appsettings'
        @($script:listActionResourceIds) | Should -Contain '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/sites/fn-app-a/slots/staging/config/connectionstrings'
    }

    It 'exports slot diagnostics and slot publishing profile when switches are enabled' {
        $resourceId = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/sites/fn-app-a'
        $slotResourceId = '/subscriptions/sub-a/resourceGroups/rg-a/providers/Microsoft.Web/sites/fn-app-a/slots/staging'

        Export-AzooAzAppServiceAllSetting -ResourceId $resourceId -OutputDirectory $TestDrive -IncludeSlots -IncludeDiagnostics -IncludePublishingProfile

        @($script:diagnosticResourceIds) | Should -Contain $slotResourceId

        $slotPublishingProfileRequests = @(
            $script:publishingProfileRequests |
                Where-Object {
                    ($_.Slot -eq 'staging') -or
                    ($_.Name -eq 'fn-app-a/staging')
                }
        )
        $slotPublishingProfileRequests.Count | Should -Be 1
    }
}
