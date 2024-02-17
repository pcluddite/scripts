
$Start=999999999
$Count=9999999999

for($i = $Start; $i -lt $Count; ++$i) {
    $Name="HUBB$($i.ToString().PadLeft(10, '0')).mp3"

    $Percent=($i - $Start) / ($Count - $Start) * 100

    Write-Progress `
        -Activity 'Scanning and downloading mp3s' `
        -Status "Scanning $($Percent.ToString('0.000'))%" `
        -PercentComplete $Percent

    $Uri="https://traffic.megaphone.fm/${Name}"
    try {
        Invoke-WebRequest -Uri $Uri -OutFile 'D:\Hubbard' -AllowInsecureRedirect
    } catch {
        $Status=$_.Exception.Response.StatusCode
        if ($Status -ne 404) {
            Write-Error $_
        }
    }
}
