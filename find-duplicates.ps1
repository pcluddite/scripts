using namespace System.IO
param(
    [Parameter(Mandatory,Position=0,ValueFromPipeline)]
    [string[]]$Path,
    [Parameter(ValueFromRemainingArguments,Position=1)]
    [string[]]$Filter,
    [switch]$Recurse,
    [string]$Algorithm = 'MD5'
)
begin {
    $MODULE_PATH=Join-Path $PSScriptRoot 'modules.ps1'
    . $MODULE_PATH -Name @('files')

    $FileMap=@{}
}
process {
    $LiteralPaths=@($Path | % { [Path]::GetFullPath($_) })
    foreach($LiteralPath in $LiteralPaths) {
        foreach($FileFilter in $Filter) {
            Get-ChildItem -LiteralPath:$LiteralPath -Filter:$FileFilter -Recurse:$Recurse | % {
                $Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm $Algorithm).Hash
                $Files=$FileMap[$Hash]
                if ($Files) {
                    $FileMap[$Hash]+=$_
                } else {
                    $FileMap[$Hash]=@($_)
                }
            }
        }
    }
}
end {
    $FileMap.Keys | % {
        [PSCustomObject]@{
            Hash = $_
            Paths = ($FileMap[$_] | select -Unique)
        }
    } | where { $_.Paths.Length -gt 1 }
}
