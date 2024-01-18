param(
    [string]$SwapVolume='/swap',
    [string]$SwapFile='swapfile'
)

$GIT_PATH=Join-Path -Path $PSScriptRoot -ChildPath '..'
$LIB_PATH=Join-Path -Path $GIT_PATH -ChildPath 'lib'

$ErrorActionPreference='Stop'

function Assert-Truth {
    param(
        [Parameter(Position=0,Mandatory=$true)]
        [bool]$Assertion,
        [Parameter(Position=1)]
        [string]$ErrorMessage='Assertion failed'
    )
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    if (-not $Assertion) {
        throw $ErrorMessage
    }
}

function Get-SwapSize {
    [OutputType([double])]
    param()
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    $SwaponOutput=(swapon --show=SIZE --noheading)

    $endIdx = $SwaponOutput.IndexOf('G')
    if ($endIdx -lt 0) {
        throw "swapon did not return a value in an expected unit: ${SwaponOutput}"
    }

    [double]$SwapSize=$SwaponOutput.Substring(0, $endIdx)
    return ($SwapSize * 2) + $SwapSize;
}

function Build-SwapFile {
    param(
        [Parameter(Position=0)]
        [string]$SwapVolume = "/swap",
        [Parameter(Position=1)]
        [string]$SwapFile = "swapfile"
    )
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    $SwapPath="${SwapVolume}/${SwapFile}"

    if (Test-Path $SwapPath) {
        Write-Information "${SwapPath} will not be created because it already exists"
        return
    }

    btrfs subvolume create $SwapVolume
    if (-not $?) {
        throw 'Failed to create volume'
    }

    Write-Information "Created subvolume ${SwapVolume}"

    $Size="$(Get-SwapSize)G"

    New-Item -Path $SwapPath -ItemType File | Out-Null

    # Disable Copy On Write on the file
    chattr +C $SwapPath
    fallocate --length $Size $SwapPath
    chmod 600 $SwapPath
    mkswap $SwapPath

    Write-Information "Created swap file ${SwapPath} with size ${Size}"
}

function Add-ResumeModule {
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath
    )
    $FIELD='add_dracutmodules'
    $VALUE='resume'
    if (Test-Path $ModulePath) {
        $Lines=@(Get-Content -Path $ModulePath)
        foreach($Line in $Lines) {
            if($Line -like "${FIELD}+=*") {
                if ($Line -notlike "${FIELD}+=`"*${VALUE}*`"") {
                    $OLDVAL=$Line.Substring($FIELD.Length + 2) # 2 for +=
                    $OLDVAL=$OLDVAL.Substring(1, $OLDVAL.LastIndexOf('"') - 1).Trim()
                    $VALUE="${VALUE} ${OLDVAL}"
                }
                break
            }
        }
    } else {
        Write-Output "${FIELD}+=`" ${VALUE} `"" >> $ModulePath
    }
}

function Get-SwapUuid {
    param(
        [Parameter(Mandatory)]
        [string]$SwapPath
    )
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    $UUID=findmnt -no UUID -T $SwapPath
    if (-not $? -or -not $UUID) {
        throw 'Could not find UUID'
    }
    return $UUID
}

function Build-BtrfsMapPhysical {
    [CmdletBinding()]
    param()
    trap {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    $ToolPath=Join-Path -Path $LIB_PATH -ChildPath 'btrfs_map_physical.c'
    $OutPath=Join-Path -Path $LIB_PATH -ChildPath 'tmp-btrfs_map_physical'
    Write-Information "Building ${ToolPath}..."
    gcc -O2 -o $OutPath $ToolPath
    if (-not $?) {
        throw "Unable to compile ${ToolPath}"
    }
}

function Invoke-BtrfsMapPhysical {
    param(
        [Parameter(Mandatory)]
        [string]$SwapPath
    )
    $OutPath=Join-Path -Path $LIB_PATH -ChildPath 'tmp-btrfs_map_physical'
    & $OutPath $SwapPath
}

function Get-PhysicalOffset {
    [OutputType([double])]
    param(
        [Parameter(Mandatory)]
        [string]$SwapPath
    )
    Invoke-BtrfsMapPhysical -SwapPath $SwapPath | select -Skip 1 -First 1 | % {
        Write-Verbose $_
        $_.Split("`t")
    } | select -Last 1
}

function Get-PageSize {
    [OutputType([double])]
    param()
    getconf PAGESIZE
}

function Get-ResumeOffset {
    [OutputType([double])]
    param(
        [string]$SwapPath
    )
    Build-BtrfsMapPhysical
    $Offset=Get-PhysicalOffset -SwapPath $SwapPath
    Write-Information "Physical offset found at ${Offset}"

    $PageSize=Get-PageSize
    Write-Information "Kernel page size is ${PageSize}"

    return $Offset / $PageSize
}

function Update-Grub {
    param(
        [Parameter(Mandatory)]
        [string]$SwapPath,
        [switch]$Remove
    )
    $SwapUuid=Get-SwapUuid -SwapPath $SwapPath
    Write-Information "UUID for ${SwapPath} is $SwapUuid"

    $ResumeOffset=Get-ResumeOffset -SwapPath $SwapPath
    Write-Information "Resume offset is ${ResumeOffset}"

    $GrubbyArgs="resume=UUID=${SwapUuid} resume_offset=${ResumeOffset}"
    if ($Remove) {
        Write-Information "Removing grub args `"${GrubbyArgs}`""
        grubby grubby --remove-args="${GrubbyArgs}" --update-kernel=ALL
    } else {
        Write-Information "Adding grub args `"${GrubbyArgs}`""
        grubby --args="${GrubbyArgs}" --update-kernel=ALL
    }
}

function Add-HibernateService {
    param(
        [Parameter(Mandatory)]
        [string]$SwapPath
    )
"[Unit]
Description=Enable swap file and disable zram before hibernate
Before=systemd-hibernate.service

[Service]
User=root
Type=oneshot
ExecStart=/bin/bash -c `"/usr/sbin/swapon ${SwapPath} && /usr/sbin/swapoff /dev/zram0`"

[Install]
WantedBy=systemd-hibernate.service" > '/etc/systemd/system/hibernate-preparation.service'

    Write-Information 'Enabling hibernate-preparation.service'
    systemctl enable hibernate-preparation.service

"[Unit]
Description=Disable swap after resuming from hibernation
After=hibernate.target

[Service]
User=root
Type=oneshot
ExecStart=/usr/sbin/swapoff ${SwapPath}

[Install]
WantedBy=hibernate.target" > '/etc/systemd/system/hibernate-resume.service'

    Write-Information 'Enabling hibernate-resume.service'
    systemctl enable hibernate-resume.service
}

function Disable-SystemdCheck {
    [CmdletBinding()]
    param()
    $LogindPath='/etc/systemd/system/systemd-logind.service.d'

    if (Test-Path $LogindPath) {
        Write-Information "${LogindPath} already exists"
    } else {
        New-Item -Path $LogindPath -ItemType Directory | Out-Null
        Write-Information "Created ${LogindPath}"
    }

"[Service]
Environment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1
" > "${LogindPath}/override.conf" | Out-Null

    Write-Information "Created ${LogindPath}/override.conf"

    $HibernatedPath='/etc/systemd/system/systemd-hibernate.service.d'

    if (Test-Path $HibernatedPath) {
        Write-Information "${HibernatedPath} already exists"
    } else {
        New-Item -Path $HibernatedPath -ItemType Directory | Out-Null
        Write-Information "Created ${HibernatedPath}"
    }

"[Service]
Environment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1
" > "${HibernatedPath}/override.conf" | Out-Null

    Write-Information "Created ${HibernatedPath}/override.conf"
}

Build-SwapFile -SwapVolume $SwapVolume -SwapFile $SwapFile -InformationAction Continue
Add-ResumeModule '/etc/dracut.conf.d/resume.conf' -InformationAction Continue

$SwapPath="${SwapVolume}/${SwapFile}"

Update-Grub -SwapPath $SwapPath -InformationAction Continue
Add-HibernateService -SwapPath $SwapPath -InformationAction Continue
Disable-SystemdCheck -InformationAction Continue

Write-Information 'Hibernation enabled. Restart system for changes to take effect.'
