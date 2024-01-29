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

function Remove-Recycle {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$Path
    )
    process {
        $Path | % {
            if ($IsLinux) {
                if ($PSCmdlet.ShouldProcess($_, 'trash-put')) {
                    Write-Informat "Trashing '$_'..."
                    trash-put $_
                    if (-not $?) {
                        Write-Error -Exception ([IOException]"Unable to move '${_}' to trash")
                    }
                }
            } else {
                if ($PSCmdlet.ShouldProcess($_, '[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile')) {
                    Write-Information "Recycling '$_'..."
                    try {
                        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_, 'OnlyErrorDialogs', 'SendToRecycleBin')
                    } catch {
                        Write-Error -Exception $_.Exception.GetBaseException()
                    }
                }
            }
        }
    }
}

function Remove-SpecialChars {
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
            if($Replacement -eq $null) {
                $sb=$sb.Append($c)
            } else {
                $sb=$sb.Append($Replacement)
            }
        }
    }

    return "$($sb.ToString().Trim())$([IO.Path]::GetExtension($Name))"
}
