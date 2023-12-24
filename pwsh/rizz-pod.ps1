using namespace System.IO
[CmdletBinding(DefaultParameterSetName='download')]
param(
    [Parameter(Mandatory,Position=0,ParameterSetName='downloadRange')]
    [Parameter(Mandatory,Position=0,ParameterSetName='csvRange')]
    [Alias('StartPage','First','Start')]
    [int]$FirstPage=1,
    [Parameter(Mandatory,Position=1,ParameterSetName='downloadRange')]
    [Parameter(Mandatory,Position=1,ParameterSetName='csvRange')]
    [Alias('EndPage','Last','End','StopPage','Stop')]
    [int]$LastPage=148,
    [Parameter(Position=1,ParameterSetName='download')]
    [Parameter(Position=1,ParameterSetName='csv')]
    [int]$Page=1,
    [Parameter(ParameterSetName='csvRange')]
    [Parameter(ParameterSetName='csv')]
    [switch]$MediaLinks,
    [Parameter(Mandatory,Position=0,ParameterSetName='download')]
    [Parameter(Mandatory,Position=2,ParameterSetName='downloadRange')]
    [string]$OutPath,
    [Parameter(Position=2,ParameterSetName='download')]
    [Parameter(Position=3,ParameterSetName='downloadRange')]
    [string]$CsvPath,
    [Parameter(ParameterSetName='download')]
    [Parameter(ParameterSetName='downloadRange')]
    [double]$RedownloadSize = 0 # in MB
)

$ErrorActionPreference = 'Stop'

. "${PSScriptRoot}/modules.ps1" -Name @('string', 'files')

# Install the module on demand (https://stackoverflow.com/a/60658511/4367864)
if (-not (Get-Module -ErrorAction Ignore -ListAvailable PSParseHTML)) {
    Write-Verbose "Installing PSParseHTML module for the current user..."
    Install-Module -Scope CurrentUser PSParseHTML -ErrorAction Stop
}

function Get-Filename {
    param (    
        [Parameter(Mandatory,Position=0)]
        [string]$Title,
        [Parameter(Position=1)]
        [string]$Uri
    )

    if ([string]::IsNullOrEmpty($Uri)) {
        $ext='.mp3'
    } else {
        $nStart = $Uri.LastIndexOf('/')
        $nEnd = $Uri.LastIndexOf('?')
        if ($nEnd -le $nStart) {
            $nEnd = $Uri.Length
        }
        $ext=[Path]::GetExtension($Uri.Substring($nStart + 1, $nEnd - $nStart - 1))
    }
    return (Remove-SpecialChars -Name "${Title}${ext}")
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
            Page=$Page

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
        [string]$OutPath,
        [Parameter()]
        [double]$RedownloadSize = 120
    )
    $Filename=Get-Filename -Title $Title
    $OutPath=[Path]::Combine($OutPath, "$($PublishDate.Year)", "$($PublishDate.ToString('MM MMMM'))")
    if (!(Test-Path -LiteralPath $OutPath)) {
        New-Item -ItemType Directory -Path $OutPath -ErrorAction Stop | Out-Null
    }
    $OutFile=Join-Path $OutPath $Filename
    $FileObject=(Get-Item -LiteralPath $OutFile -ErrorAction Ignore)
    if ($FileObject.Exists -and ($FileObject.Length / 1024 / 1024) -ge $RedownloadSize) {
        Write-Verbose "Skipped '${Title}' because file already exists in '${OutPath}'"
    } else {
        if ($FileObject.Exists) {
            Write-Warning "Redownloading '${Title}' because file is less than ${RedownloadSize} MB"
        }
        $Uri=(Get-Mp3Uri $Url)
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -AllowInsecureRedirect -ErrorAction Inquire
        if ($?) {
            Set-ItemProperty -LiteralPath $OutFile -Name LastWriteTime -Value $PublishDate.ToUniversalTime() -ErrorAction Ignore
            return $true
        }
    }
    return $false
}

$Articles=@()

if ($MyInvocation.BoundParameters.ContainsKey('Page')) {
    $FirstPage=$Page
    $LastPage=$Page
}

$TotalPages=$LastPage-$FirstPage+1

if ([string]::IsNullOrEmpty($CsvPath)) {
    for($Page=$FirstPage; $Page -le $LastPage; ++$Page) {
        $CompletedPages=$Page - $FirstPage
        Write-Progress `
            -Activity 'Gathering links to podcast articles' `
            -Status "Page $($CompletedPages + 1) of ${TotalPages}" `
            -PercentComplete ($CompletedPages / $TotalPages * 100)
        Get-Articles -Page $Page | % { $Articles += $_ }
    }
} else {
    $Articles=@(Import-Csv -LiteralPath $CsvPath | where { $_.Page -ge $FirstPage -and $_.Page -le $LastPage })
}

if ([string]::IsNullOrEmpty($OutPath)) {
    if ($MediaLinks) {
        $Count=0
        $Articles | % {
            Write-Progress `
                -Activity 'Gathering download links' `
                -Status "$Count of $($Articles.Length)" `
                -PercentComplete ($Count / $Articles.Length * 100)
            [PSCustomObject]@{
                Page=$_.Page
                Title=$_.Title
                PublishDate=$_.PublishDate
                Url=$_.Url
                Downlaod=(Get-Mp3Uri -EpisodeUrl $_.Url)
            }
            ++$Count
        } | Export-Csv -LiteralPath './articles.out.csv'
    } else {
        $Articles | % { $_ } | Export-Csv -LiteralPath './articles.out.csv'
    }
} else {
    $ErrorActionPreference='Continue'
    
    $Failed=@()
    $Completed=0
    $Successful=@()

    $Articles | % {
        Write-Progress -Activity 'Total Podcast Download' `
            -Status "Downloading '$($_.Title | Out-Truncate -Width 30)' ($($Completed + 1) out of $($Articles.Length))" `
            -PercentComplete ($Completed / $Articles.Length * 100)
        $Episode=$_
        try {
            $WasDownloaded=(Get-Episode -Title $Episode.Title `
                                -Url $Episode.Url `
                                -PublishDate $Episode.PublishDate `
                                -OutPath $OutPath `
                                -RedownloadSize $RedownloadSize)
            if ($WasDownloaded) {
                $Successful+=$Episode
                Write-Verbose "Successfully downloaded $($Episode.Title)"
            }
        } catch {
            Write-Error "Failed to download '$($Episode.Title)' from $($Episode.Url)"
            Write-Error $_
            $Failed+=$Episode
        }
        ++$Completed
    }
    
    $Skipped=$Completed - $Successful.Length - $Failed.Length

    if ($Successful.Length -gt 0) {
        Write-Host '[  ' -ForegroundColor Yellow -NoNewline
        Write-Host 'OK' -ForegroundColor Green -NoNewline
        Write-Host '  ]' -ForegroundColor Yellow -NoNewline
        Write-Host " Downloaded $($Successful.Length) episode(s) successfully"
    }

    if ($Skipped -gt 0) {
        Write-Host '[ ' -ForegroundColor Yellow -NoNewline
        Write-Host 'WARN' -ForegroundColor Yellow -NoNewline
        Write-Host ' ]' -ForegroundColor Yellow -NoNewline
        if ($VerbosePreference -eq 'SilentlyContinue') {
            Write-Host " ${Skipped} episode(s) were skipped. Use -Verbose for more details."
        } else {
            Write-Host " ${Skipped} episode(s) were skipped"
        }
    }

    if ($Failed.Length -gt 0) {
        Write-Host '[' -ForegroundColor Yellow -NoNewline
        Write-Host 'FAILED' -ForegroundColor Red -NoNewline
        Write-Host '] ' -ForegroundColor Yellow -NoNewline
        Write-Host "Unable to download $($Failed.Length) episode(s):"
        $Failed 
    }
}
