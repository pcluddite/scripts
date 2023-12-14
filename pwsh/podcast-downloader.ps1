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
    [string]$FeedUrl = 'https://feeds.megaphone.fm/rizzutoshow',
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

# Create the download folder if it doesn't exist
if (!(Test-Path $OutPath)) {
    New-Item -ItemType Directory -Path $OutPath | Out-Null
}

# Download the RSS feed
$RSS = (Invoke-RestMethod $FeedUrl | where { 
        $PubDate = [DateTime]$_.pubDate
        $_.episodeType -eq 'full' `
            -and ($Year -le 0 -or $PubDate.Year -ge $Year) `
            -and ($Month -le 0 -or $PubDate.Month -ge $Month) 
    }
)
[Array]::Reverse($RSS)

# Loop through each episode and download it
foreach ($Episode in $RSS) {
    $Url = $Episode.enclosure.url
    $PubDate = [DateTime]$Episode.pubDate

    $FileName = Get-FileName -Title ($Episode.title | select -First 1) -Url $Url
    $OutFile = [Path]::Combine($OutPath, "$($PubDate.Year)", "$($PubDate.ToString('MM MMMM'))")

    if (!(Test-Path $OutFile)) {
        New-Item -ItemType Directory -Path $OutFile | Out-Null
    }

    $OutFile = Join-Path $OutFile $FileName

    # Check if the file already exists
    if (Test-Path $OutFile) {
        Write-Error "'${OutFile}' already exists"
    } else {
        Write-Host "Downloading $($Episode.title) to '${OutFile}'..."
        Invoke-WebRequest $Url -OutFile $OutFile -ErrorAction Inquire
        Set-ItemProperty -Path $OutFile -Name LastWriteTime -Value $PubDate.ToUniversalTime() -ErrorAction Continue
    }
}

Write-Host "All episodes downloaded successfully!"
