param(
    [Parameter(Mandatory,Position=0)]
    [string]$Path
)

. "${PSScriptRoot}/modules.ps1" -Name @('files', 'string')

$Episodes=@{}

Get-ChildItem -LiteralPath $Path -Recurse -File | % {
    $List=$Episodes[$_.LastWriteTime.Date]
    if ($List -eq $null) {
        $List=@($_)
    } else {
        $List+=$_
    }
    $Episodes[$_.LastWriteTime.Date]=$List
}

$SameName=@{}

$Episodes.Keys | where { $Episodes[$_].Length -gt 1} | % {
    $Episodes[$_] | % {
        $StrippedName=($_.Name | Select-AlphaNumeric)
        $List=$SameName[$StrippedName]
        if ($List -eq $null) {
            $List=@($_)
        } else {
            $List+=$_
        }
        $SameName[$StrippedName]=$List
    }
}

$SameName.Keys | where { $SameName[$_].Length -gt 1} | % { 
    $List=($SameName[$_] | Sort-Object -Descending -Property Length)
    for($i=1; $i -lt $List.Length; ++$i) {
        Remove-Recycle $List[$i] -Verbose
    }
    if ($List[0].Name -ne $_) {
        $NewPath=Join-Path ([IO.Path]::GetDirectoryName($List[0].FullName)) $_
        Move-Item $List[0] -Destination $NewPath
    }
}