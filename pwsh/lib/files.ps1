$script:MODULE_NAME='timfiles'

if (-not (Get-Module -Name $script:MODULE_NAME)) {
    Write-Verbose "Importing $script:MODULE_NAME"
    Import-Module "${PSScriptRoot}/${script:MODULE_NAME}.psm1" -ErrorAction Stop
}