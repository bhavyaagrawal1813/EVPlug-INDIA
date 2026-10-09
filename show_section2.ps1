$content = Get-Content "lib/screens/home_content.dart" -Raw
$start = 31200
$end = [Math]::Min(31900, $content.Length)
$snippet = $content.Substring($start, $end - $start)
Write-Output $snippet
