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
. $MODULE_PATH -Name @('files')

$FileMap=@{}

function Find-Duplicate {
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Path,
        [Parameter(Position=1)]
        [string]$Filter,
        [Parameter()]
        [string]$Algorithm='MD5',
        [Parameter()]
        [switch]$Recurse
    )
    $AllFiles=@(Get-ChildItem -LiteralPath:$Path -Filter:$Filter -Recurse:$Recurse -File)
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

$i=0

$Path | % {
    trap {
        $PSCmdlet.WriteError($_)
    }

    $Directory=(Get-Item $_ -ErrorAction SilentlyContinue)
    if (-not $Directory) {
        throw [DirectoryNotFoundException]"'${_}' does not exist"
    } elseif ($Directory -isnot [DirectoryInfo]) {
        throw [DirectoryNotFoundException]"'${_}' is not a directory"
    } elseif ($Filter) {
        $Filter | % {
            Find-Duplicate -Path $Directory -Filter $_ -Recurse:$Recurse -Algorithm $Algorithm
        }
    } else {
        Find-Duplicate -Path $Directory -Recurse:$Recurse -Algorithm $Algorithm
    }
    ++$i
}

$FileMap.Keys | % {
    [PSCustomObject]@{
        Hash = $_
        Paths = @($FileMap[$_].Keys | sort -Property FullName)
    }
} | where { $_.Paths.Length -gt 1 }
