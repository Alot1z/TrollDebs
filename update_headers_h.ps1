$files = Get-ChildItem -Path . -Recurse -Include *.h,*.m

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw
    $updatedContent = $content -replace '//\s+AppIndex', '//  TrollDebs'
    
    if ($updatedContent -ne $content) {
        Set-Content -Path $file.FullName -Value $updatedContent -NoNewline
        Write-Host "Updated: $($file.FullName)"
    }
}
