#!/bin/bash

# Bash script to update imports from "woosh" to "glamour_queen"
# Run this script from the project root directory

echo "Starting import update from 'woosh' to 'glamour_queen'..."

# Function to update imports in a single file
update_imports_in_file() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    # Create backup
    cp "$file_path" "$file_path.backup"
    
    # Update package imports
    sed -i 's|import '\''package:woosh/|import '\''package:glamour_queen/|g' "$file_path"
    
    # Update relative imports
    sed -i 's|import '\''\.\./\.\./woosh/|import '\''../../glamour_queen/|g' "$file_path"
    sed -i 's|import '\''\.\./woosh/|import '\''../glamour_queen/|g' "$file_path"
    sed -i 's|import '\''woosh/|import '\''glamour_queen/|g' "$file_path"
    
    # Check if file was modified
    if ! cmp -s "$file_path" "$file_path.backup"; then
        echo "Updated: $file_path"
        rm "$file_path.backup"
        return 0
    else
        rm "$file_path.backup"
        return 1
    fi
}

# Function to update pubspec.yaml
update_pubspec_yaml() {
    local pubspec_path="pubspec.yaml"
    
    if [[ ! -f "$pubspec_path" ]]; then
        return 1
    fi
    
    # Create backup
    cp "$pubspec_path" "$pubspec_path.backup"
    
    # Update package name and description
    sed -i 's/name: woosh/name: glamour_queen/' "$pubspec_path"
    sed -i 's/description: "A new Flutter project."/description: "Glamour Queen - A Flutter project."/' "$pubspec_path"
    
    # Check if file was modified
    if ! cmp -s "$pubspec_path" "$pubspec_path.backup"; then
        echo "Updated: $pubspec_path"
        rm "$pubspec_path.backup"
        return 0
    else
        rm "$pubspec_path.backup"
        return 1
    fi
}

# Function to update test files
update_test_files() {
    local test_path="test/widget_test.dart"
    
    if [[ ! -f "$test_path" ]]; then
        return 1
    fi
    
    # Create backup
    cp "$test_path" "$test_path.backup"
    
    # Update import
    sed -i "s|import 'package:woosh/main.dart';|import 'package:glamour_queen/main.dart';|g" "$test_path"
    
    # Check if file was modified
    if ! cmp -s "$test_path" "$test_path.backup"; then
        echo "Updated: $test_path"
        rm "$test_path.backup"
        return 0
    else
        rm "$test_path.backup"
        return 1
    fi
}

# Function to update Android files
update_android_files() {
    local android_files=(
        "android/app/src/main/kotlin/com/example/whoosh/MainActivity.kt"
        "android/app/src/main/java/com/example/whoosh/MainActivity.java"
    )
    
    for file in "${android_files[@]}"; do
        if [[ -f "$file" ]]; then
            # Create backup
            cp "$file" "$file.backup"
            
            # Update package names
            sed -i 's/package com\.example\.whoosh/package com.example.glamour_queen/g' "$file"
            sed -i 's/import com\.example\.whoosh/import com.example.glamour_queen/g' "$file"
            
            # Check if file was modified
            if ! cmp -s "$file" "$file.backup"; then
                echo "Updated: $file"
                rm "$file.backup"
            else
                rm "$file.backup"
            fi
        fi
    done
}

# Main execution
updated_files=0
total_files=0

# Update pubspec.yaml
if update_pubspec_yaml; then
    ((updated_files++))
fi
((total_files++))

# Update test files
if update_test_files; then
    ((updated_files++))
fi
((total_files++))

# Update Android files
update_android_files

# Find and update all Dart files
echo "Scanning Dart files..."
while IFS= read -r -d '' file; do
    ((total_files++))
    if update_imports_in_file "$file"; then
        ((updated_files++))
    fi
done < <(find lib test -name "*.dart" -type f -print0 2>/dev/null)

echo ""
echo "Update completed!"
echo "Files processed: $total_files"
echo "Files updated: $updated_files"

if [[ $updated_files -gt 0 ]]; then
    echo ""
    echo "Next steps:"
    echo "1. Run 'flutter clean'"
    echo "2. Run 'flutter pub get'"
    echo "3. Update any remaining references manually if needed"
    echo "4. Test your application thoroughly"
else
    echo ""
    echo "No files were updated. All imports may already be correct."
fi 