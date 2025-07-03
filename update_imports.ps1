# PowerShell script to update imports from "woosh" to "glamour_queen"
# Run this script from the project root directory

Write-Host "Starting import update from 'woosh' to 'glamour_queen'..." -ForegroundColor Green

# Function to update imports in a single file
function Update-ImportsInFile {
    param(
        [string]$FilePath
    )
    
    try {
        $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $originalContent = $content
        
        # Update package imports
        $content = $content -replace "import 'package:woosh/", "import 'package:glamour_queen/"
        
        # Update relative imports that might reference woosh
        $content = $content -replace "import '\.\./\.\./woosh/", "import '../../glamour_queen/"
        $content = $content -replace "import '\.\./woosh/", "import '../glamour_queen/"
        $content = $content -replace "import 'woosh/", "import 'glamour_queen/"
        
        # Only write if content changed
        if ($content -ne $originalContent) {
            Set-Content -Path $FilePath -Value $content -Encoding UTF8
            Write-Host "Updated: $FilePath" -ForegroundColor Yellow
            return $true
        }
        return $false
    }
    catch {
        Write-Host "Error processing $FilePath : $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to update pubspec.yaml
function Update-PubspecYaml {
    $pubspecPath = "pubspec.yaml"
    if (Test-Path $pubspecPath) {
        try {
            $content = Get-Content -Path $pubspecPath -Raw -Encoding UTF8
            $originalContent = $content
            
            # Update package name
            $content = $content -replace "name: woosh", "name: glamour_queen"
            $content = $content -replace "description: `"A new Flutter project.`"", "description: `"Glamour Queen - A Flutter project.`""
            
            if ($content -ne $originalContent) {
                Set-Content -Path $pubspecPath -Value $content -Encoding UTF8
                Write-Host "Updated: $pubspecPath" -ForegroundColor Yellow
                return $true
            }
        }
        catch {
            Write-Host "Error updating pubspec.yaml : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    return $false
}

# Function to update test files
function Update-TestFiles {
    $testPath = "test/widget_test.dart"
    if (Test-Path $testPath) {
        try {
            $content = Get-Content -Path $testPath -Raw -Encoding UTF8
            $originalContent = $content
            
            $content = $content -replace "import 'package:woosh/main.dart';", "import 'package:glamour_queen/main.dart';"
            
            if ($content -ne $originalContent) {
                Set-Content -Path $testPath -Value $content -Encoding UTF8
                Write-Host "Updated: $testPath" -ForegroundColor Yellow
                return $true
            }
        }
        catch {
            Write-Host "Error updating test file : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    return $false
}

# Function to update Android files
function Update-AndroidFiles {
    $androidFiles = @(
        "android/app/src/main/kotlin/com/example/whoosh/MainActivity.kt",
        "android/app/src/main/java/com/example/whoosh/MainActivity.java"
    )
    
    foreach ($file in $androidFiles) {
        if (Test-Path $file) {
            try {
                $content = Get-Content -Path $file -Raw -Encoding UTF8
                $originalContent = $content
                
                # Update package names in Android files
                $content = $content -replace "package com\.example\.whoosh", "package com.example.glamour_queen"
                $content = $content -replace "import com\.example\.whoosh", "import com.example.glamour_queen"
                
                if ($content -ne $originalContent) {
                    Set-Content -Path $file -Value $content -Encoding UTF8
                    Write-Host "Updated: $file" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "Error updating Android file $file : $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

# Main execution
$updatedFiles = 0
$totalFiles = 0

# Update pubspec.yaml
if (Update-PubspecYaml) {
    $updatedFiles++
}
$totalFiles++

# Update test files
if (Update-TestFiles) {
    $updatedFiles++
}
$totalFiles++

# Update Android files
Update-AndroidFiles

# Find and update all Dart files
$dartFiles = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse
$dartFiles += Get-ChildItem -Path "test" -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    $totalFiles++
    if (Update-ImportsInFile -FilePath $file.FullName) {
        $updatedFiles++
    }
}

Write-Host "`nUpdate completed!" -ForegroundColor Green
Write-Host "Files processed: $totalFiles" -ForegroundColor Cyan
Write-Host "Files updated: $updatedFiles" -ForegroundColor Cyan

if ($updatedFiles -gt 0) {
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Run 'flutter clean'" -ForegroundColor White
    Write-Host "2. Run 'flutter pub get'" -ForegroundColor White
    Write-Host "3. Update any remaining references manually if needed" -ForegroundColor White
    Write-Host "4. Test your application thoroughly" -ForegroundColor White
} else {
    Write-Host "`nNo files were updated. All imports may already be correct." -ForegroundColor Green
} 