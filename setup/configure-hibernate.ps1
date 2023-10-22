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

