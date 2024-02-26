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
using namespace System.Diagnostics.CodeAnalysis;
using namespace System.IO

$MODULE_PATH=Join-Path -Path $PSScriptRoot -ChildPath '../modules.ps1' -Resolve
. $MODULE_PATH -Name @('string')

if ($IsWindows) {
    Add-Type -AssemblyName Microsoft.VisualBasic
}

$INVALID_CHARS = [IO.Path]::GetInvalidFileNameChars()
$REPLACE_CHARS = @{
    [char]"’" ="'"
    [char]"‘" ="'"
    [char]"`“"="`'"
    [char]"`”"="`'"
    [char]"–" ="-"
    [char]"—" ='-'
    [char]"…" ='...'
}

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

function Remove-Recycle {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$Path
    )
    begin {
        if (-not $IsWindows) {
            $HasTrashPut=Test-Command 'trash-put'
        }
    }
    process {
        $Path | % {
            trap {
                $PSCmdlet.WriteError($_)
            }
            if ($IsWindows) {
                if ($PSCmdlet.ShouldProcess($_, '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile')) {
                    Write-Information "Recycling '$_'..."
                    try {
                        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_, 'OnlyErrorDialogs', 'SendToRecycleBin')
                    } catch {
                        throw [IOException]::new("Could not delete '${_}'", $_.Exception.GetBaseException())
                    }
                }
            } elseif ($HasTrashPut) {
                if ($PSCmdlet.ShouldProcess($_, 'trash-put')) {
                    Write-Information "Trashing '$_'..."
                    trash-put $_
                    if (-not $?) {
                        throw [IOException]"Unable to move '${_}' to trash"
                    }
                }
            } else {
                Write-Warning "Removing '$_'! This cannot be undone!"
                if ($PSCmdlet.ShouldProcess($_, 'Remove-Item')) {
                    Remove-Item -LiteralPath $_ -ErrorAction Continue -WhatIf:$false -Confirm:$false
                }
            }
        }
    }
}

function Rename-SpecialChar {
    param (
        [Parameter(Mandatory,Position=0)]
        [string]$Name
    )
    $NoExt=[IO.Path]::GetFileNameWithoutExtension($Name)

    $sb=[Text.StringBuilder]::new($NoExt.Length)
    foreach($c in [char[]]$NoExt) {
        if ($INVALID_CHARS -contains $c) {
            $sb=$sb.Append('%')
        } else{
            $Replacement=$REPLACE_CHARS[$c]
            if($Replacement) {
                $sb=$sb.Append($Replacement)
            } else {
                $sb=$sb.Append($c)
            }
        }
    }

    return "$($sb.ToString().Trim())$([IO.Path]::GetExtension($Name))"
}

function Test-Command {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [string]$Name
    )
    process {
        Get-Command -Name $Name -ErrorAction SilentlyContinue | Out-Null
        return $?
    }
}
