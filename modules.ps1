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

[SuppressMessageAttribute('PSReviewUnusedParameter','Reimport',Justification='false positive')]
param(
    [Parameter(Mandatory,Position=0,ValueFromPipeline)]
    [Alias('Name')]
    [string[]]$ModuleName,
    [Parameter()]
    [Alias('Reload')]
    [switch]$Reimport
)
process {
    $ModuleName | % {
        $script:TimName="tim${_}"
        $script:Module=Get-Module -Name $TimName
        if ($Module) {
            if ($Reimport) {
                $PSCmdlet.WriteVerbose("Removing ${TimName} before import...")
                Remove-Module $TimName -ErrorAction Stop -Verbose:$false
                $script:Module=$null
            } else {
                $PSCmdlet.WriteVerbose("Module ${TimName} is already loaded")
            }
        }
        if (-not $Module) {
            $PSCmdlet.WriteVerbose("Importing ${TimName}...")
            $script:LibPath=Join-Path $PSScriptRoot 'lib'
            Import-Module $(Join-Path $LibPath "${TimName}.psm1") -ErrorAction Stop -Verbose:$false
        }
    }
}
