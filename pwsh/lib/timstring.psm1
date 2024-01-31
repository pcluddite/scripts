function Select-Truncate {
    [Cmdletbinding(DefaultParameterSetName='default')]
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline,ParameterSetName='default')]
        [Parameter(Mandatory,Position=0,ValueFromPipeline,ParameterSetName='mid')]
        [Parameter(Mandatory,Position=0,ValueFromPipeline,ParameterSetName='start')]
        [psobject]$InputObject,
        [Parameter(Position=1)]
        [ValidateRange('Positive')]
        [Alias('Count','n','Width')]
        [int]$Take = 30,
        [Parameter(Mandatory,ParameterSetName='mid')]
        [Alias('Mid')]
        [switch]$Middle,
        [Parameter(Mandatory,ParameterSetName='start')]
        [switch]$Start,
        [Parameter(Position=2)]
        [AllowEmptyString()]
        [string]$Elipses = '...',
        [switch]$Trim
    )
    process {
        $String=($InputObject | Out-String -NoNewline)
        Write-Verbose "'${String}'"
        if ($String.Length -gt $Take) {
            $Count=$Take-$Elipses.Length
            if ($Count -le 0) {
                $Count=$Take
                $Elipses=''
            }
            if ($Middle) {
                $Substring1=$String.Remove([Math]::Ceiling($Count / 2))
                $Substring2=$String.Substring($String.Length - [Math]::Floor($Count / 2))
                if ($Trim) {
                    $Substring1=$Substring1.TrimEnd()
                    $Substring2=$Substring2.TrimStart()
                }
                return "${Substring1}${Elipses}${Substring2}"
            } elseif($FromEnd) {
                $Substring=$String.Substring($String.Length - $Count)
                if ($Trim) {
                    $Substring=$Substring.Trim()
                }
                return "${Elipses}${Substring}"
            } else {
                $Substring=$String.Remove($Count)
                if ($Trim) {
                    $Substring=$Substring.TrimEnd()
                }
                return "${Substring}${Elipses}"
            }
        }
        return $String
    }
}

function Select-Alpha {
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [psobject]$InputObject
    )
    begin {
        $sb=[Text.StringBuilder]::new()
    }
    process {
        $String = ($InputObject | Out-String -NoNewline)
        foreach($c in [char[]]$String) {
            if ([char]::IsLetter($c) -or [char]::IsWhiteSpace($c)) {
                $sb=$sb.Append($c)
            }
        }
        $sb.ToString()
        $sb=$sb.Clear()
    }
}


function Select-AlphaNumeric {
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [psobject]$InputObject
    )
    begin {
        $sb=[Text.StringBuilder]::new()
    }
    process {
        $String = ($InputObject | Out-String -NoNewline)
        foreach($c in [char[]]$String) {
            if ([char]::IsLetterOrDigit($c) -or [char]::IsWhiteSpace($c)) {
                $sb=$sb.Append($c)
            }
        }
        $sb.ToString()
        $sb=$sb.Clear()
    }
}

function ConvertTo-Regex {
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Pattern,
        [Parameter(Position=1)]
        [string]$WordBoundry="\W"
    )
    # splits the pattern on wildchards ('*', '?', '[a-b]', etc)
    -join ([Regex]::Split($Pattern, '(?<!`)([\*\?])|(\[.*?\])') | % {
        # convert wildchards to regex equivalent
        if ($_ -eq '*') {
            ".*?${WordBoundry}?"
        } elseif ($_ -eq '?') {
            '.{1}'
        } elseif ($_ -like '[*]') {
            # don't bother validating char groups; if it's wrong, it'll error
            $_
        } else {
            # escape any other text
            [Regex]::Escape($_)
        }
    })
}
