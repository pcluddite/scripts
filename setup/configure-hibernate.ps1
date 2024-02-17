param(
    [string]$SwapVolume='/swap',
    [string]$SwapFile='swapfile'
)

$GIT_PATH=Join-Path -Path $PSScriptRoot -ChildPath '..'
$LIB_PATH=Join-Path -Path $GIT_PATH -ChildPath 'lib'

$ErrorActionPreference='Stop'
$InformationPreference='Continue'

function Get-SwapSize {
    [OutputType([int])]
    [CmdletBinding()]
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
    return [int][Math]::Round(($SwapSize * 2) + $SwapSize, [MidpointRounding]::AwayFromZero);
}

function New-BtrfsVolume {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param(
        [Parameter(Position=0)]
        [string]$SwapVolume = "/swap"
    )
    process {
        trap {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        if ($PSCmdlet.ShouldProcess("Run 'btrfs subvolume create ${SwapVolume}'", $SwapVolume, 'brfs')) {
            btrfs subvolume create $SwapVolume
            if (-not $?) {
                throw 'Failed to create volume'
            }
        }
    }
}

function New-SwapFile {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param(
        [Parameter(Position=0)]
        [string]$SwapVolume = "/swap",
        [Parameter(Position=1)]
        [string]$SwapFile = "swapfile"
    )
    begin {
        $SwapPath=[IO.Path]::GetFullPath((Join-Path -Path $SwapVolume -ChildPath $SwapFile))

        if (Test-Path -LiteralPath $SwapPath) {
            Write-Information "${SwapPath} will not be created because it already exists"
            return
        }
    }
    process {
        trap {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $Size="$(Get-SwapSize -ErrorAction Stop)G"

        if ($PSCmdlet.ShouldProcess("Creating ${SwapPath} of size ${Size}", "Create ${SwapPath} with size ${Size}?", 'mkswap')) {
            New-Item -Path $SwapPath -ItemType File -WhatIf:$false -Confirm:$false | Out-Null

            # Disable Copy On Write on the file
            chattr +C $SwapPath
            if (-not $?) {
                throw [IO.IOException]'Unable to disable copy-on-write attribute'
            }

            # allocate space
            fallocate --length $Size $SwapPath
            if (-not $?) {
                throw [IO.IOException]"Unable to allocate ${Size} to ${SwapPath}"
            }

            # mkswap
            chmod 600 $SwapPath
            if (-not $?) {
                throw [IO.IOException]"Unable to set permissions of ${SwapPath} to 600"
            }

            mkswap $SwapPath
            if (-not $?) {
                throw [IO.IOException]"Unable to make ${SwapPath} a swap file"
            }

            Write-Information "Created swap file ${SwapPath} with size ${Size}"
        }
    }
}

function Add-ResumeModule {
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath
    )
    $ResumeLine="add_dracutmodules+=`" resume `""
    if ($PSCmdlet.ShouldProcess($ModulePath, "Append ${ResumeLine}")) {
        Write-Output $ResumeLine >> $ModulePath
        Write-Information "Added resume to ${ModulePath}"
    }

    if ($PSCmdlet.ShouldProcess($ModulePath, "drcut -f")) {
        Write-Information "Running dracut -f..."
        dracut -f
        Write-Information "Finished dracut -f"
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
    [CmdletBinding(SupportsShouldProcess,ConfirmImpact='High')]
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
        $GrubbyArgs=@("--remove-args=`"${GrubbyArgs}`"")
    } else {
        Write-Information "Adding grub args `"${GrubbyArgs}`""
        $GrubbyArgs=@("--args=`"${GrubbyArgs}`"")
    }
    $GrubbyArgs+='--update-kernel=ALL'
    if ($PSCmdlet.ShouldProcess("Running 'grubby $($GrubbArgs -join ' ')'", $GrubbyArgs[0], 'grubby')) {
        grubby @GrubbyArgs
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
Environment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1" > "${LogindPath}/override.conf" | Out-Null

    Write-Information "Created ${LogindPath}/override.conf"

    $HibernatedPath='/etc/systemd/system/systemd-hibernate.service.d'

    if (Test-Path $HibernatedPath) {
        Write-Information "${HibernatedPath} already exists"
    } else {
        New-Item -Path $HibernatedPath -ItemType Directory | Out-Null
        Write-Information "Created ${HibernatedPath}"
    }

"[Service]
Environment=SYSTEMD_BYPASS_HIBERNATION_MEMORY_CHECK=1" > "${HibernatedPath}/override.conf" | Out-Null

    Write-Information "Created ${HibernatedPath}/override.conf"
}

New-SwapFile -SwapVolume $SwapVolume -SwapFile $SwapFile
Add-ResumeModule '/etc/dracut.conf.d/resume.conf'

$SwapPath="${SwapVolume}/${SwapFile}"

Update-Grub -SwapPath $SwapPath
Add-HibernateService -SwapPath $SwapPath
Disable-SystemdCheck

Write-Information 'Hibernation enabled. Restart system for changes to take effect.'

if ($(getenforce) -ieq 'enabled') {
    Write-Warning 'SELinux is enabled.'
    Write-Warning "You may need to run the following commands to permit hibernation:
$ audit2allow -b
#============= systemd_sleep_t ==============
allow systemd_sleep_t unlabeled_t:dir search;
$ cd /tmp
$ audit2allow -b -M systemd_sleep
$ semodule -i systemd_sleep.pp"
}
