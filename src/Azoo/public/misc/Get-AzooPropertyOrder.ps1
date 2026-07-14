function Get-AzooPropertyOrder {
    <#
    .SYNOPSIS
    Returns the stored property order for a tag.

    .DESCRIPTION
    Reads the property-order array previously captured by
    Set-AzooPropertyOrder for the same tag.

    .PARAMETER Tag
    Name of the stored property-order slot.

    .EXAMPLE
    $data | Select-Object resourceGroup, name, id | Set-AzooPropertyOrder -Tag "foo" | Format-MarkdownTableTableStyle -Property (Get-AzooPropertyOrder -Tag "foo")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Tag
    )

    $script:PropertyOrders[$Tag]
}