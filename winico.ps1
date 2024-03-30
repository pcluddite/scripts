using namespace System.IO;

[CmdletBinding(SupportsShouldProcess,ConfirmImpact='Low')]
param(
    [Parameter(Mandatory,Position=0)]
    [ValidateScript({ Test-Path -LiteralPath $_ })]
    [string]$Path,
    [Parameter()]
    [string]$OutputPath,
    [Parameter()]
    [switch]$NoUninstall,
    [Parameter()]
    [int]$Index,
    [Parameter(Position=1)]
    [string]$Name,
    [Parameter()]
    [switch]$Plain
)
trap {
    $PSCmdlet.ThrowTerminatingError($_)
}

. "${PSScriptRoot}/modules.ps1" -Name @('files') -ErrorAction Stop

function Get-UniconDirPath {
    Join-Path $PSScriptRoot 'un-icon'
}

function Get-RmScriptPath {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    Join-Path (Get-UniconDirPath) $Name
}

function Get-TempRmScriptPath {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    Join-Path ([Path]::GetTempPath()) "uninstall-wineico-$($Name.Replace(' ', '-')).tmp"
}

$Path=[Path]::GetFullPath($Path)

if (-not (Test-Path -LiteralPath $Path)) {
    throw [FileNotFoundException]$Path
}

if (-not (Test-Command -Name 'icoextract')) {
    throw [FileNotFoundException]"'icoextract' does not exist. It can be installed using python3-pip.

    pip3 install icoextract[thumbnailer]

See https://github.com/jlu5/icoextract/"
}

if (-not (Test-Command -Name 'icotool')) {
    throw [FileNotFoundException]"'icotool' does not exist. It can be installed from the icoutils package.

    sudo dnf install icoutils"
}

if (-not $Name) {
    $Name=[Path]::GetFileNameWithoutExtension($Path)
}

$TMP_RM_SCRIPT="/tmp/uninstall-wineico-$($Name.Replace(' ', '-'))"
if (Test-Path -LiteralPath $TMP_RM_SCRIPT -and -not $WhatIfPreference) {
    Remove-Item -LiteralPath $TMP_RM_SCRIPT -Confirm:$false -WhatIf:$false
}
