param(
    [Parameter(Mandatory,Position=0)]
    [string]$Letters,
    [switch]$Anagrams
)

function Get-LetterCount {
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$Letters
    )
    $LetterCount=@{}
    foreach($c in [char[]]$Letters) {
        if ($LetterCount[$c]) {
            ++$LetterCount[$c]
        } else {
            $LetterCount[$c]=1
        }
    }
    return $LetterCount
}

Get-LetterCount -Letters $Letters