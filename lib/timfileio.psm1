using namespace System.Diagnostics.CodeAnalysis;

. (Join-Path -Path $PSScriptRoot -ChildPath '../modules.ps1' -Resolve -ErrorAction Stop)

function Select-Text {
    [SuppressMessageAttribute('PSReviewUnusedParameter','IgnoreCase',Justification='false positive')]
    param (
        [Parameter(Mandatory,Position=0)]
        [string]$Pattern,
        [Parameter(Mandatory,Position=1)]
        [string]$Path,
        [switch]$Recurse,
        [switch]$Regex,
        [switch]$IgnoreCase,
        [switch]$Plain
    )
    if (-not $Regex) {
        $Pattern=(ConvertTo-Regex -Pattern $Pattern)
        Write-Verbose "Matching regex pattern '${Pattern}'"
    }
    if (-not $Plain) {
        $Highlight="$($PSStyle.Foreground.Magenta)$($PSStyle.Bold)"
    }
    Get-ChildItem -Path $Path -Recurse:$Recurse | % {
        $File=$_
        $Line=1
        Get-Content $File | % {
            if (($IgnoreCase -and $_ -imatch $Pattern) `
                              -or $_ -cmatch $Pattern) {
                [PSCustomObject]@{
                    File = $File
                    Line = $Line
                    Text = $(
                        if ($Plain) {
                            $_
                        } else {
                            ($_.Split($Matches[0])) -join "${Highlight}$($Matches[0])$($PSStyle.Reset)"
                        }
                    )
                }
            }
            $Line=$Line + 1
        }
    }
}