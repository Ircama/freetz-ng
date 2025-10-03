# GCC - Native Compiler Toolchain for Freetz-NG

## Overview

This package provides a complete native GCC compiler toolchain that runs directly on your Fritz!Box router. It enables on-device compilation of C/C++ programs and Python C extension modules.

## Features

- **GCC** (C compiler)
- **G++** (C++ compiler, optional)
- **Binutils** (ld, as, ar, ranlib, nm, objdump, etc.)
- **Standard headers** (C and C++ standard library headers)
- **Python headers** (for building Python wheels)
- **GNU Make** (build automation)

## Size

- **Minimal (C only)**: ~150 MB
- **Standard (C/C++)**: ~200 MB  
- **Full (with Fortran)**: ~250 MB

## Requirements

⚠️ **This package REQUIRES external storage (USB drive or network share)**

- USB flash drive or external HDD/SSD
- At least 300 MB free space (recommended: 500 MB)
- External processing must be enabled in `make menuconfig`

## Installation

### 1. Enable in menuconfig

```bash
make menuconfig
```

Navigate to:
```
Package selection
  → Testing
    → [*] GCC (Native Compiler Toolchain)
```

### 2. Build firmware

```bash
make
```

### 3. Externalize to USB storage

After flashing, SSH to your Fritz!Box:

```bash
# Create external directory
mkdir -p /var/media/ftp/uStor01/freetz-external

# Move GCC to USB storage
cp -a /tmp/flash/gcc /var/media/ftp/uStor01/freetz-external/

# Verify installation
gcc --version
```

## Usage Examples

### Compile a simple C program

```bash
cat > hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from Fritz!Box!\n");
    return 0;
}
EOF

gcc hello.c -o hello
./hello
```

### Build Python C extension module

```python
# On Fritz!Box
cat > example.c << 'EOF'
#include <Python.h>

static PyObject* hello(PyObject* self, PyObject* args) {
    return Py_BuildValue("s", "Hello from C extension!");
}

static PyMethodDef methods[] = {
    {"hello", hello, METH_NOARGS, "Say hello"},
    {NULL, NULL, 0, NULL}
};

PyMODINIT_FUNC initexample(void) {
    Py_InitModule("example", methods);
}
EOF

cat > setup.py << 'EOF'
from distutils.core import setup, Extension
setup(name='example', ext_modules=[Extension('example', ['example.c'])])
EOF

python setup.py build_ext --inplace
python -c "import example; print example.hello()"
```

### Build Python wheel from source

```bash
# Install cffi from source (compiles C extensions automatically)
pip install --no-binary :all: cffi

# Or build wheel
pip wheel --no-binary :all: pycrypto
```

### Compile with optimizations

```bash
gcc -O2 -march=34kc -mtune=34kc program.c -o program
```

## Integration with Python

When GCC is installed, Python's build system automatically detects it:

```python
from cffi import FFI
ffi = FFI()

ffi.cdef("int add(int, int);")
ffi.set_source("_math", """
    int add(int a, int b) { return a + b; }
""")

# This will use native GCC!
ffi.compile(verbose=True)

from _math.lib import add
print(add(2, 3))  # Output: 5
```

## Environment Variables

The GCC package automatically sets:

```bash
export CC=gcc
export CXX=g++
export LD=ld
export AR=ar
export RANLIB=ranlib
```

## Troubleshooting

### "gcc: command not found"

Ensure external processing is configured:
1. Check USB drive is mounted: `df -h`
2. Verify symlinks: `ls -la /usr/bin/gcc`
3. Check PATH: `echo $PATH`

### "cannot find -lc"

Headers may be missing. Reinstall package or check:
```bash
ls /usr/include/
```

### Out of memory during compilation

Add swap space:
```bash
# On USB drive
dd if=/dev/zero of=/var/media/ftp/uStor01/swapfile bs=1M count=512
mkswap /var/media/ftp/uStor01/swapfile
swapon /var/media/ftp/uStor01/swapfile
```

## Performance Notes

- **Compilation is slow** on embedded hardware
- Simple programs: 1-10 seconds
- Python wheels: 10-60 seconds
- Large projects: several minutes

For faster builds, consider cross-compilation on Ubuntu.

## Use Cases

✅ **Perfect for:**
- Building Python wheels on-device
- Quick C/C++ prototyping
- Small utility programs
- On-the-fly development

❌ **Not recommended for:**
- Large projects (use cross-compilation)
- Production builds (slower than cross-compilation)
- Memory-constrained devices

## Size Optimization

To reduce size:

1. **Strip binaries** (enabled by default)
2. **Disable C++** if not needed
3. **Skip Fortran** (rarely needed)
4. **Remove debug symbols**

## Security Considerations

⚠️ Having a compiler on the router enables:
- On-device malware compilation
- Potential privilege escalation

**Recommendations:**
- Only install if needed
- Keep firmware updated
- Use strong passwords
- Consider firewall rules

## See Also

- [Python package](../python/README.md)
- [GNU Make package](../gnu-make/README.md)
- [External processing](../../../docs/EXTERNAL.md)

## License

GCC is licensed under GPL v3+. See [COPYING](https://gcc.gnu.org/git/?p=gcc.git;a=blob;f=COPYING3) for details.
