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
