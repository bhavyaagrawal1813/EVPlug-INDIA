$content = Get-Content "lib/screens/home_content.dart" -Raw
$len = $content.Length
$depth = 0
$inString = $false
$inSingleQuote = $false
$inDoubleQuote = $false
$inTripleSingle = $false
$inTripleDouble = $false
$inLineComment = $false
$inBlockComment = $false
$rawString = $false

for ($i = 0; $i -lt $len; $i++) {
    $c = $content[$i]
    $next = if ($i + 1 -lt $len) { $content[$i+1] } else { "" }
    $next2 = if ($i + 2 -lt $len) { $content[$i+2] } else { "" }
    
    if ($inLineComment) {
        if ($c -eq "`n") { $inLineComment = $false }
        continue
    }
    
    if ($inBlockComment) {
        if ($c -eq "*" -and $next -eq "/") { $inBlockComment = $false; $i++ }
        continue
    }
    
    if ($inTripleSingle) {
        if ($c -eq "'" -and $next -eq "'" -and $next2 -eq "'") { $inTripleSingle = $false; $i += 2 }
        continue
    }
    
    if ($inTripleDouble) {
        if ($c -eq '"' -and $next -eq '"' -and $next2 -eq '"') { $inTripleDouble = $false; $i += 2 }
        continue
    }
    
    if ($inSingleQuote) {
        if ($c -eq "`"") { $inSingleQuote = $false }
        continue
    }
    
    if (-not $inString -and -not $inSingleQuote -and -not $inDoubleQuote) {
        # Not in any string
        if ($c -eq "/" -and $next -eq "/") { $inLineComment = $true; $i++; continue }
        if ($c -eq "/" -and $next -eq "*") { $inBlockComment = $true; $i++; continue }
        
        if ($c -eq "'" -and $next -eq "'" -and $next2 -eq "'") { $inTripleSingle = $true; $i += 2; continue }
        if ($c -eq '"' -and $next -eq '"' -and $next2 -eq '"') { $inTripleDouble = $true; $i += 2; continue }
        if ($c -eq "'") { $inSingleQuote = $true; continue }
        if ($c -eq '"') { $inDoubleQuote = $true; continue }
        
        if ($c -eq "{") { $depth++ }
        elseif ($c -eq "}") {
            $depth--
            if ($depth -lt 0) { Write-Host "EXTRA closing brace at position $i (line 1, col $($i+1))" }
        }
    }
}

Write-Host "Final depth: $depth"
Write-Host "File length: $len"
