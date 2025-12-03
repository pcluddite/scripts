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
