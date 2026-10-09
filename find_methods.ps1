$content = Get-Content "lib/screens/home_content.dart" -Raw

# Find @override
$pos = 0
Write-Output "=== @override positions ==="
while ($true) {
    $idx = $content.IndexOf("@override", $pos)
    if ($idx -eq -1) { break }
    $snippet = $content.Substring($idx, [Math]::Min(100, $content.Length - $idx))
    $snippet = $snippet -replace '\s+', ' '
    Write-Output "$idx : $snippet"
    $pos = $idx + 9
}

# Find method signatures (Widget build, void, etc.)
Write-Output "`n=== Method-like patterns ==="
$pos = 0
$searchTerms = @("Widget build(", "void ", "Future<", "StreamSubscription", "Stream<")
foreach ($term in $searchTerms) {
    $pos = 0
    while ($true) {
        $idx = $content.IndexOf($term, $pos)
        if ($idx -eq -1) { break }
        Write-Output "$term at $idx"
        $pos = $idx + 1
    }
}

# Find class boundaries
Write-Output "`n=== Closing braces of classes ==="
# Count braces to find class endings
Write-Output "File length: $($content.Length)"
