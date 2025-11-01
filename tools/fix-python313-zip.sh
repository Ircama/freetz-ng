#!/bin/bash
#
# Fix Python 3.13 zip importer compatibility
# This script fixes python313.zip to make it compatible with Python 3.13's zip importer
# by copying .pyc files from __pycache__/ to package level
#
# Usage: fix-python313-zip.sh <path_to_python313.zip>
#

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path_to_python313.zip>"
    exit 1
fi

PYTHON_ZIP="$1"

if [ ! -f "$PYTHON_ZIP" ]; then
    echo "ERROR: File not found: $PYTHON_ZIP"
    exit 1
fi

echo "Fixing Python 3.13 zip importer compatibility..."

# Create temporary directory
TEMP_DIR=$(mktemp -d /tmp/python_zip_fix.XXXXXX)

# Extract the ZIP
cd "$TEMP_DIR"
unzip -q "$PYTHON_ZIP"

# Copy .pyc files from __pycache__/ to package level
COPIED=0
while IFS= read -r pycache_dir; do
    package_dir=$(dirname "$pycache_dir")
    for pyc_file in "$pycache_dir"/*.cpython-313.pyc; do
        if [ -f "$pyc_file" ]; then
            module_name=$(basename "$pyc_file" .cpython-313.pyc)
            dst_file="$package_dir/$module_name.pyc"
            if [ ! -f "$dst_file" ]; then
                cp "$pyc_file" "$dst_file"
                COPIED=$((COPIED + 1))
            fi
        fi
    done
done < <(find . -name "__pycache__" -type d)

echo "  Copied $COPIED .pyc files from __pycache__/ to package level"

# Remove __pycache__ directories to save space (files are now at package level)
echo "  Removing __pycache__ directories..."
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# Recreate the ZIP
rm -f "$PYTHON_ZIP"
find . -name "*.pyc" -print | zip -9qy@ "$PYTHON_ZIP"

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo "Python 3.13 zip importer fix completed successfully!"
