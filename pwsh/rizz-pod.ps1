using namespace System.IO
param(
    [Parameter(Mandatory,Position=0)]
    [int]$Page
)

$ErrorActionPreference = 'Stop'

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
function Out-Unescape() {
    param(
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [string[]]$InputString
    )
    begin {
        $sb = New-Object -TypeName System.Text.StringBuilder
    }
    process {
        $InputString | % {
            if ($_ -eq '') {
                return $_
            }
            $sb=$sb.Clear()
            $i = 0
            for(; $i -lt $_.Length - 1; ++$i) {
                $c=$_[$i]
                if ($c -eq '\') {
                    $c=$_[++$i]
                    if ($c -eq 'n') {
                        $c=[char]"`n"
                    } elseif ($c -eq 'r') {
                        $c=[char]"`r"
                    } elseif ($c -eq 't') {
                        $c=[char]"`t"
                    } elseif ($c -eq '0') {
                        $c=[char]"`0"
                    } elseif ($c -eq 'b') {
                        $c=[char]"`b"
                    }
                }
                $sb=$sb.Append($c)
            }
            $sb=$sb.Append($_[$i])
            return $sb.ToString()
        }
    }
}

function Get-Mp3Uri() {
    param(
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [string[]]$Url
    )
    process {
        $Url | % {
            $EpResponse=(Invoke-WebRequest -Uri $_)
            $html=$EpResponse.Content
            $Field = '"mp3":"'
            $startIdx=$html.IndexOf($Field) + $Field.Length
            $endIdx=$html.IndexOf('"', $startIdx)
            $html.Substring($startIdx, $endIdx - $startIdx) | Out-Unescape
        }
    }
}

$PageUrl = "https://www.1057thepoint.com/podcasts/the-rizzuto-show/?episode_page=${Page}"
$Response = Invoke-WebRequest -Uri $PageUrl
$Response.Links | where { $_.href -like 'https://www.1057thepoint.com/episode/*' } | % { 
    $Title=$_.outerHTML.Substring($_.outerHTML.IndexOf('>') + 1)
    $Title=$Title.Remove($Title.LastIndexOf('<'))
    $Mp3Uri = $($_.href | Get-Mp3Uri)
    Write-Host "${Title}: ${Mp3Uri}"
    Invoke-WebRequest -Uri $Mp3Uri -OutFile (Get-FileName -Title $Title -Url $Mp3Uri)
}