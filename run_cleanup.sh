#!/bin/bash

# Woosh Debug Log Cleanup Script
# This script runs the Python cleanup tool to remove debug logs

echo "🚀 Woosh Debug Log Cleanup"
echo "=========================="

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "lib/pages/journeyplan/createJourneyplan.dart" ]; then
    echo "❌ Please run this script from the woosh directory"
    exit 1
fi

# Create backup directory
echo "📁 Creating backup..."
mkdir -p backup_debug_logs

# Run the advanced cleanup script
echo "🧹 Running debug log cleanup..."
python3 cleanup_debug_logs_advanced.py

# Check if cleanup was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Cleanup completed successfully!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Test the application thoroughly"
    echo "2. Check that all features still work"
    echo "3. Verify no critical errors were removed"
    echo "4. If issues occur, restore from backup_debug_logs_advanced/"
    echo ""
    echo "💡 Performance improvements expected:"
    echo "   - Reduced I/O operations"
    echo "   - Lower memory usage"
    echo "   - Faster app startup"
    echo "   - Cleaner console output"
else
    echo "❌ Cleanup failed. Check the error messages above."
    exit 1
fi 