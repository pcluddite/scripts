param(
    [Parameter(Mandatory,Position=0)]
    [string]$Path
)

Add-Type -AssemblyName Microsoft.VisualBasic

function Move-Recycle() {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$Path
    )
    process {
        $Path | % {
            Write-Verbose "Recycling '${RecyclePath}'..."
            try {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_, 'OnlyErrorDialogs', 'SendToRecycleBin')
            } catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
}

$INVALID_CHARS = [IO.Path]::GetInvalidFileNameChars()
$REPLACE_CHARS = @{
    [char]"’" =[char]"'"
    [char]"‘" =[char]"'"
    [char]"`“"=[char]"`'"
    [char]"`”"=[char]"`'"
    [char]"—" =[char]'-'
}
function Remove-Special {
    param (    
        [Parameter(Mandatory,Position=0)]
        [string]$Name
    )
    $NoExt=[IO.Path]::GetFileNameWithoutExtension($Name)

    $sb=[Text.StringBuilder]::new($NoExt.Length)
    foreach($c in [char[]]$NoExt) {
        if ($INVALID_CHARS -contains $c) {
            $sb=$sb.Append('%')
        } else{
            $Replacement=$REPLACE_CHARS[$c]
            if($Replacement -eq $null) {
                $sb=$sb.Append($c)
            } else {
                $sb=$sb.Append($Replacement)
            }
        }
    }

    return "$($sb.ToString().Trim())$([IO.Path]::GetExtension($Name))"
}

$Episodes=@{}

Get-ChildItem -Path $Path -Recurse -File | % {
    $List=$Episodes[$_.LastWriteTime.Date]
    if ($List -eq $null) {
        $List=@($_)
    } else {
        $List+=$_
    }
    $Episodes[$_.LastWriteTime.Date]=$List
}

$SameName=@{}

$Episodes.Keys | where { $Episodes[$_].Length -gt 1} | % {
    $Episodes[$_] | % {
        $StrippedName=Remove-Special $_.Name
        $List=$SameName[$StrippedName]
        if ($List -eq $null) {
            $List=@($_)
        } else {
            $List+=$_
        }
        $SameName[$StrippedName]=$List
    }
}

$SameName.Keys | where { $SameName[$_].Length -gt 1} | % { 
    $List=($SameName[$_] | Sort-Object -Descending -Property Length)
    for($i=1; $i -lt $List.Length; ++$i) {
        Move-Recycle $List[$i]
    }
    if ($List[0].Name -ne $_) {
        $NewPath=Join-Path ([IO.Path]::GetDirectoryName($List[0].FullName)) $_
        Move-Item $List[0] -Destination $NewPath
    }
}