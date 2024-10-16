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
$InformationPreference = 'Continue'

. "${PSScriptRoot}/modules.ps1" -Name @('string', 'files')

# Install the module on demand (https://stackoverflow.com/a/60658511/4367864)
if (-not (Get-Module -ErrorAction Ignore -ListAvailable PSParseHTML)) {
    Write-Verbose "Installing PSParseHTML module for the current user..."
    Install-Module -Scope CurrentUser PSParseHTML -ErrorAction Stop
}

function Get-FileName {
    param (
        [Parameter(Mandatory,Position=0)]
        [string]$Title,
        [Parameter(Position=1)]
        [string]$Uri
    )

    if ($Uri) {
        $nStart = $Uri.LastIndexOf('/')
        $nEnd = $Uri.LastIndexOf('?')
        if ($nEnd -le $nStart) {
            $nEnd = $Uri.Length
        }
        $ext=[Path]::GetExtension($Uri.Substring($nStart + 1, $nEnd - $nStart - 1))
    } else {
        $ext='.mp3'
    }
    return (Rename-SpecialChar -Name "${Title}${ext}")
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

function Get-Article {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0,ParameterSetName='default')]
        [ValidateRange('Positive')]
        [int]$Page,
        [Parameter(Mandatory,Position=0,ParameterSetName='range')]
        [ValidateRange('Positive')]
        [int]$FirstPage,
        [Parameter(Mandatory,Position=1,ParameterSetName='range')]
        [ValidateScript({ $_ -ge $FirstPage })]
        [int]$LastPage
    )

    if ($PSCmdlet.ParameterSetName -eq 'default') {
        $FirstPage=$Page
        $LastPage=$Page
    }

    $TotalPages=$LastPage-$FirstPage+1

    for($Page=$FirstPage; $Page -le $LastPage; ++$Page) {
        $CompletedPages=$Page - $FirstPage
        Write-Progress `
            -Activity 'Gathering links to podcast articles' `
            -Status "Page $($CompletedPages + 1) of ${TotalPages}" `
            -PercentComplete ($CompletedPages / $TotalPages * 100)

        $PageUrl="https://www.1057thepoint.com/podcasts/the-rizzuto-show/?episode_page=${Page}"

        try {
            $Response=Invoke-WebRequest -Uri $PageUrl
        } catch {
            $Status=$_.Exception.Response.StatusCode
            try {
                throw "$([int]$Status) ${Status}: ${PageUrl}"
            } catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }

        $HtmlNode=($Response.Content | ConvertFrom-HTML)

        # select article nodes for latest episodes
        $Articles=$HtmlNode.SelectNodes("//div[@class='latest-episodes']/a")

        $Articles | % {
            # select link node to each article from post-title class
            $LinkNode=$_
            $InnerNode=$_.InnerHtml | ConvertFrom-HTML
            $TitleNode=$InnerNode.SelectSingleNode("//*[@class='post-title']")
            return [PSCustomObject]@{
                Page=$Page

                # decode innerText to remove &###;
                Title=[Net.WebUtility]::HtmlDecode($TitleNode.InnerText).Trim()

                # get url from href attribute
                Url=$LinkNode.Attributes['href'].Value

                # select published date from time node
                PublishDate=[DateTime]$InnerNode.SelectSingleNode("//time").InnerText
            }
        }
    }
}

function Get-Episode {
    [OutputType([bool])]
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
    $Filename=Get-FileName -Title $Title
    $OutPath=Join-Path $OutPath "$($PublishDate.Year)/$($PublishDate.ToString('MM MMMM'))"
    if (!(Test-Path -LiteralPath $OutPath)) {
        New-Item -ItemType Directory -Path $OutPath -ErrorAction Stop | Out-Null
    }
    $OutFile=Join-Path $OutPath $Filename
    $FileObject=(Get-Item -LiteralPath $OutFile -ErrorAction Ignore)
    if ($FileObject.Exists -and ($FileObject.Length / 1024 / 1024) -ge $RedownloadSize) {
        Write-Warning "Skipped '${Title}' because file already exists in '${OutPath}'"
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

function Export-ArticleCsv {
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [pscustomobject[]]$Articles,
        [Parameter(Mandatory,Position=1)]
        [string]$OutPath,
        [switch]$MediaLinks
    )
    begin {
        $AllArticles=@()
    }
    process {
        $Articles | % { $AllArticles+=$_ }
    }
    end {
        if ($MediaLinks) {
            $Count=0
            $AllArticles | % {
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
            } | Export-Csv -LiteralPath $OutPath
        } else {
            $AllArticles | % { $_ } | Export-Csv -LiteralPath $OutPath
        }
    }
}

if ($PSBoundParameters['Page']) {
    $FirstPage=$Page
    $LastPage=$Page
}

if ($CsvPath) {
    $Articles=@(Import-Csv -LiteralPath $CsvPath | where { $_.Page -ge $FirstPage -and $_.Page -le $LastPage })
} else {
    $Articles=@(Get-Article -FirstPage $FirstPage -LastPage $LastPage)
}

if (-not $OutPath) {
    $Articles | Export-ArticleCsv -OutPath './articles.out.csv' -MediaLinks:$MediaLinks
} else {
    $ErrorActionPreference='Continue'

    $Failed=@()
    $Completed=0
    $Successful=@()

    $Articles | % {
        Write-Progress -Activity 'Total Podcast Download' `
            -Status "Downloading '$($_.Title | Select-Truncate -Take 30)' ($($Completed + 1) out of $($Articles.Length))" `
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
                Write-Information "Successfully downloaded $($Episode.Title)" -Tags 'Success'
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
        Write-InfoGood " Downloaded $($Successful.Length) episode(s) successfully"
    }

    if ($Skipped -gt 0) {
        if ($InformationPreference) {
            Write-InfoWarn " ${Skipped} episode(s) were skipped"
        } else {
            Write-InfoWarn " ${Skipped} episode(s) were skipped. Use -InformationAction 'Continue' for more details."
        }
    }

    if ($Failed.Length -gt 0) {
        Write-InfoBad "Unable to download $($Failed.Length) episode(s):"
        $Failed
    }
}
