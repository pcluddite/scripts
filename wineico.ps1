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

function Read-Icon {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$IconPath,
        [Parameter(Mandatory,ValueFromRemainingArguments)]
        [string[]]$Parameters
    )
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    $IsIcon = $false
    $Index  = 667
    $Height = 0
    $Width  = 0
    $Depth  = 0x0D
    $Pallet = 0x0F
    foreach($Arg in $Parameters) {
        switch -wildcard ($arg) {
            '--icon' {
                $IsIcon=$true
                break
            }
            '--height=*' {
                $Height=$_.Substring($_.IndexOf('=')+1)
                break
            }
            '--width=*' {
                $Width=$_.Substring($_.IndexOf('=')+1)
                break
            }
            '--bit-depth=*' {
                $Depth=$_.Substring($_.IndexOf('=')+1)
                break
            }
            '--palette-size=*' {
                $Pallet=$_.Substring($_.IndexOf('=')+1)
                if ($Pallet -match '[0-9]+' -and [int]$Pallet -ne 0) {
                    $Pallet=[int]$Pallet - 1
                }
                break
            }
            '--index=*' {
                $Index=$_.Substring($_.IndexOf('=')+1)
                break
            }
            Default {
                trap {
                    $PSCmdlet.WriteError($_)
                }
                throw "unrecognized option ${_}"
            }
        }
    }

    if (-not $IsIcon) {
        throw 'Parameters were not for an icon'
    }

    $Depth=([int]$Depth).ToString('X').PadLeft(2,'0')
    $Depth="0x${Depth}"

    $Pallet=([int]$Pallet).ToString('X').PadLeft(2,'0')
    $Pallet="0x${Pallet}"

    $PngPath="${OutputPath}/${Height}x${Width}/apps"
    $PngName="${Depth}${Pallet}_$($Name.Replace(' ', '_')).${Index}.png"

    if (-not (Test-Path -LiteralPath $PngPath)) {
        New-Item -Path $PngPath -WhatIf:$false -Confirm:$false
    }
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
