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
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [string]$ConfigPath = "${HOME}/.config/dosbox-x/dosbox-x.conf",
    [string]$OneDrive = "${HOME}/OneDrive"
)
trap {
    $PSCmdlet.ThrowTerminatingError($_)
}

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '../modules.ps1') -Name @('files')

$ConfigPath=[IO.Path]::GetFullPath($ConfigPath)
$OneDrive=[IO.Path]::GetFullPath($OneDrive)
$DiscPath=Join-Path '%ONEDRIVE%' 'Disc Images'
$DOSBoxPath=Join-Path '%ONEDRIVE%' 'Program Files/DOSBox-X'

$Drives=@{
    'C'=Join-Path '%DOSBOX%' 'win'
    'D'=Join-Path '%ONEDRIVE%' 'My Apps/Desktop/MS-DOS'
    'G'=Join-Path '%ONEDRIVE%' 'Games'
    'I'=Join-Path '%DOSBOX%' 'install'
}

$Settings=@{
    'sdl' = @{
        'fulldouble'        = 'true'
        'autolock'          = 'true'
        'autolock_feedback' = 'none'
        'middle_unlock'     = 'manual'
        'mouse_emulation'   = 'always'
        'mouse_wheel_key'   = '1'
    }

    'dosbox' = @{
        'fastbioslogo' = 'true'
        'startbanner'  = 'false'
        'saveremark'   = 'false'
    }

    'render' = @{
        'aspect'       = 'true'
        'aspect_ratio' = '-1:-1'
        #'scaler'       = 'normal2x forced'
    }

    'video' = @{
        'allow low resolution vesa modes'  = 'false'
        'allow high definition vesa modes' = 'true'
        'allow unusual vesa modes' = 'true'
    }

    'cpu' = @{
        'core'   = 'auto'
        'cycles' = '35620'
    }

    'dos' = @{
        'ver' = '6.22'
    }

    'config' = @{
        'set path' = '+;C:\CMD'
        'set temp' = 'C:\WINDOWS\TEMP'
    }
}

if (-not (Test-Path $ConfigPath)) {
    throw [IO.FileNotFoundException]"Could not find '${ConfigPath}'"
}

if ($PSCmdlet.ShouldProcess('Replace [autoexec]', 'Replace [autoexec] section?', $MyInvocation.MyCommand)) {
    #$TempFile=[IO.Path]::GetTempFileName()
    $Lines=Get-Content $ConfigPath
    $(foreach($Line in $Lines) {
        Write-Output $Line
        if ($Line -eq '[autoexec]') {
            Write-Output '# Lines in this section will be run at startup.'
            Write-Output '# You can put your MOUNT lines here.'
            Write-Output '@ECHO OFF'
            Write-Output "SET ONEDRIVE=${OneDrive}"
            Write-Output "SET DOSBOX=${DOSBOxPath}"
            Write-Output "SET DISCS=${DiscPath}"
            $Drives.Keys | Sort-Object | % {
                Write-Output ('MOUNT {0} "{1}"' -f $_, $Drives[$_])
            }
            Write-Output 'SET TEMP=C:\WINDOWS\TEMP'
            Write-Output 'PATH %PATH%;C:\CMD;C:\QB'
            Write-Output 'CALL C:\VBDOS\BIN\NEW-VARS.BAT'
            Write-Output 'CALL C:\MSVC\BIN\MSVCVARS.BAT'
            Write-Output 'C:'
            Write-Output 'CLS'
            Write-Output 'ECHO.'
            Write-Output 'VER'
            Write-Output 'ECHO.'
            Write-Output "ECHO Type 'win' and press enter to start Windows 3.11"
            Write-Output 'ECHO.'
            break
        }
    }) > $ConfigPath
    #Move-Item -Force -LiteralPath $TempFile -Destination $ConfigPath -Confirm:$false -WhatIf:$false
}
