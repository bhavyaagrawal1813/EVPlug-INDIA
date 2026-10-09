$content = Get-Content "lib/screens/home_content.dart" -Raw
$pos = 0
while ($true) {
    $idx = $content.IndexOf("class ", $pos)
    if ($idx -eq -1) { break }
    $snippet = $content.Substring($idx, [Math]::Min(80, $content.Length - $idx))
    $snippet = $snippet -replace '\s+', ' '
    Write-Output "Position $idx : $snippet"
    $pos = $idx + 6
}
