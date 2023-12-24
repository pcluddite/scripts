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
        $TimName="tim${_}"
        $script:Module=Get-Module -Name $TimName
        if ($script:Module -ne $null) {
            if ($Reimport) {
                $PSCmdlet.WriteVerbose("Removing ${TimName} before import")
                Remove-Module $TimName -ErrorAction Stop
                $script:Module=$null
            } else {
                $PSCmdlet.WriteVerbose("Module ${TimName} is already loaded")
            }
        }
        if ($script:Module -eq $null) {
            $PSCmdlet.WriteVerbose("Importing ${TimName}")
            Import-Module "${PSScriptRoot}/${TimName}.psm1" -ErrorAction Stop
        }
    }
}
