[CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
param(
    [string]$ConfigPath = "${HOME}/.dosbox/dosbox-0.74-3.conf",
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
