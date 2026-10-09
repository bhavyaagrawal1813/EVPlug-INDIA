$content = Get-Content "lib/screens/home_content.dart" -Raw
$start = 31700
$end = [Math]::Min(31850, $content.Length)
$snippet = $content.Substring($start, $end - $start)
Write-Output $snippet
