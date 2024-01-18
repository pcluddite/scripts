param(
    [string]$SwapVolume='/swap',
    [string]$SwapFile='swapfile'
)

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

function New-SwapFile {
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
        [string]$ResumePath
    )
    $FIELD='add_dracutmodules'
    $VALUE='resume'
    $Lines=@(Get-Content -Path $ResumePath)
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
    Write-Output "${FIELD}+=`" ${VALUE} `"" >> $RESUME_PATH
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

New-SwapFile -SwapVolume $SwapVolume
Add-ResumeModule '/etc/dracut.conf.d/resume.conf'
