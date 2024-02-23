using namespace System.Diagnostics.CodeAnalysis;
using namespace System.IO

[SuppressMessageAttribute('PSReviewUnusedParameter','Algorithm',Justification='false positive')]
[SuppressMessageAttribute('PSReviewUnusedParameter','Filter',Justification='false positive')]
[SuppressMessageAttribute('PSReviewUnusedParameter','Recurse',Justification='false positive')]
param(
    [Parameter(Mandatory,Position=0,ValueFromPipeline)]
    [string[]]$Path,
    [Parameter(ValueFromRemainingArguments,Position=1)]
    [string[]]$Filter,
    [Parameter()]
    [switch]$Recurse,
    [Parameter()]
    [string]$Algorithm = 'MD5'
)
begin {
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
        Get-ChildItem -LiteralPath:$Path -Filter:$Filter -Recurse:$Recurse -File | % {
            $Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm $Algorithm).Hash
            if ($FileMap[$Hash]) {
                $FileMap[$Hash]+=$_
            } else {
                $FileMap[$Hash]=@($_)
            }
        }
    }
}
process {
    $Path | % {
        $LiteralPath=[Path]::GetFullPath($_)
        if ($Filter) {
            $Filter | % {
                Find-Duplicate -Path $LiteralPath -Filter $_ -Recurse:$Recurse -Algorithm $Algorithm
            }
        } else {
            Find-Duplicate -Path $LiteralPath -Recurse:$Recurse -Algorithm $Algorithm
        }
    }
}
end {
    $FileMap.Keys | % {
        [PSCustomObject]@{
            Hash = $_
            Paths = ($FileMap[$_] | select -Unique | sort -Property FullName)
        }
    } | where { $_.Paths.Length -gt 1 }
}
