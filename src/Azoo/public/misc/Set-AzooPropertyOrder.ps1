function Set-AzooPropertyOrder {
    <#
    .SYNOPSIS
    Captures a stable property order for a tagged object stream.

    .DESCRIPTION
    Tracks property names seen from pipeline input and stores a merged
    order under the provided tag. The input objects are returned unchanged
    so the command can be used mid-pipeline.

    .PARAMETER Tag
    Name of the stored property-order slot.

    .PARAMETER InputObject
    Pipeline object whose property names are used to build the order.

    .EXAMPLE
    $data | Select-Object resourceGroup, name, id | Set-AzooPropertyOrder -Tag "foo" | Format-MarkdownTableTableStyle -Property (Get-AzooPropertyOrder -Tag "foo")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Tag,

        [Parameter(ValueFromPipeline, Mandatory)]
        [psobject]$InputObject
    )

    begin {
        $order = [System.Collections.Generic.List[string]]::new()
    }

    process {
        [string[]]$props = @($InputObject.PSObject.Properties.Name)

        if ($order.Count -eq 0) {
            $order.AddRange($props)
        }
        else {
            foreach ($prop in $props) {

                if ($order.Contains($prop)) {
                    continue
                }

                $insert = $null
                $index = [array]::IndexOf($props, $prop)

                # Insert after nearest known predecessor.
                for ($i = $index - 1; $i -ge 0; $i--) {
                    $anchor = $props[$i]
                    $pos = $order.IndexOf($anchor)
                    if ($pos -ge 0) {
                        $insert = $pos + 1
                        break
                    }
                }

                # Otherwise insert before nearest known successor.
                if ($null -eq $insert) {
                    for ($i = $index + 1; $i -lt $props.Count; $i++) {
                        $anchor = $props[$i]
                        $pos = $order.IndexOf($anchor)
                        if ($pos -ge 0) {
                            $insert = $pos
                            break
                        }
                    }
                }

                if ($null -eq $insert) {
                    $order.Add($prop)
                }
                else {
                    $order.Insert($insert, $prop)
                }
            }
        }

        # Pass the object through unchanged.
        $InputObject
    }

    end {
        $script:PropertyOrders[$Tag] = $order.ToArray()
    }
}
