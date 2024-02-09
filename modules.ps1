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
        if ($Module) {
            if ($Reimport) {
                Write-Information "Removing ${TimName} before import..."
                Remove-Module $TimName -ErrorAction Stop
                $script:Module=$null
            } else {
                Write-Information "Module ${TimName} is already loaded"
            }
        }
        if (-not $Module) {
            Write-Information "Importing ${TimName}..."
            $script:LibPath=Join-Path $PSScriptRoot 'lib'
            Import-Module $(Join-Path $LibPath "${TimName}.psm1") -ErrorAction Stop
        }
    }
}
