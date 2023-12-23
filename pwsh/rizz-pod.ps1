using namespace System.IO
param(
    [Parameter(Position=0)]
    [int]$FirstPage=1,
    [Parameter(Position=1)]
    [int]$LastPage=148,
    [Parameter(Position=3)]
    [string]$OutPath
)

$ErrorActionPreference = 'Stop'
$INVALID_CHARS = "[{0}]" -f [Regex]::Escape([Path]::GetInvalidFileNameChars() -join '')

# Install the module on demand (https://stackoverflow.com/a/60658511/4367864)
if (-not (Get-Module -ErrorAction Ignore -ListAvailable PSParseHTML)) {
    Write-Verbose "Installing PSParseHTML module for the current user..."
    Install-Module -Scope CurrentUser PSParseHTML -ErrorAction Stop
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
    $OutPath=[Path]::Combine($OutPath, "$($PublishDate.Year)", "$($PublishDate.ToString('MM MMMM'))")
    if (!(Test-Path -LiteralPath $OutPath)) {
        New-Item -ItemType Directory -Path $OutPath -ErrorAction Stop | Out-Null
    }
    $OutFile=Join-Path $OutPath $Filename
    if (Test-Path -LiteralPath $OutFile) {
        Write-Warning "Skipped '${Title}' because file already exists in '${OutPath}'"
    } else {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -ErrorAction Inquire
        if ($?) {
            Set-ItemProperty -Path $OutFile -Name LastWriteTime -Value $PublishDate.ToUniversalTime() -ErrorAction Continue
        }
    }
}

$Articles=@()

$TotalPages=$LastPage-$FirstPage+1
for($Page=$FirstPage; $Page -le $LastPage; ++$Page) {
    $CompletedPages=$Page - $FirstPage
    Write-Progress `
        -Activity 'Gathering links to podcast articles' `
        -Status "Page $($CompletedPages + 1) of ${TotalPages}" `
        -PercentComplete ($CompletedPages / $TotalPages * 100)
    Get-Articles -Page $Page | % { $Articles += $_ }
}

$Failed=0
$Completed=0

if ([string]::IsNullOrEmpty($OutPath)) {
    $Articles | ConvertTo-Csv > './articles.csv'
} else {
    $ErrorActionPreference='Continue'
    $Articles | % {
        Write-Progress -Activity 'Total Podcast Download' `
            -Status "Downloading '$($_.Title | Out-Truncated -Width 30)' ($($Completed + 1) out of $($Articles.Length))" `
            -PercentComplete ($Completed / $Articles.Length * 100)
        try {
            Get-Episode -Title $_.Title -Url $_.Url -PublishDate $_.PublishDate -OutPath $OutPath
        } catch {
            Write-Error "Failed to download '$($_.Title)' from $($_.Url)"
            Write-Error $_
            ++$Failed
        }
        ++$Completed
    }
}

Write-Host "Downloaded $($Completed - $Failed) episode(s) successfully"