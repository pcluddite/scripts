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
    [string]$MachineName = ${env:COMPUTERNAME}
)

$ErrorActionPreference='Stop'

Add-Type -AssemblyName Microsoft.VisualBasic

function Move-Recycle() {
    param(
        [Parameter(Mandatory)]
        [FileSystemInfo]$Original,
        [Parameter(Mandatory)]
        [FileSystemInfo]$Duplicate
    )
    try {
        $IsOriginal=($Duplicate.LastWriteTime -gt $Original.LastWriteTime)
        if ($IsOriginal) {
            $RecyclePath=$Original.FullName
        } else {
            $RecyclePath=$Duplicate.FullName
        }
        Write-Host "Recycling '${RecyclePath}'..."
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($RecyclePath, 'OnlyErrorDialogs', 'SendToRecycleBin')
        if ($IsOriginal) {
            $PSCmdlet.WRiteVerbose("Moving '$($Duplicate.FullName)' to '${RecyclePath}")
            Move-Item -Path $Duplicate.FullName -Destination $RecyclePath
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-DuplicateItems() {
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Path,
        [Parameter(Mandatory,Position=1)]
        [string]$MachineName
    )
    $PSCmdlet.WRiteVerbose("Searching in $([Path]::GetFullPath($Path))...")
    $EscapedMachine=[Regex]::Escape($MachineName)
    Get-ChildItem -Path $Path -File | where { $_.BaseName -imatch "^(.+)\-${EscapedMachine}(\-\d+)*`$" } | % {
        $OriginalName=$Matches[1]
        if ([Path]::HasExtension($_.Name)) {
            $OriginalName="${OriginalName}$($_.Extension)"
        }
        $OriginalPath = Join-Path $_.DirectoryName $OriginalName
        $Original = Get-Item -Path $OriginalPath -ErrorAction SilentlyContinue
        if ($Original.Exists) {
            Write-Host "Found duplicate for '${OriginalPath}'..."
            @{
                Original=$Original
                Duplicate=$_
            }
        } else {
            $PSCmdlet.WriteWarning("'${OriginalPath}' does not exist")
        }
    }
}

$dupes=@(Get-ChildItem -Path $Path -Directory -Recurse | % {
    Get-DuplicateItems -Path $_ -MachineName $MachineName
})

Write-Host "$($dupes.Count) duplicate(s) were found"

foreach($dupe in $dupes) {
    Move-Recycle -Original $dupe['Original'] -Duplicate $dupe['Duplicate']
}
