<#
 :
 : Copyright 2023 Timothy Baxendale (pcluddite@outlook.com)
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

param(
    [Parameter(Mandatory, Position=0)]
    [string]$Path,
    [Parameter(Position=1)]
    [string]$MachineName = $([Environment]::MachineName)
)

. "${PSScriptRoot}/modules.ps1" -Name @('files')

$ErrorActionPreference='Stop'

function Move-Recycle() {
    param(
        [Parameter(Mandatory)]
        [FileSystemInfo]$Original,
        [Parameter(Mandatory)]
        [FileSystemInfo]$Duplicate,
        [Parameter(Mandatory)]
        [FileSystemInfo]$Older
    )
    try {
        $RecyclePath=$Older.FullName
        Remove-Recycle -Path $RecyclePath
        if ($Original -eq $Older) {
            $PSCmdlet.WriteVerbose("Moving '$($Duplicate.FullName)' to '${RecyclePath}")
            Move-Item -Path $Duplicate.FullName -Destination $RecyclePath
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Find-Duplicates() {
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
            Write-Host "Found duplicate for '${OriginalPath}'..."
            @{
                Original=$Original
                Duplicate=$_
                Older=$(if ($_.LastWriteTime -gt $Original.LastWriteTime) { $Original } else { $_ })
            }
        } else {
            $PSCmdlet.WriteWarning("Moving '$($_.Name)' to '${OriginalPath}' because the original does not exist")
            Move-Item $_ -Destination $OriginalPath
        }
    }
}

$RootPath=[Path]::GetFullPath($Path)

Write-Host "Finding and removing duplicates for ${MachineName} in '${RootPath}'"

$dirs=@(Get-ChildItem -LiteralPath $RootPath -Directory -Recurse)
$dirs+=(Get-Item -LiteralPath $RootPath)

$i = 0
$dupes=@($dirs | % {
    Write-Progress -Activity 'OneDrive search status' `
        -Status "Searching '$($_.FullName.Substring($RootPath.Length % $_.FullName.Length))'" `
        -PercentComplete ([double]$i++ / $dirs.Length * 100)
    Find-Duplicates -Path $_ -MachineName $MachineName
})

Write-Host "$($dupes.Length) duplicate(s) were found"

for($i = 0; $i -lt $dupes.Length; ++$i) {
    $dupe = $dupes[$i]
    Write-Progress -Activity 'Recycling duplicates progress' `
        -Status "Recycling '$($dupe['Older'].Name)' ($($i + 1) of $($dupes.Length))" `
        -PercentComplete ([double]$i / $dupes.Length * 100)
    Move-Recycle -Original $dupe['Original'] -Duplicate $dupe['Duplicate'] -Older $dupe['Older']
}

if ($dupes.Length -gt 0) {
    Write-Host 'Done'
}
