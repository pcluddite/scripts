param(
    [string]$SwapVolume='/swap'
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
    $SwaponOutput=(swapon --show=SIZE --noheading)

    $endIdx = $SwaponOutput.IndexOf('G')
    if ($endIdx -lt 0) {
        throw "swapon did not return a value in an expected unit: ${SwaponOutput}"
    }

    [double]$SwapSize=$SwaponOutput.Substring(0, $endIdx) 
    return ($SwapSize * 2) + $SwapSize;
}

$SwapFile="${SwapVolume}/swapfile"

if (Test-Path $SwapFile) {
    Write-Verbose "${SwapFile} will not be created because it already exists"
} else {
    btrfs subvolume create $SwapVolume
    Write-Verbose "Subvolume ${SwapVolume} created"
}

New-Item -Path $SwapFile -ItemType File
# Disable Copy On Write on the file
chattr +C $SwapFile
fallocate --length 24G $SwapFile
chmod 600 $SwapFile 
mkswap $SwapFile

$RESUME_PATH='/etc/dracut.conf.d/resume.conf'

$FIELD='add_dracutmodules'
$VALUE='resume'
$Lines=@(Get-Content -Path $RESUME_PATH)
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
