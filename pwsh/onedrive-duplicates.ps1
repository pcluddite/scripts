<#
 :
 : Copyright 2023-2024 Timothy Baxendale (pcluddite@outlook.com)
 :
 : Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 : and associated documentation files (the "Software"), to deal in the Software without limitation
 : in the rights to use, copy, modify, merge, publish, and/ or distribute copies of the Software in
 : an educational or personal context, subject to the following conditions:
 : 
 : - The above copyright notice and this permission notice shall be included in all copies or
 :  substantial portions of the Software.
 : 
 :  Permission is granted to sell and/ or distribute copies of the Software in a commercial
 :  context, subject to the following conditions:
 : 
 : - Substantial changes: adding, removing, or modifying large parts, shall be developed in the
 :  Software. Reorganizing logic in the software does not warrant a substantial change. 
 : 
 : THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
 : NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 : NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 : DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
 : OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 : 
#>
using namespace System.IO

[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [Parameter(Position=0)]
    [Alias('Path')]
    [string]$OneDrivePath = $(Join-Path $HOME 'OneDrive'),
    [Parameter(Position=1)]
    [string]$MachineName = $([Environment]::MachineName)
)

$ErrorActionPreference='Stop'

. "${PSScriptRoot}/modules.ps1" -Name @('files')

if ($null -eq $PSBoundParameters['InformationAction']) {
    $InformationPreference='Continue'
}

function Move-Recycle() {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$DupeInfo
    )
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    $RecyclePath=$DupeInfo.Older.FullName
    if ($DupeInfo.Original -eq $DupeInfo.Older) {
        if ($PSCmdlet.ShouldProcess("Recycle '${RecyclePath}'", "Recycle '${RecyclePath}' and rename '$($DupeInfo.Duplicate.FullName)'?", 'Remove-Recycle')) {
            Remove-Recycle -Path $RecyclePath -ErrorAction Stop -WhatIf:$false -Confirm:$false
            Write-Information "Moving '$($DupeInfo.Duplicate.FullName)' to '${RecyclePath}"
            Move-Item -Path $DupeInfo.Duplicate.FullName -Destination $RecyclePath -ErrorAction Stop -WhatIf:$false -Confirm:$false
        }
    } else {
        if ($PSCmdlet.ShouldProcess("Recycle '${RecyclePath}'", "Recycle '${RecyclePath}'?", 'Remove-Recycle')) {
            Remove-Recycle -Path $RecyclePath -ErrorAction Stop -WhatIf:$false -Confirm:$false
        }
    }
}

function Find-Duplicate {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Path,
        [Parameter(Mandatory,Position=1)]
        [string]$MachineName
    )
    $EscapedMachine=[Regex]::Escape($MachineName)
    Get-ChildItem -LiteralPath $Path -File | where { $_.BaseName -imatch "^(.+)\-${EscapedMachine}(\-\d+)*`$" } | % {
        $OriginalName=$Matches[1]
        if ([Path]::HasExtension($_.Name)) {
            $OriginalName="${OriginalName}$($_.Extension)"
        }
        $OriginalPath = Join-Path $_.DirectoryName $OriginalName
        $Original = Get-Item -LiteralPath $OriginalPath -ErrorAction SilentlyContinue
        if ($Original.Exists) {
            Write-Information "Found duplicate for '${OriginalPath}'..."
            [PSCustomObject]@{
                Original=$Original
                Duplicate=$_
                Older=$(if ($_.LastWriteTime -gt $Original.LastWriteTime) { $Original } else { $_ })
            }
        } else {
            $PSCmdlet.WriteWarning("Original file for '$($_.Name)' does not exist")
            Move-Item $_ -Destination $OriginalPath -WhatIf:$WhatIfPreference
        }
    }
}

$RootPath=[Path]::GetFullPath($OneDrivePath)

if (-not (Test-Path -LiteralPath $RootPath)) {
    try {
        throw "${RootPath} does not exist"
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Write-Information "Finding and removing duplicates for ${MachineName} in '${RootPath}'"

$SearchPaths=@(Get-ChildItem -LiteralPath $RootPath -Directory -Recurse)
$SearchPaths+=(Get-Item -LiteralPath $RootPath)

$i = 0
$DupeList=@($SearchPaths | % {
    Write-Progress -Activity 'OneDrive search status' `
        -Status "Searching '$($_.FullName.Substring($RootPath.Length % $_.FullName.Length))'" `
        -PercentComplete ([double]$i++ / $SearchPaths.Length * 100)
    Find-Duplicate -Path $_ -MachineName $MachineName -WhatIf:$WhatIfPreference
})

Write-Information "$($DupeList.Length) duplicate(s) were found"

for($i = 0; $i -lt $DupeList.Length; ++$i) {
    $DupeInfo = $DupeList[$i]
    Write-Progress -Activity 'Recycling duplicates progress' `
        -Status "Recycling '$($DupeInfo.Older.Name)' ($($i + 1) of $($DupeList.Length))" `
        -PercentComplete ([double]$i / $DupeList.Length * 100)
    Move-Recycle -DupeInfo $DupeInfo -WhatIf:$WhatIfPreference
}

if ($DupeList.Length -gt 0) {
    Write-Information 'Done'
}
