$content = Get-Content "lib/screens/home_content.dart" -Raw
# Show content from position 541 to 900 (HomeContentScreen class and start of _HomeContentScreenState)
$start = 541
$end = [Math]::Min(900, $content.Length)
Write-Output $content.Substring($start, $end - $start)
