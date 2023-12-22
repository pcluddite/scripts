param(
    [Parameter(Mandatory, Position=0)]
    [string]$Letters
)

function Test-Word() {
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Word,
        [Parameter(Mandatory, Position=1)]
        [char[]]$Letters,
        [Parameter(Position=3)]
        [char]$LastLetter = [char]0
    )
    
    $Word = $Word.ToUpper()

    # Check if the word is at least 3 letters long
    if ($Word.Length -lt 3) {
        return $false
    }

    # Check if the word starts with the last letter of the previous word
    if ($LastLetter -ne [char]0 -and $Word[0] -ne $LastLetter) {
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
    $words = Get-Content "words.txt"
    # Initialize an empty list of used words
    $usedWords = @()
    # Initialize an empty set of used letters
    $usedLetters = @{}
    # Initialize the last letter as empty
    $LastLetter = [char]0
    # Loop until all letters are used
    while ($usedLetters.Count -lt $letters.Length) {
        # Find a valid word that has not been used before
        $word = $words | Where { -not [string]::IsNullOrEmpty($_) } | Where-Object {(Test-Word -Word $_ -Letters $Letters -LastLetter $LastLetter) -and $usedWords -notcontains $_} | Select-Object -First 1
        # If no word is found, return null
        if ($word -eq $null) {
            return $usedWords
        }
        # Add the word to the used words list
        $usedWords += $word
        # Add the letters of the word to the used letters set
        foreach ($char in $word) {
            $usedLetters[$char] = $true
        }
        # Update the last letter
        $LastLetter = $word[-1]
    }
    # Return the used words list as the solution
    return $usedWords
}

function Out-Solution() {
    param(
        [Parameter(Mandatory,Position=0,ValueFromPipeline,ValueFromRemainingArguments)]
        [string[]]$Solution
    )
    begin {
        $First=$true
    }
    process {
        $Solution | % {
            if ($First) {
                Write-Host $_ -NoNewline
                $First = $false
            } else {
                Write-Host " -> ${_}" -NoNewline
            }
        }
    }
    end {
        Write-Host ''
    }
}

Find-Solution -Letters $Letters | Out-Solution
