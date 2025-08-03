#!/usr/bin/env python3
"""
Debug Log Cleanup Script for Woosh Journey Plan Files
Removes debug print statements and console.log calls to improve performance
"""

import os
import re
import shutil
from pathlib import Path
from datetime import datetime

class DebugLogCleaner:
    def __init__(self, base_path="lib/pages/journeyplan"):
        self.base_path = Path(base_path)
        self.backup_dir = Path("backup_debug_logs")
        self.cleaned_files = []
        self.skipped_files = []
        self.error_files = []
        
        # Patterns to match debug logs
        self.debug_patterns = [
            # Basic print statements
            r'^\s*print\s*\(\s*[\'"][^\'"]*debug[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Debug[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*DEBUG[^\'"]*[\'"]\s*\)\s*;?\s*$',
            
            # Print statements with ?? or ? prefixes (common debug pattern)
            r'^\s*print\s*\(\s*[\'"][^\'"]*\?\?[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*\?[^\'"]*[\'"]\s*\)\s*;?\s*$',
            
            # Console.log statements
            r'^\s*console\.log\s*\([^)]*\)\s*;?\s*$',
            
            # Debug print statements with variables
            r'^\s*print\s*\(\s*[\'"][^\'"]*debug[^\'"]*[\'"]\s*\+\s*[^)]*\)\s*;?\s*$',
            
            # Specific debug patterns found in the codebase
            r'^\s*print\s*\(\s*[\'"][^\'"]*REPORT SUBMISSION DEBUG[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*CHECKOUT[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Error[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Failed[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Loaded[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Saved[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Cached[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Cleared[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Syncing[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Routes preloaded[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Fetching[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Found[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Debug Auth Status[^\'"]*[\'"]\s*\)\s*;?\s*$',
        ]
        
        # Patterns to keep (important error handling)
        self.keep_patterns = [
            r'^\s*print\s*\(\s*[\'"][^\'"]*Exception[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Critical[^\'"]*[\'"]\s*\)\s*;?\s*$',
            r'^\s*print\s*\(\s*[\'"][^\'"]*Fatal[^\'"]*[\'"]\s*\)\s*;?\s*$',
        ]
        
        # Files to process
        self.target_files = [
            "createJourneyplan.dart",
            "journeyplans_page.dart", 
            "journeyview.dart",
            "reports/reportMain_page.dart",
            "reports/pages/product_report_page.dart",
            "reports/pages/visibility_report_page.dart",
            "reports/pages/feedback_report_page.dart",
            "reports/pages/product_sample_page.dart"
        ]
        
        # Related service files
        self.service_files = [
            "../services/enhanced_journey_plan_service.dart",
            "../services/jouneyplan_service.dart",
            "../services/offline_sync_service.dart",
            "../services/hive/product_hive_service.dart",
            "../services/hive/client_hive_service.dart",
            "../services/hive/order_hive_service.dart",
            "../services/hive/route_hive_service.dart",
        ]

    def create_backup(self):
        """Create backup of original files"""
        if self.backup_dir.exists():
            shutil.rmtree(self.backup_dir)
        
        self.backup_dir.mkdir(parents=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        print(f"📁 Creating backup in: {self.backup_dir}")
        
        # Backup target files
        for file_path in self.target_files:
            full_path = self.base_path / file_path
            if full_path.exists():
                backup_path = self.backup_dir / f"{timestamp}_{file_path}"
                shutil.copy2(full_path, backup_path)
                print(f"   ✅ Backed up: {file_path}")
        
        # Backup service files
        for file_path in self.service_files:
            full_path = self.base_path / file_path
            if full_path.exists():
                backup_path = self.backup_dir / f"{timestamp}_{file_path.replace('../', '')}"
                backup_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(full_path, backup_path)
                print(f"   ✅ Backed up: {file_path}")

    def should_keep_line(self, line):
        """Check if line should be kept (important error handling)"""
        for pattern in self.keep_patterns:
            if re.match(pattern, line, re.IGNORECASE):
                return True
        return False

    def is_debug_line(self, line):
        """Check if line is a debug statement"""
        for pattern in self.debug_patterns:
            if re.match(pattern, line, re.IGNORECASE):
                return True
        return False

    def clean_file(self, file_path):
        """Clean debug logs from a single file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
            
            original_lines = len(lines)
            cleaned_lines = []
            removed_count = 0
            
            for line in lines:
                # Keep important error handling lines
                if self.should_keep_line(line):
                    cleaned_lines.append(line)
                    continue
                
                # Remove debug lines
                if self.is_debug_line(line):
                    removed_count += 1
                    continue
                
                # Keep all other lines
                cleaned_lines.append(line)
            
            # Write cleaned content back
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(cleaned_lines)
            
            return {
                'file': str(file_path),
                'original_lines': original_lines,
                'cleaned_lines': len(cleaned_lines),
                'removed_count': removed_count
            }
            
        except Exception as e:
            return {
                'file': str(file_path),
                'error': str(e)
            }

    def clean_all_files(self):
        """Clean all target files"""
        print("\n🧹 Starting debug log cleanup...")
        
        all_files = self.target_files + self.service_files
        
        for file_path in all_files:
            full_path = self.base_path / file_path
            
            if not full_path.exists():
                print(f"   ⚠️  Skipped (not found): {file_path}")
                self.skipped_files.append(file_path)
                continue
            
            print(f"   🔧 Cleaning: {file_path}")
            result = self.clean_file(full_path)
            
            if 'error' in result:
                print(f"      ❌ Error: {result['error']}")
                self.error_files.append(result)
            else:
                print(f"      ✅ Removed {result['removed_count']} debug lines")
                self.cleaned_files.append(result)

    def generate_report(self):
        """Generate cleanup report"""
        print("\n📊 Cleanup Report")
        print("=" * 50)
        
        total_removed = sum(f.get('removed_count', 0) for f in self.cleaned_files)
        total_files = len(self.cleaned_files)
        
        print(f"📁 Files processed: {total_files}")
        print(f"🗑️  Debug lines removed: {total_removed}")
        print(f"⚠️  Files skipped: {len(self.skipped_files)}")
        print(f"❌ Files with errors: {len(self.error_files)}")
        
        if self.cleaned_files:
            print("\n📋 Detailed Results:")
            for result in self.cleaned_files:
                print(f"   {result['file']}: {result['removed_count']} lines removed")
        
        if self.skipped_files:
            print("\n⚠️  Skipped Files:")
            for file in self.skipped_files:
                print(f"   {file}")
        
        if self.error_files:
            print("\n❌ Errors:")
            for error in self.error_files:
                print(f"   {error['file']}: {error['error']}")
        
        print(f"\n💾 Backup location: {self.backup_dir}")
        print("🎯 Performance improvement: Reduced I/O operations and memory usage")

    def run(self):
        """Run the complete cleanup process"""
        print("🚀 Woosh Debug Log Cleanup Tool")
        print("=" * 50)
        
        # Create backup
        self.create_backup()
        
        # Clean files
        self.clean_all_files()
        
        # Generate report
        self.generate_report()
        
        print("\n✅ Cleanup completed successfully!")
        print("💡 Tip: Test the application thoroughly after cleanup")

def main():
    """Main function"""
    cleaner = DebugLogCleaner()
    cleaner.run()

if __name__ == "__main__":
    main() 