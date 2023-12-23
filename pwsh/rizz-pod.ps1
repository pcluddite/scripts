using namespace System.IO
param(
    [Parameter(Mandatory,Position=0)]
    [int]$Page
)

$ErrorActionPreference = 'Stop'
$INVALID_CHARS = "[{0}]" -f [Regex]::Escape([Path]::GetInvalidFileNameChars() -join '')

# Install the module on demand (https://stackoverflow.com/a/60658511/4367864)
if (-not (Get-Module -ErrorAction Ignore -ListAvailable PSParseHTML)) {
    Write-Verbose "Installing PSParseHTML module for the current user..."
    Install-Module -Scope CurrentUser PSParseHTML -ErrorAction Stop
}
  
function Get-Filename {
    param (    
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$Uri
    )
    $nStart = $Uri.LastIndexOf('/')
    $nEnd = $Uri.LastIndexOf('?')
    if ($nEnd -le $nStart) {
        $nEnd = $Uri.Length
    }
    $ext = [Path]::GetExtension($Uri.Substring($nStart + 1, $nEnd - $nStart - 1))
    return "${Title}${ext}" -replace $INVALID_CHARS, '%'
}

function Get-Mp3Uri() {
    param(
        [Parameter(Mandatory,Position=0)]
        [Alias('Uri')]
        [string[]]$EpisodeUrl
    )
    process {
        $EpisodeUrl | % {
            $Response=(Invoke-WebRequest -Uri $_)
            
            $HtmlNode=($Response.Content | ConvertFrom-HTML)

            $Script=($HtmlNode.SelectNodes("//div[@class='entry-content']/script") | % { $_.InnerText.Trim() } | where { $_ -ne '' } | select -First 1)

            $endIdx=$Script.LastIndexOf(';')
            $startIdx=$Script.IndexOf('=') + 1
            $Json=($Script.Substring($startIdx, $endIdx - $startIdx).Trim() | ConvertFrom-Json)
            return $Json.episode.media.mp3
        }
    }
}

function Get-Articles {
    param(
        [Parameter(Mandatory,Position=0)]
        [int]$Page
    )

    $PageUrl="https://www.1057thepoint.com/podcasts/the-rizzuto-show/?episode_page=${Page}"

    $Response=Invoke-WebRequest -Uri $PageUrl
    $HtmlNode=($Response.Content | ConvertFrom-HTML)

    # select article nodes for latest episodes
    $Articles=$HtmlNode.SelectNodes("//div[@class='latest-episodes']/article")

    $Articles | % { $_.InnerHtml | ConvertFrom-HTML } | % {     
        # select link node to each article from post-title class
        $LinkNode=$_.SelectSingleNode("//*[@class='post-title']/a")
        return [PSCustomObject]@{
            # decode innerText to remove &###;
            Title=[Net.WebUtility]::HtmlDecode($LinkNode.InnerText)

            # get url from href attribute
            Url=$LinkNode.Attributes['href'].Value
            
            # select published date from time node
            PublishDate=[DateTime]$_.SelectSingleNode("//time").InnerText
        }
    }
}

function Get-Episode {
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Title,
        [Parameter(Mandatory,Position=1)]
        [string]$Url,
        [Parameter(Mandatory,Position=2)]
        [DateTime]$PublishDate,
        [Parameter(Mandatory,Position=3)]
        [string]$OutPath
    )
    $Uri=(Get-Mp3Uri $Url)
    $Filename=Get-Filename -Title $Title -Uri $Uri
    $FullPath=Join-Path $OutPath $Filename
    Invoke-WebRequest -Uri $Uri -OutFile $FullPath
}

Get-Articles -Page $Page