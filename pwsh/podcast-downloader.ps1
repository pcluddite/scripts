<#
 :
 : Copyright 2023 Timothy Baxendale (pcluddite@outlook.com)
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
using namespace System.IO

param(
    [Parameter(Position=0)]
    [string]$Url = 'https://feeds.megaphone.fm/rizzutoshow',
    [Parameter(Position=1)]
    [string]$OutPath = (Join-Path $PSScriptRoot 'Rizzuto Show'),
    [Parameter(Position=2)]
    [int]$Year = 0,
    [Parameter(Position=3)]
    [int]$Month = 0
)

$INVALID_CHARS = "[{0}]" -f [Regex]::Escape([Path]::GetInvalidFileNameChars() -join '')

function Get-FileName {
    param (    
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Url
    )
    $nStart = $Url.LastIndexOf('/')
    $nEnd = $Url.LastIndexOf('?')
    if ($nEnd -le $nStart) {
        $nEnd = $Url.Length
    }
    $ext = [Path]::GetExtension($Url.Substring($nStart + 1, $nEnd - $nStart - 1))
    return "${Title}${ext}" -replace $INVALID_CHARS, '%'
}

function Out-Truncated {
    param(
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [psobject]$InputObject,
        [Parameter(Mandatory,Position=1)]
        [int]$Width
    )
    $str = ($InputObject | Out-String -NoNewline)
    if ($str.Length -gt $Width) {
        return "$($str.Substring(0, $Width - 3))..."
    }
    return $str
}

# Create the download folder if it doesn't exist
if (!(Test-Path -LiteralPath $OutPath)) {
    New-Item -ItemType Directory -Path $OutPath -ErrorAction Stop | Out-Null
}

# Download and filter the RSS feed
try {
    $RSS = (Invoke-RestMethod $Url | where { 
            $PubDate = [DateTime]$_.pubDate
            $_.episodeType -eq 'full' `
                -and ($Year -le 0 -or $PubDate.Year -ge $Year) `
                -and ($Month -le 0 -or $PubDate.Month -ge $Month) 
        }
    )
    [Array]::Reverse($RSS)
} catch {
    Write-Error 'Failed to download and filter RSS Feed'
    throw $_
}

$Successful = 0
$Completed = 0

# Loop through each episode and download it
foreach ($Episode in $RSS) {
    $Url = $Episode.enclosure.url
    $PubDate = [DateTime]$Episode.pubDate

    $FileName = Get-FileName -Title ($Episode.title | select -First 1) -Url $Url
    $OutFile = [Path]::Combine($OutPath, "$($PubDate.Year)", "$($PubDate.ToString('MM MMMM'))")

    if (!(Test-Path -LiteralPath $OutFile)) {
        New-Item -ItemType Directory -Path $OutFile -ErrorAction Stop | Out-Null
    }

    $OutFile = Join-Path $OutFile $FileName
    Write-Progress -Activity 'Total Podcast Download' `
        -Status "Downloading '$($Episode.title | Out-Truncated -Width 30)' ($($Completed + 1) out of $($RSS.Length))" `
        -PercentComplete ([double]$Completed / $RSS.Length * 100)

    # Check if the file already exists
    if (Test-Path -LiteralPath $OutFile) {
        Write-Warning "Skipped '$($Episode.title)' because file already exists in '$([Path]::GetDirectoryName($OutFile))'"
    } else {
        Write-Host "Downloading $($Episode.title) to '${OutFile}'..."
        Invoke-WebRequest $Url -OutFile $OutFile -ErrorAction Inquire
        if ($?) {
            ++$Successful
            Set-ItemProperty -Path $OutFile -Name LastWriteTime -Value $PubDate.ToUniversalTime() -ErrorAction Continue
        }
    }
    ++$Completed
}

if ($Successful -eq 0) {
    Write-Host 'No episodes were downloaded'
} elseif ($Successful -eq $RSS.Length) {
    Write-Host "All episodes downloaded successfully!"
} elseif ($Successful -eq 1) {
    Write-Host "1 episode out of $($RSS.Length) was downloaded"
} else {
    Write-Host "${Successful} episodes out of $($RSS.Lenth) were downloaded"
}
