<#
 :
 : Copyright 2025 Timothy Baxendale (pcluddite@outlook.com)
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
using namespace System.Diagnostics.CodeAnalysis;

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

function Select-Truncate {
    [Cmdletbinding(DefaultParameterSetName='default')]
    [OutputType([string])]
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
            } elseif($Start) {
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
    [OutputType([string])]
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
    [OutputType([string])]
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
    [SuppressMessageAttribute('PSReviewUnusedParameter','WordBoundry',Justification='false positive')]
    [OutputType([string])]
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

function Write-InfoGood {
    [OutputType([void])]
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [object]$MessageData,
        [Parameter(Position=1,ValueFromRemainingArguments)]
        [string[]]$Tags
    )
    begin {
        if ($null -eq $MyInvocation.BoundParameters['InformationAction']) {
            $InformationPreference='Continue'
        }
    }
    process {
        Write-Information "[   $($PSStyle.Bold)$($PSStyle.Foreground.Green)OK$($PSStyle.Reset)   ] $($MessageData | Out-String -NoNewline)" -Tags:$Tags
    }
}

function Write-InfoBad {
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [object]$MessageData,
        [Parameter(Position=1,ValueFromRemainingArguments)]
        [string[]]$Tags
    )
    begin {
        if ($null -eq $MyInvocation.BoundParameters['InformationAction']) {
            $InformationPreference='Continue'
        }
    }
    process {
        Write-Information "[ $($PSStyle.Bold)$($PSStyle.Foreground.Red)FAILED$($PSStyle.Reset) ] $($MessageData | Out-String -NoNewline)" -Tags:$Tags
    }
}

function Write-InfoWarn {
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [object]$MessageData,
        [Parameter(Position=1,ValueFromRemainingArguments)]
        [string[]]$Tags
    )
    begin {
        if ($null -eq $MyInvocation.BoundParameters['InformationAction']) {
            $InformationPreference='Continue'
        }
    }
    process {
        Write-Information "[  $($PSStyle.Bold)$($PSStyle.Foreground.Yellow)WARN$($PSStyle.Reset)  ] $($MessageData | Out-String -NoNewline)" -Tags:$Tags
    }
}

function Format-Comma {
    [OutputType([string])]
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline)]
        [double]$Number
    )
    process {
        $Number.ToString("#,##0")
    }
}
