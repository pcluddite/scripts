<#
::
:: Copyright 2024 Timothy Baxendale (pcluddite@outlook.com)
::
:: Permission is hereby granted, free of charge, to any person obtaining a copy of this software
:: and associated documentation files (the "Software"), to deal in the Software without limitation
:: in the rights to use, copy, modify, merge, publish, and/ or distribute copies of the Software in
:: an educational or personal context, subject to the following conditions:
:: 
:: - The above copyright notice and this permission notice shall be included in all copies or
::  substantial portions of the Software.
:: 
::  Permission is granted to sell and/ or distribute copies of the Software in a commercial
::  context, subject to the following conditions:
:: 
:: - Substantial changes: adding, removing, or modifying large parts, shall be developed in the
::  Software. Reorganizing logic in the software does not warrant a substantial change. 
:: 
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
:: NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
:: NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
:: DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
:: OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
:: 
::
::  ******************************************************************
::
::  Run this script to restore the old context menu in Windows 11
::
::  ******************************************************************
#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param()
trap {
    $PSCmdlet.ThrowTerminatingError($_)
}

if ($null -eq $PSBoundParameters['InformationAction']) {
    $InformationPreference='Continue'
}

$CLSID='HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
$KEY='InprocServer32'

function Update-ContextMenu {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param (
        [switch]$Undo,
        [switch]$Force
    )
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    if ($Force -and -not $Confirm){
        $ConfirmPreference = 'None'
    }
    $Path="${CLSID}\${KEY}"
    if ($Undo) {
        if ($PSCmdlet.ShouldProcess($Path, 'Remove-Item')) {
            Remove-Item -Force -Path $Path -ErrorAction Stop -Confirm:$false
            Write-Information 'CLSID for the old menu is has been removed. You may need to restart your computer for this to take effect.'
        }
    } else {
        if ($PSCmdlet.ShouldProcess($Path, 'New-Item')) {
            New-Item -Force -Path $CLSID -Name $KEY -Value '' -ErrorAction Stop -Confirm:$false | Out-Null
            Write-Information 'CLSID for the old menu is now registerd. You may need to restart your computer for this to take effect.'
        }
    }
}

if (Test-Path -LiteralPath "${CLSID}\${KEY}") {
    Write-Warning 'Traditional context menu is already enabled'
    if ($PSCmdlet.ShouldProcess('Enable Windows 11 context menu', 'Enable the Windows 11 context menu?', 'Update-ContextMenu -Undo')) {
        Update-ContextMenu -Undo -Confirm:$false
    }
} else {
    if ($PSCmdlet.ShouldProcess('Disable Windows 11 context menu', 'Disable the Windows 11 context menu?', 'Update-ContextMenu')) {
        Update-ContextMenu -Confirm:$false
    }
}
