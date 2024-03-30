using namespace System.Text;

param(
    [Parameter(Position=0)]
    [string]$Letters = 'DMEOIHARSPFW'
)

$ErrorActionPreference = 'Stop'

function Test-Word() {
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Word,
        [Parameter(Mandatory, Position=1)]
        [char[]]$Letters,
        [Parameter(Position=3)]
        [char]$FinalLetter = [char]0
    )

    $Word = $Word.ToUpper()

    # Check if the word is at least 3 letters long
    if ($Word.Length -lt 3) {
        return $false
    }

    # Check if the word starts with the last letter of the previous word
    if ($FinalLetter -ne [char]0 -and $Word[0] -ne $FinalLetter) {
        return $false
    }

    # Check if the word uses only the letters in the box
    foreach ($c in [char[]]$Word) {
        if ($Letters -notcontains $c) {
            return $false
        }
    }

    # Check if the word does not use consecutive letters from the same side
    for ($i = 0; $i -lt $Word.Length - 1; ++$i) {
        [double]$idx1 = $Letters.IndexOf($Word[$i])
        [double]$idx2 = $Letters.IndexOf($Word[$i + 1])
        if ([Math]::Floor($idx1 / 3) -eq [Math]::Floor($idx2 / 3)) {
            return $false
        }
    }

    return $true
}

function Find-Solution() {
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Letters
    )

    # Load a word list from a file
    $AllWords = Get-Content "words.txt"

    # Initialize an empty set of used words
    $UsedWords = [ordered]@{}

    # Initialize an empty set of used letters
    $UsedLetters = @{}

    # Initialize the last letter as null char
    $FinalLetter = [char]0

    # Loop until all letters are used
    while ($UsedLetters.Count -lt $letters.Length) {
        # Find a valid word that has not been used before

        $Word = $AllWords | where { $_ -and -not $UsedWords[$_] -and (Test-Word -Word $_ -Letters $Letters -FinalLetter $FinalLetter) }
            | % {
                [PSCustomObject]@{
                    Word=$_
                    Count=$(([char[]]$_ | select -Unique).Count)
                }
            }
            | Sort-Object -Property Count -Descending 
            | % { $_.Word } | select -First 1

        # If no word is found, return the list
        if (-not $Word) {
            return $UsedWords
        }
        Write-Verbose "Found ${Word}"

        # Add the word to the used AllWords set
        $UsedWords[$Word] = $true

        # Add the letters of the word to the used letters set
        foreach ($char in $Word) {
            $UsedLetters[$char] = $true
        }
        # Update the last letter
        $FinalLetter = $Word[-1]
    }

    # Return the used AllWords set as the solution
    return $UsedWords.Keys
}

function Write-Solution() {
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline,ValueFromRemainingArguments)]
        [string[]]$Solution
    )
    begin {
        $First=$true
        $sb=[StringBuilder]::new()
    }
    process {
        $Solution | % {
            if ($First) {
                $First=$false
            } else {
                $sb=$sb.Append(' -> ')
            }
            $sb=$sb.Append($_)
        }
    }
    end {
        $sb.ToString()
    }
}

Find-Solution -Letters $Letters -InformationAction Continue | Write-Solution
