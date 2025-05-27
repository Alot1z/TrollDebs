$files = Get-ChildItem -Path ".\TrollDebs\Localization" -Recurse -Filter "*.strings"

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $updatedContent = $content -replace 'AppIndex', 'TrollDebs'
    
    if ($updatedContent -ne $content) {
        Set-Content -Path $file.FullName -Value $updatedContent -NoNewline
        Write-Host "Updated: $($file.FullName)"
    }
}
