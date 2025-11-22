#!/bin/bash
#
# Build Python 3.14 standalone external archive
# This script creates a complete standalone .external archive with all dependencies
# that can be tested directly without installation on the device.
#
# Usage: build-python314-external.sh [output-name]
#
# The archive will be created in the images/ directory.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FREETZ_BASE="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$FREETZ_BASE"

echo "Creating Python 3.14 standalone external archive..."

# Check if we're in the Freetz-NG root directory
if [ ! -f "Makefile" ] || [ ! -d "make/pkgs/python3" ]; then
    echo "ERROR: Cannot find Freetz-NG root directory"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Find the Python 3.14 build directory
PYTHON_BUILD_DIR=$(find packages/target-* -maxdepth 2 -type d -name "python3-3.14*" 2>/dev/null | head -1)

if [ -z "$PYTHON_BUILD_DIR" ]; then
    echo "ERROR: Python 3.14 not found in packages/"
    echo "Please build Python 3.14 first with: make menuconfig && make"
    exit 1
fi

# Extract target architecture from build directory
TARGET_ARCH=$(echo "$PYTHON_BUILD_DIR" | sed 's|packages/\(target-[^/]*\)/.*|\1|')
ROOT_DIR="packages/$TARGET_ARCH/root"

PYTHON_ROOT="$PYTHON_BUILD_DIR/root"

if [ ! -d "$PYTHON_ROOT/usr/lib/python3.14" ] && [ ! -f "$PYTHON_ROOT/usr/lib/python314.zip" ]; then
    echo "ERROR: Python 3.14 files not found in $PYTHON_ROOT"
    echo "Please build Python 3.14 first with: make"
    exit 1
fi

echo "Found Python 3.14 in: $PYTHON_BUILD_DIR"
echo "Using libraries from: $ROOT_DIR"

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "Creating standalone package in: $TEMP_DIR"

# Create directory structure (matching the old python314-test layout)
mkdir -p "$TEMP_DIR/bin"
mkdir -p "$TEMP_DIR/lib/python3.14"

# Copy Python library directory
if [ -d "$PYTHON_ROOT/usr/lib/python3.14" ]; then
    echo "Copying python3.14 library directory..."
    cp -a "$PYTHON_ROOT/usr/lib/python3.14/"* "$TEMP_DIR/lib/python3.14/"
fi

# Create site-packages directory if it doesn't exist
mkdir -p "$TEMP_DIR/lib/python3.14/site-packages"

# Copy all Python 3 addon packages (3rd-party modules)
echo "Copying Python addon packages..."
ADDON_COUNT=0
for ADDON_DIR in packages/$TARGET_ARCH/python3-*/root/usr/lib/python3.14/site-packages/; do
    if [ -d "$ADDON_DIR" ] && [ "$ADDON_DIR" != "packages/$TARGET_ARCH/python3-3.14*/root/usr/lib/python3.14/site-packages/" ]; then
        ADDON_NAME=$(echo "$ADDON_DIR" | sed 's|.*/python3-\([^/]*\)/.*|\1|')
        echo "  - $ADDON_NAME"
        cp -a "$ADDON_DIR"* "$TEMP_DIR/lib/python3.14/site-packages/" 2>/dev/null || true
        ADDON_COUNT=$((ADDON_COUNT + 1))
    fi
done

if [ $ADDON_COUNT -eq 0 ]; then
    echo "  (no addon packages found)"
else
    echo "  Total: $ADDON_COUNT addon packages copied"
fi

# Copy python314.zip
if [ -f "$PYTHON_ROOT/usr/lib/python314.zip" ]; then
    echo "Copying python314.zip..."
    cp -a "$PYTHON_ROOT/usr/lib/python314.zip" "$TEMP_DIR/lib/"
fi

# Copy Python executable
if [ -f "$PYTHON_ROOT/usr/bin/python3.14.bin" ]; then
    echo "Copying python3.14 executable..."
    cp -a "$PYTHON_ROOT/usr/bin/python3.14.bin" "$TEMP_DIR/bin/"
fi

# Copy all required shared libraries from /usr/lib/freetz/
echo "Copying shared libraries..."

# Copy libpython3.14.so.1.0 and create symlinks
if [ -f "$ROOT_DIR/usr/lib/freetz/libpython3.14.so.1.0" ]; then
    cp -a "$ROOT_DIR/usr/lib/freetz/libpython3.14.so.1.0" "$TEMP_DIR/lib/"
    ln -sf libpython3.14.so.1.0 "$TEMP_DIR/lib/libpython3.14.so"
    echo "  - libpython3.14.so.1.0"
fi

# Copy libz and create symlinks
if [ -f "$ROOT_DIR/usr/lib/freetz/libz.so.1.3.1" ]; then
    cp -a "$ROOT_DIR/usr/lib/freetz/libz.so.1.3.1" "$TEMP_DIR/lib/"
    ln -sf libz.so.1.3.1 "$TEMP_DIR/lib/libz.so.1"
    ln -sf libz.so.1.3.1 "$TEMP_DIR/lib/libz.so"
    echo "  - libz.so.1.3.1"
fi

# Copy libexpat and create symlinks
if [ -f "$ROOT_DIR/usr/lib/freetz/libexpat.so.1.11.1" ]; then
    cp -a "$ROOT_DIR/usr/lib/freetz/libexpat.so.1.11.1" "$TEMP_DIR/lib/"
    ln -sf libexpat.so.1.11.1 "$TEMP_DIR/lib/libexpat.so.1"
    ln -sf libexpat.so.1.11.1 "$TEMP_DIR/lib/libexpat.so"
    echo "  - libexpat.so.1.11.1"
fi

# Create firmware-compatible wrapper script (matching the old script)
cat > "$TEMP_DIR/bin/python3.14" << 'EOF'
#!/bin/sh
#
# Firmware-compatible Python 3.14 wrapper
# This script sets up the environment exactly like the firmware installation
#

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Set Python home to our test installation
export PYTHONHOME="${PYTHON_ROOT}"

# Add our lib directory to library path (mimic firmware setup)
export LD_LIBRARY_PATH="${PYTHON_ROOT}/lib${LD_LIBRARY_PATH:+:}${LD_LIBRARY_PATH}"

# Execute the Python binary with all arguments
exec "${PYTHON_ROOT}/bin/python3.14.bin" -B "$@"
EOF
chmod +x "$TEMP_DIR/bin/python3.14"

# Create python3 symlink
ln -sf python3.14 "$TEMP_DIR/bin/python3"

# Create images directory if it doesn't exist
mkdir -p images

# Generate archive name
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE_NAME="${1:-python314-standalone_${BRANCH}-${COMMIT}_${TIMESTAMP}.tar.gz}"
ARCHIVE_PATH="images/$ARCHIVE_NAME"

echo "Creating archive: $ARCHIVE_PATH"

# Create the archive
cd "$TEMP_DIR"
tar -czf "$FREETZ_BASE/$ARCHIVE_PATH" .

cd "$FREETZ_BASE"

# Verify archive
if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "ERROR: Failed to create archive"
    exit 1
fi

ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
echo
echo "SUCCESS! Python 3.14 standalone archive created:"
echo "  File: $ARCHIVE_PATH"
echo "  Size: $ARCHIVE_SIZE"
echo
echo "Archive contents:"
tar -tzf "$ARCHIVE_PATH" | head -20
echo "  ..."
echo
echo "To test on your device:"
echo "  1. Copy to device: scp $ARCHIVE_PATH root@192.168.178.1:/var/media/ftp/FRITZBOX/test_python/"
echo "  2. Extract: mkdir -p /var/media/ftp/FRITZBOX/test_python/python314 && tar -xzf /var/media/ftp/FRITZBOX/test_python/$(basename "$ARCHIVE_PATH") -C /var/media/ftp/FRITZBOX/test_python/python314/"
echo "  3. Test: /var/media/ftp/FRITZBOX/test_python/python314/bin/python3 << 'PYTEST'"
echo ""
echo "import sys"
echo "print('Python version:', sys.version)"
echo ""
echo "import importlib.metadata"
echo "print('\\nInstalled packages:')"
echo "for dist in importlib.metadata.distributions():"
echo "    print(f'  {dist.metadata[\"Name\"]} {dist.version}')"
echo ""
echo "import os"
echo "print('\\nZip import test:')"
echo "print('  os module from:', os.__file__)"
echo ""
echo "try:"
echo "    import ssl, socket"
echo "    ctx = ssl._create_unverified_context()"
echo "    s = ctx.wrap_socket(socket.socket(), server_hostname='python.org')"
echo "    s.connect(('python.org', 443))"
echo "    print('\\nSSL test: OK -', s.version())"
echo "    s.close()"
echo "except Exception as e:"
echo "    print('\\nSSL test: FAILED -', e)"
echo ""
echo "PYTEST"
echo