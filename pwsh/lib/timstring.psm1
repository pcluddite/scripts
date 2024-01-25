function Out-Truncate {
    param(
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [psobject]$InputObject,
        [Parameter(Mandatory,Position=1)]
        [int]$Width
    )
    process {
        $str = ($InputObject | Out-String -NoNewline)
        if ($str.Length -gt $Width) {
            return "$($str.Substring(0, $Width - 3))..."
        }
        return $str
    }
}

function Out-Alpha {
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [psobject]$InputObject
    )
    begin {
        $sb=[Text.StringBuilder]::new()
    }
    process {
        $str = ($InputObject | Out-String -NoNewline)
        foreach($c in [char[]]$str) {
            if ([char]::IsLetter($c) -or [char]::IsWhiteSpace($c)) {
                $sb=$sb.Append($c)
            }
        }
        $sb.ToString()
        $sb=$sb.Clear()
    }
}


function Out-Alphanumeric {
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)]
        [psobject]$InputObject
    )
    begin {
        $sb=[Text.StringBuilder]::new()
    }
    process {
        $str = ($InputObject | Out-String -NoNewline)
        foreach($c in [char[]]$str) {
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
