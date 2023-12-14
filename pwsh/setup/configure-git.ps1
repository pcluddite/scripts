
$ErrorActionPreference = 'Stop'

$Configs = @{
    core = @{
        editor='vim'
    };
    user = @{
        name='Tim Baxendale';
        email='pcluddite@outlook.com';
    };
    pull = @{
        rebase='true';
    };
    rebase = @{
        autoStash='true';
    };
}

$Configs.Keys | % {
    $SectionName=$_
    $Section=$Configs[$SectionName]

    $Section.Keys | % {
        $Name="${SectionName}.$_"
        $Value=$Section[$_]
        Write-Host "[${Name}] = '${Value}': " -NoNewLine
        git config --global -- $Name $Value
        if ($?) {
            Write-Host 'OK' -ForegroundColor Green
        } else {
            Write-Host 'FAIL' -ForegroundColor Red
        }
    }
}
