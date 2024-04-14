
$GIT_PATH=Join-Path -Path $PSScriptRoot -ChildPath '..'

. (Join-Path $GIT_PATH 'modules.ps1') -Name @('string')

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
        git config --global -- $Name $Value
        if ($?) {
            Write-InfoGood "${Name} = '${Value}'"
        } else {
            Write-InfoBad "${Name} = '${Value}'"
        }
    }
}
