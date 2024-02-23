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
    trap {
        $PSCmdlet.WriteError($_)
    }

    $Directory=(Get-Item $_ -ErrorAction SilentlyContinue)
    if (-not $Directory) {
        throw [DirectoryNotFoundException]"'${_}' does not exist"
    } elseif ($Directory -isnot [DirectoryInfo]) {
        throw [DirectoryNotFoundException]"'${_}' is not a directory"
    } else {
        Find-Duplicate -Path $Directory -Filter $Filter -Recurse:$Recurse -Algorithm $Algorithm
    }
}

$DupeCount=0
$TotalSize=0
$UniqueCount=0

$FileMap.Keys | % {
    $DistinctPaths=@($FileMap[$_].Keys | sort -Property FullName)
    [PSCustomObject]@{
        Hash = $_
        Length = (Get-Item -LiteralPath $DistinctPaths[0]).Length
        Files = $DistinctPaths
    }
} | where { $_.Files.Length -gt 1 } | % {
    $DupeCount=$DupeCount + $_.Files.Length - 1
    $UniqueCount=$UniqueCount+1
    $TotalSize=$TotalSize+($_.Length * ($_.Files.Length - 1))
    $_
}


if ($UniqueCount -gt 0) {
    Write-Warning "Found $($UniqueCount.ToString("#,###")) unique file(s) with $($DupeCount.ToString("#,###")) duplicate(s) occupying an additional $(($TotalSize / 1024 / 1024).ToString("#,###.##")) MB"
}