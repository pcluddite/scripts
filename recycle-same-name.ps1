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