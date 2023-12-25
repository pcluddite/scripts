param(
    [Parameter(Mandatory,Position=0,ValueFromPipeline)]
    [Alias('Name')]
    [string[]]$ModuleName,
    [Parameter()]
    [Alias('Reload')]
    [switch]$Reimport
)
process {
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    $ModuleName | % {
        $script:TimName="tim${_}"
        $script:Module=Get-Module -Name $TimName
        if ($Module -ne $null) {
            if ($Reimport) {
                $PSCmdlet.WriteVerbose("Removing ${TimName} before import")
                Remove-Module $TimName -ErrorAction Stop
                $script:Module=$null
            } else {
                $PSCmdlet.WriteVerbose("Module ${TimName} is already loaded")
            }
        }
        if ($Module -eq $null) {
            $PSCmdlet.WriteVerbose("Importing ${TimName}")
            $script:LibPath=Join-Path $PSScriptRoot 'lib'
            Import-Module $(Join-Path $LibPath "${TimName}.psm1") -ErrorAction Stop
        }
    }
}
