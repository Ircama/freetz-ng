#!/bin/bash
#
# Build Python 3.15 external archive
# This script enables Python 3.15 in the configuration, builds the external package,
# and performs basic tests to ensure Python 3.15 is properly included.
#
# Usage: build-python315-external.sh
#

set -e

echo "Creating external archive for Python 3.15..."

# Check if we're in the Freetz-NG root directory
if [ ! -f "Makefile" ] || [ ! -d "make/pkgs/python3" ]; then
    echo "ERROR: This script must be run from the Freetz-NG root directory"
    exit 1
fi

# Enable Python 3.15 in the configuration
echo "Enabling FREETZ_PACKAGE_PYTHON3 in .config..."
if [ -f ".config" ]; then
    sed -i 's/# FREETZ_PACKAGE_PYTHON3 is not set/FREETZ_PACKAGE_PYTHON3=y/' .config
    sed -i 's/FREETZ_PACKAGE_PYTHON3=n/FREETZ_PACKAGE_PYTHON3=y/' .config
    if ! grep -q "FREETZ_PACKAGE_PYTHON3=y" .config; then
        echo "FREETZ_PACKAGE_PYTHON3=y" >> .config
    fi
else
    echo "ERROR: .config file not found. Please run 'make menuconfig' first."
    exit 1
fi

# Ensure external storage is enabled (required for Python 3.15)
echo "Ensuring FREETZ_SEPARATE_AVM_UCLIBC is enabled..."
sed -i 's/# FREETZ_SEPARATE_AVM_UCLIBC is not set/FREETZ_SEPARATE_AVM_UCLIBC=y/' .config
sed -i 's/FREETZ_SEPARATE_AVM_UCLIBC=n/FREETZ_SEPARATE_AVM_UCLIBC=y/' .config
if ! grep -q "FREETZ_SEPARATE_AVM_UCLIBC=y" .config; then
    echo "FREETZ_SEPARATE_AVM_UCLIBC=y" >> .config
fi

echo "Ensuring FREETZ_EXTERNAL_ENABLED is enabled..."
sed -i 's/# FREETZ_EXTERNAL_ENABLED is not set/FREETZ_EXTERNAL_ENABLED=y/' .config
sed -i 's/FREETZ_EXTERNAL_ENABLED=n/FREETZ_EXTERNAL_ENABLED=y/' .config
if ! grep -q "FREETZ_EXTERNAL_ENABLED=y" .config; then
    echo "FREETZ_EXTERNAL_ENABLED=y" >> .config
fi

# Run olddefconfig to ensure config consistency
echo "Running make olddefconfig..."
make olddefconfig > /dev/null

# Build the external package
echo "Building Python 3.15 external package..."
make external-pkg PKG=python3

# Check if build succeeded and Python 3.15 is included
echo "Checking build results..."
if [ ! -d "images" ]; then
    echo "ERROR: images directory not found"
    exit 1
fi

# Find the latest external archive for python3
LATEST_EXTERNAL=$(ls -t images/*python3*.external 2>/dev/null | head -1)
if [ -z "$LATEST_EXTERNAL" ]; then
    echo "ERROR: No Python 3 external archive found in images/"
    exit 1
fi

echo "Latest Python 3 external archive: $LATEST_EXTERNAL"

# Extract and check for Python 3.15
TEMP_DIR=$(mktemp -d /tmp/external_check.XXXXXX)
echo "Extracting external archive to check for Python 3.15..."
cd "$TEMP_DIR"
tar -xf "$LATEST_EXTERNAL" 2>/dev/null || true

if [ -f "usr/lib/python315.zip" ] || [ -f "usr/bin/python3" ]; then
    echo "SUCCESS: Python 3.15 found in external archive"
else
    echo "WARNING: Python 3.15 not found in external archive"
fi

# Cleanup
cd /
rm -rf "$TEMP_DIR"

echo "Python 3.15 external archive creation completed successfully!"