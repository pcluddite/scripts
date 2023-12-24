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
