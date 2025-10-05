# GCC (Native Compiler for On-Device Compilation)
  - Package: [master/make/pkgs/gcc-toolchain/](https://github.com/Freetz-NG/freetz-ng/tree/master/make/pkgs/gcc-toolchain/)
  - Maintainer: [@Ircama](https://github.com/Ircama)

This package provides native GCC compiler capability on Fritz!Box routers.

## Overview

The `gcc-toolchain` package takes the already-compiled cross-compiler GCC used by Freetz-NG's build system and packages it for installation on the target Fritz!Box device. This enables **on-device compilation** of C/C++ programs and Python C extension modules.

## Why This Package?

### Primary Use Case: Python C Extensions

Many Python packages include C extensions that must be compiled during installation:
- **cffi** - Foreign Function Interface for Python
- **pycryptodome** - Cryptographic library
- **numpy**, **pillow**, **lxml** - Common scientific/data packages
- **pyzmq**, **gevent**, **uvloop** - Networking packages

Without native GCC, these packages fail to install via `pip install` on the Fritz!Box.

### Secondary Use Cases
- Compile small C/C++ utilities directly on the router
- Build kernel modules for custom hardware
- Cross-platform development testing

## Requirements

### ⚠️ Build System Requirements

**Building this package requires:**
- **RAM**: Minimum 4GB free RAM (8GB+ recommended)
- **Disk Space**: ~5GB free for compilation
- **Time**: 30-60 minutes depending on CPU

The package builds a native GCC compiler (`gcc_target`) which is **very resource-intensive**. If the build fails with "Terminated" or hangs:
1. Close other applications to free RAM
2. Use `make -j1` to reduce parallel builds
3. Consider using a more powerful build machine

### ⚠️ CRITICAL: External Storage Required (Target Device)

**Size:** ~200-250 MB (depending on configuration)

**You MUST have:**
- USB stick (recommended: 4GB+) or network share
- `FREETZ_EXTERNAL_ENABLED` enabled in menuconfig
- Sufficient free space on external storage

The Fritz!Box internal flash memory is typically only 8-32 MB and cannot accommodate GCC.

## Installation

### 1. Enable in Menuconfig

```bash
make menuconfig
```

Navigate to:
```
Package Selection
  └─> Development
      └─> [*] GCC Toolchain (Native Compiler from Build System)
          └─> [*] GCC Toolchain  # MUST enable externalization
```

#### Configuration Options

- **Minimal installation**: Saves ~50 MB, includes only GCC + essential binutils
- **Include development headers**: Required for compiling most programs (recommended: Y)
- **Include Python headers**: Required for Python C extensions (recommended: Y if using Python)

### 2. Build the Image

```bash
make
```

The build system will:
1. Copy GCC binaries from the toolchain directory
2. Copy required libraries (libgcc_s, libstdc++, etc.)
3. Copy headers (if enabled)
4. Create a package ready for externalization

### 3. Flash the Modified Firmware

Flash the generated image to your Fritz!Box.

### 4. Setup External Storage

After booting, connect a USB stick or configure network share:

```bash
# Check external storage is mounted
ls /var/media/ftp/uStor01/

# The externalization script will automatically create:
# /var/media/ftp/uStor01/freetz-external/gcc-toolchain/
```

### 5. Verify Installation

```bash
# Test GCC
gcc --version

# Test compilation
cat > test.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from Fritz!Box GCC!\n");
    return 0;
}
EOF

gcc test.c -o test
./test
```

Expected output:
```
Hello from Fritz!Box GCC!
```

## Using with Python C Extensions

### Before Installing Python Packages

Ensure environment variables are set for cross-compilation:

```bash
export CC=gcc
export CXX=g++
export LDSHARED="gcc -shared"
export CFLAGS="-march=34kc -mtune=24kc"
export LDFLAGS=""
```

### Install Python Packages with C Extensions

```bash
# Example: Install cffi
pip install --no-binary :all: cffi

# Example: Install pycryptodome
pip install --no-binary :all: pycryptodomex

# Note: --no-binary :all: forces compilation from source
```

### Troubleshooting Python Extensions

If you encounter errors:

1. **Check headers are installed:**
   ```bash
   ls /usr/include/python2.7/Python.h
   ```

2. **Verify GCC is accessible:**
   ```bash
   which gcc
   gcc -v
   ```

3. **Check external storage is mounted:**
   ```bash
   ls -la /tmp/flash/gcc-toolchain/
   # Should show symlinks to /var/media/ftp/uStor01/freetz-external/gcc-toolchain/
   ```

## Package Contents

### Full Installation (~250 MB)

```
/usr/bin/
  ├── gcc, g++, cpp           # Compilers
  ├── cc, c++                 # Symlinks
  ├── as, ld                  # Assembler, linker
  ├── ar, ranlib              # Archive tools
  ├── objdump, objcopy        # Binary utilities
  ├── nm, strings, readelf    # Analysis tools
  ├── gcov, gcov-tool         # Coverage tools
  └── addr2line               # Debug tool

/usr/lib/
  ├── gcc/                    # GCC internal libraries
  ├── libgcc_s.so*            # GCC runtime
  ├── libstdc++.so*           # C++ standard library
  ├── libgomp.so*             # OpenMP runtime
  └── libatomic.so*           # Atomic operations

/usr/libexec/gcc/
  ├── cc1                     # C compiler proper
  ├── cc1plus                 # C++ compiler proper
  ├── collect2                # Linker wrapper
  └── lto1                    # Link-time optimizer

/usr/include/                 # Development headers (if enabled)
  ├── c++/                    # C++ STL headers
  ├── bits/, gnu/, linux/     # System headers
  ├── python2.7/              # Python headers (if enabled)
  └── *.h                     # Standard C headers
```

### Minimal Installation (~200 MB)

Same as full, but excludes:
- objdump, objcopy, nm, strings, readelf, addr2line
- gcov, gprof
- Non-essential binutils

## Technical Details

### How It Works

1. **No Compilation**: This package does NOT compile GCC from source
2. **Reuse Toolchain**: Copies the already-built MIPS GCC from `$(TARGET_TOOLCHAIN_STAGING_DIR)`
3. **Rename Binaries**: Strips the `mips-linux-uclibc-` prefix from binaries
4. **Externalize**: Moves to USB storage due to size constraints

### Relationship to Freetz-NG Toolchain

The Freetz-NG build system uses a cross-compiler GCC (runs on x86_64 Ubuntu, generates MIPS code). This package takes that same GCC and packages it to run on MIPS Fritz!Box (native compilation).

**Key difference:**
- **Cross-compiler:** `x86_64-linux-gnu → mips-linux-uclibc` (build time)
- **Native compiler:** `mips-linux-uclibc → mips-linux-uclibc` (runtime on device)

### Version Compatibility

The GCC version matches your Freetz-NG configuration:
- `FREETZ_AVM_GCC_13` → GCC 13.4.0
- `FREETZ_AVM_GCC_14` → GCC 14.3.0
- `FREETZ_AVM_GCC_15` → GCC 15.2.0 (default)

## Storage Management

### Checking Size

```bash
# After installation, check actual size:
du -sh /var/media/ftp/uStor01/freetz-external/gcc-toolchain/
```

Typical sizes:
- Full + headers: ~250 MB
- Full without headers: ~220 MB
- Minimal + headers: ~200 MB
- Minimal without headers: ~180 MB

### Freeing Up Space

If you need to save space:

1. **Disable unused features:**
   - Uncheck "Include development headers" if not compiling
   - Enable "Minimal installation" to exclude debugging tools

2. **Remove after use:**
   ```bash
   # If you only needed GCC temporarily for Python wheels:
   rm -rf /var/media/ftp/uStor01/freetz-external/gcc-toolchain/
   ```

## Known Limitations

1. **Compilation Speed**: MIPS routers have limited CPU power; compilation is slow
2. **Memory Requirements**: Large programs may fail to compile due to RAM constraints
3. **No Kernel Headers**: Kernel module compilation requires additional kernel-headers package
4. **Temporary Storage**: `/tmp` is limited; use external storage for build directories

## Comparison to Alternatives

| Method | Size | Pros | Cons |
|--------|------|------|------|
| **GCC Toolchain** | ~250 MB | Native compilation, full control | Large, slow compilation |
| **Cross-compile** | 0 MB | Fast, unlimited resources | Requires build system setup |
| **Pre-compiled wheels** | ~1-50 MB | Small, fast installation | Limited package availability |

## Related Freetz-NG PR

This package was created in response to [PR #1242](https://github.com/Freetz-ng/freetz-ng/pull/1242), which fixes Python C extension cross-compilation by properly exporting environment variables (`LDSHARED`, `CC`, `CXX`, etc.) during the build process.

**Timeline:**
- May 11, 2025: Python C extensions worked
- May 20, 2025: Commit `e7cc53902` broke environment variable propagation
- May 28, 2025: PR #1242 proposed fix
- June 2025: This package created to enable native on-device compilation

## Contributing

If you encounter issues or have improvements:

1. Test thoroughly on your Fritz!Box model
2. Report issues with:
   - Fritz!Box model and firmware version
   - GCC version (from menuconfig)
   - Error messages and logs
3. Submit pull requests with clear descriptions

## License

This package follows Freetz-NG's licensing (GPL-2.0). GCC itself is licensed under GPL-3.0+.

## Author

Created by: Ircama
Repository: https://github.com/Freetz-ng/freetz-ng
Branch: gcc

## See Also

- [Freetz-NG Documentation](https://freetz-ng.github.io/freetz-ng/)
- [External Storage Guide](https://freetz-ng.github.io/freetz-ng/wiki/packages/external/)
- [Python Package Documentation](https://freetz-ng.github.io/freetz-ng/wiki/packages/python/)
- [GCC Documentation](https://gcc.gnu.org/onlinedocs/)
