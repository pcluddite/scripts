<#
 :
 : Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)
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
using namespace System.Diagnostics.CodeAnalysis;
using namespace System.IO

[SuppressMessageAttribute('PSReviewUnusedParameter','Algorithm',Justification='false positive')]
[SuppressMessageAttribute('PSReviewUnusedParameter','Filter',Justification='false positive')]
[SuppressMessageAttribute('PSReviewUnusedParameter','Recurse',Justification='false positive')]
param(
    [Parameter(Mandatory,Position=0)]
    [string[]]$Path,
    [Parameter(ValueFromRemainingArguments,Position=1)]
    [string[]]$Filter,
    [Parameter()]
    [switch]$Recurse,
    [Parameter()]
    [string]$Algorithm = 'MD5'
)
$MODULE_PATH=Join-Path $PSScriptRoot 'modules.ps1'
. $MODULE_PATH -Name @('files','string')

if ($null -eq $PSBoundParameters['InformationAction']) {
    $InformationPreference='Continue'
}

$FileMap=@{}

function Find-Duplicate {
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Path,
        [Parameter(Position=1)]
        [string[]]$Filter,
        [Parameter()]
        [string]$Algorithm='MD5',
        [Parameter()]
        [switch]$Recurse
    )
    if ($Filter) {
        $AllFiles=@()
        $Filter | % {
            Get-ChildItem -LiteralPath:$Path -Filter:$_ -Recurse:$Recurse -File | % {
                $AllFiles+=$_
            }
        }
    } else {
        $AllFiles=@(Get-ChildItem -LiteralPath:$Path -Filter:$Filter -Recurse:$Recurse -File)
    }
    $i=0
    $AllFiles | % {
        $Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm $Algorithm).Hash
        $FileSet=$FileMap[$Hash]
        if ($FileSet) {
            $FileSet[$_.ResolvedTarget]=$true
        } else {
            $FileSet=@{"$($_.ResolvedTarget)"=$true}
        }
        $FileMap[$Hash]=$FileSet
        Write-Progress -Activity 'Duplicate search status' `
            -Status "Searching '${_}'" `
            -PercentComplete ([double]$i++ / $AllFiles.Length * 100)
    }
}

$Path | % {
    $Directory=(Get-Item $_ -ErrorAction SilentlyContinue)
    if (-not $Directory) {
        try {
            throw [DirectoryNotFoundException]"'${_}' does not exist"
        } catch {
            $PSCmdlet.WriteError($_)
        }
    } elseif ($Directory -isnot [DirectoryInfo]) {
        try {
            throw [DirectoryNotFoundException]"'${_}' is not a directory"
        } catch {
            $PSCmdlet.WriteError($_)
        }
    } else {
        Find-Duplicate -Path $Directory -Filter $Filter -Recurse:$Recurse -Algorithm $Algorithm
    }
}

$DupeCount=0
$TotalSize=0
$UniqueCount=0

$FileMap.Keys | % {
    $DistinctPaths=@($FileMap[$_].Keys | Sort-Object -Property FullName)
    [PSCustomObject]@{
        Hash = $_
        Length = (Get-Item -LiteralPath $DistinctPaths[0]).Length
        Files = $DistinctPaths
    }
} | where { $_.Files.Length -gt 1 } | % {
    $DupeCount=$DupeCount + $_.Files.Length - 1
    $UniqueCount=$UniqueCount+1
    $TotalSize=$TotalSize+($_.Length * ($_.Files.Length - 1))
    return $_
}

if ($UniqueCount -gt 0) {
    Write-Information "Found $($UniqueCount.ToString("#,###")) unique file(s) with $($DupeCount.ToString("#,###")) duplicate(s) occupying an additional $(($TotalSize / 1024 / 1024).ToString("#,###.##")) MB"
} else {
    Write-Information 'No duplicates found'
}