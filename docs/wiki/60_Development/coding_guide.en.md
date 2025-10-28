# Freetz-NG Package Development Guide

This guide provides best practices and step-by-step instructions for developing packages in Freetz-NG.

## Table of Contents

1. [General Principles](#general-principles)
2. [Adding Simple Binary Packages](#adding-simple-binary-packages)
3. [Adding Packages with Data Files](#adding-packages-with-data-files)
4. [Adding Multi-Binary Packages](#adding-multi-binary-packages)
5. [Adding Python 3rd-Party Modules](#adding-python-3rd-party-modules)
6. [Makefile Best Practices](#makefile-best-practices)
7. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)
8. [Testing and Validation](#testing-and-validation)

---

## General Principles

### Directory Structure
```
make/pkgs/PACKAGE_NAME/
├── Config.in          # Package configuration
├── PACKAGE_NAME.mk    # Build instructions
├── external.in        # (Optional) Externalization config
├── external.files     # (Optional) Files to externalize
└── files/             # (Optional) Additional files to install
```

### Naming Conventions
- Package directory: `make/pkgs/package-name/`
- Makefile: `package-name.mk` (matches directory name)
- Variables: Use `$(PKG)` macro, NOT hardcoded package names
- Avoid nested variable references: Use `$(ZIP_DIR)` not `$($(PKG)_DIR)`

### SUPPORT Field
Add a SUPPORT field to track maintainership:
```makefile
### SUPPORT:=YourGitHubUsername
```

---

## Adding Simple Binary Packages

**Example: zip package**

### Step 1: Create Directory Structure
```bash
mkdir -p make/pkgs/zip
```

### Step 2: Create Config.in
```bash
cat > make/pkgs/zip/Config.in << 'EOF'
config FREETZ_PACKAGE_ZIP
	bool "zip 3.0 (binary only)"
	default n
	help
		zip - package and compress (archive) files

		Brief description of what the package does.
		
		Can be externalized to save flash memory.
EOF
```

### Step 3: Create Makefile (zip.mk)

**Important:** Handle non-standard archive directory names!

```makefile
$(call PKG_INIT_BIN, 3.0)
$(PKG)_SOURCE:=zip30.tar.gz
$(PKG)_HASH:=<sha256sum>
$(PKG)_SITE:=https://downloads.sourceforge.net/infozip
$(PKG)_SOURCE_DIR:=$(SOURCE_DIR)/$(PKG_LANG)
$(PKG)_DIR:=$($(PKG)_SOURCE_DIR)/zip30  # Actual directory name after extraction
### WEBSITE:=https://infozip.sourceforge.net/Zip.html
### SUPPORT:=YourUsername

$(PKG)_BINARY_BUILD := $(ZIP_DIR)/zip
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/zip

$(PKG)_MAKE_OPTIONS += -f unix/Makefile
$(PKG)_MAKE_OPTIONS += CC="$(TARGET_CC)"
$(PKG)_MAKE_OPTIONS += CPP="$(TARGET_CC) -E"
$(PKG)_MAKE_OPTIONS += CFLAGS="$(TARGET_CFLAGS)"
$(PKG)_MAKE_OPTIONS += generic

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)

# For packages without configure script
$(ZIP_DIR)/.configured: $(ZIP_DIR)/.unpacked
	touch $@

$(ZIP_BINARY_BUILD): $(ZIP_DIR)/.configured
	$(SUBMAKE) -C $(ZIP_DIR) $(ZIP_MAKE_OPTIONS)

$(ZIP_BINARY_TARGET): $(ZIP_BINARY_BUILD)
	$(INSTALL_BINARY_STRIP)

$(pkg):

$(pkg)-precompiled: $(ZIP_BINARY_TARGET)

$(pkg)-clean:
	-$(SUBMAKE) -C $(ZIP_DIR) $(ZIP_MAKE_OPTIONS) clean

$(pkg)-uninstall:
	$(RM) $(ZIP_BINARY_TARGET)

$(PKG_FINISH)
```

**Key Points:**
- If archive extracts to a different directory name (e.g., `zip30` instead of `zip-3.0`), override `$(PKG)_DIR`
- Use direct variable names (`ZIP_DIR`) not nested `$($(PKG)_DIR)` for better make compatibility
- For packages without `./configure`, create `.configured` marker manually

---

## Adding Packages with Data Files

**Example: file package (includes magic database)**

### Additional Files in Makefile

```makefile
$(PKG)_BINARY_BUILD := $($(PKG)_DIR)/src/file
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/file

# Additional data file
$(PKG)_MAGIC_BUILD := $($(PKG)_DIR)/magic/magic.mgc
$(PKG)_MAGIC_TARGET := $($(PKG)_DEST_DIR)/usr/share/misc/magic.mgc

$(PKG_CONFIGURE_OPTIONS) += --enable-static
$(PKG_CONFIGURE_OPTIONS) += --disable-shared

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BINARY_BUILD): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(FILE_DIR)

$($(PKG)_BINARY_TARGET): $($(PKG)_BINARY_BUILD)
	$(INSTALL_BINARY_STRIP)

$($(PKG)_MAGIC_TARGET): $($(PKG)_MAGIC_BUILD)
	$(INSTALL_FILE)

$(pkg)-precompiled: $($(PKG)_BINARY_TARGET) $($(PKG)_MAGIC_TARGET)

$(pkg)-uninstall:
	$(RM) $($(PKG)_BINARY_TARGET)
	$(RM) $($(PKG)_MAGIC_TARGET)
	$(RM) -r $($(PKG)_DEST_DIR)/usr/share/misc
```

### Externalization Support

Create `external.in`:
```
config EXTERNAL_FREETZ_PACKAGE_FILE
	depends on EXTERNAL_ENABLED && FREETZ_PACKAGE_FILE && EXTERNAL_SUBDIRS
	bool "file (externalization recommended)"
	default n
	help
		Externalize file command to USB storage.
		
		Files externalized:
		- /usr/bin/file
		- /usr/share/misc/magic.mgc
```

Create `external.files`:
```bash
if [ "$EXTERNAL_FREETZ_PACKAGE_FILE" == "y" ] ; then
	EXTERNAL_FILES+=" /usr/bin/file /usr/share/misc/magic.mgc"
fi
```

---

## Adding Multi-Binary Packages

**Example: binary-tools (10 binaries from single source)**

### Makefile Structure

```makefile
$(call PKG_INIT_BIN, 2.41)
$(PKG)_SOURCE:=binutils-$($(PKG)_VERSION).tar.xz
$(PKG)_HASH:=<sha256>
$(PKG)_SITE:=https://ftp.gnu.org/gnu/binutils
### SUPPORT:=YourUsername

# Define all binaries
$(PKG)_READELF_BUILD := $($(PKG)_DIR)/binutils/readelf
$(PKG)_READELF_TARGET := $($(PKG)_DEST_DIR)/usr/bin/readelf

$(PKG)_OBJDUMP_BUILD := $($(PKG)_DIR)/binutils/objdump
$(PKG)_OBJDUMP_TARGET := $($(PKG)_DEST_DIR)/usr/bin/objdump

# ... (repeat for all binaries)

$(PKG)_CONFIGURE_OPTIONS += --target=$(REAL_GNU_TARGET_NAME)
$(PKG)_CONFIGURE_OPTIONS += --disable-shared
$(PKG)_CONFIGURE_OPTIONS += --enable-static

# Manual configuration to avoid conflicts with toolchain
$($(PKG)_DIR)/.configured: | $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libc.a
	mkdir -p $(BINARY_TOOLS_DIR)
	(cd $(BINARY_TOOLS_DIR); rm -f config.cache; \
		$(TARGET_CONFIGURE_ENV) \
		$(FREETZ_BASE_DIR)/$(BINARY_TOOLS_SOURCE_DIR)/configure \
		--build=$(GNU_HOST_NAME) \
		--host=$(REAL_GNU_TARGET_NAME) \
		--target=$(REAL_GNU_TARGET_NAME) \
		$(BINARY_TOOLS_CONFIGURE_OPTIONS) \
	)
	touch $@

# Build all
$(BINARY_TOOLS_READELF_BUILD) $(BINARY_TOOLS_OBJDUMP_BUILD) ... : $(BINARY_TOOLS_DIR)/.configured
	$(SUBMAKE) -C $(BINARY_TOOLS_DIR)

# Install each binary
$(BINARY_TOOLS_READELF_TARGET): $(BINARY_TOOLS_READELF_BUILD)
	$(INSTALL_BINARY_STRIP)

# Precompiled target includes ALL binaries
$(pkg)-precompiled: $(BINARY_TOOLS_READELF_TARGET) \
                    $(BINARY_TOOLS_OBJDUMP_TARGET) \
                    # ... (all targets)

$(pkg)-uninstall:
	$(RM) $(BINARY_TOOLS_READELF_TARGET) \
	      $(BINARY_TOOLS_OBJDUMP_TARGET) \
	      # ... (all targets)
```

**Key Points:**
- Avoid using standard `PKG_SOURCE_DOWNLOAD`/`PKG_UNPACKED` macros if they conflict with toolchain
- Manual configuration gives more control
- Group all binary builds in one rule for efficiency

---

## Adding Python3 3rd-Party Modules

### Step 1: Create Package Structure

```bash
mkdir -p make/pkgs/python3-MODULENAME
```

### Step 2: Config.in

```
config FREETZ_PACKAGE_PYTHON3_MODULENAME
	bool "modulename X.Y.Z"
	depends on FREETZ_PACKAGE_PYTHON3
	select FREETZ_PACKAGE_PYTHON3_DEPENDENCY1  # if needed
	default n
	help
		Brief description
		
		Features:
		  - Feature 1
		  - Feature 2
		
		Size: ~X MB
```

Add `depends on FREETZ_SHOW_DEVELOPER` if in developer mode.

### Step 3: Makefile (python3-modulename.mk)

```makefile
$(call PKG_INIT_BIN, X.Y.Z)
$(PKG)_SOURCE:=modulename-$($(PKG)_VERSION).tar.gz
$(PKG)_HASH:=<sha256>
$(PKG)_SITE:=https://files.pythonhosted.org/packages/source/m/modulename
### WEBSITE:=https://pypi.org/project/modulename/
### SUPPORT:=YourUsername

$(PKG)_DEPENDS_ON += python3
$(PKG)_DEPENDS_ON += python3-setuptools

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_NOP)

$($(PKG)_DIR)/.compiled: $($(PKG)_DIR)/.configured
	$(call Build/Py3Mod/Pip, PYTHON3_MODULENAME, , )
	@touch $@

$(pkg):

$(pkg)-precompiled: $($(PKG)_DIR)/.compiled

$(pkg)-clean:
	$(RM) $(PYTHON3_MODULENAME_DIR)/{.configured,.compiled}
	$(RM) -r $(PYTHON3_MODULENAME_DIR)/build

$(pkg)-uninstall:
	$(RM) -r \
		$(PYTHON3_MODULENAME_DEST_DIR)$(PYTHON3_SITE_PKG_DIR)/modulename \
		$(PYTHON3_MODULENAME_DEST_DIR)$(PYTHON3_SITE_PKG_DIR)/modulename-*.dist-info

$(PKG_FINISH)
```

### Step 4: Add to Python3 Menu

Edit `make/pkgs/python3/Config.in` and add under "3rd-party modules":
```
source "make/pkgs/python3-modulename/Config.in"
```

---

## Makefile Best Practices

### Variable References

❌ **AVOID:**
```makefile
$($(PKG)_DIR)/.configured     # Nested variables
$(dir $@)/$(notdir $@)        # Can create double slashes
```

✅ **PREFER:**
```makefile
$(ZIP_DIR)/.configured        # Direct variable
$@                            # Use target directly
```

### Calling External Scripts

❌ **AVOID relative paths:**
```makefile
tools/script.sh packages/...  # Fails if pwd is wrong (some scripts change the current directory internally)
```

✅ **USE absolute paths:**
```makefile
$(FREETZ_BASE_DIR)/tools/script.sh $(FREETZ_BASE_DIR)/packages/...
```

### Process Substitution in Makefiles

❌ **DOESN'T WORK (requires bash):**
```makefile
while read line; do ... done < <(find ...)
```

✅ **WORKS (POSIX sh):**
```makefile
find ... > /tmp/tempfile_$$$$; \
while read line; do ... done < /tmp/tempfile_$$$$; \
rm /tmp/tempfile_$$$$
```

Or better: **Use external bash script!**

## Common Pitfalls and Solutions

### Problem: "No rule to make target 'source/.../package-X.Y'"

**Cause:** Package directory name mismatch after extraction

**Solution:** Override `$(PKG)_DIR`:
```makefile
$(PKG)_SOURCE:=zip30.tar.gz
$(PKG)_DIR:=$($(PKG)_SOURCE_DIR)/zip30  # Actual directory after extraction
```

### Problem: Makefile creates duplicate warnings

**Cause:** Multiple packages using same source (e.g., binutils)

**Solution:** Don't use standard macros for secondary packages:
```makefile
# DON'T use: $(PKG_SOURCE_DOWNLOAD), $(PKG_UNPACKED)
# Instead: manually manage dependencies
$($(PKG)_DIR)/.configured: | $(TOOLCHAIN_DEPENDENCY)
	# custom build
```

### Problem: Script fails with "file not found" in makefile

**Cause:** Script executed from build directory, relative paths broken

**Solution:** Always use `$(FREETZ_BASE_DIR)` prefix:
```makefile
$(FREETZ_BASE_DIR)/tools/script.sh $(FREETZ_BASE_DIR)/packages/...
```

### Problem: Python 3.13 "No module named 'encodings'"

**Cause:** Python 3.13 changed zip importer behavior - requires `.pyc` files at package level, not just in `__pycache__/`

**Solution:** Use fix script:
```makefile
$(if $(FREETZ_PACKAGE_PYTHON3_COMPRESS_PYC), \
	$(FREETZ_BASE_DIR)/tools/fix-python313-zip.sh $(FREETZ_BASE_DIR)/$@; \
)
```

### Build Won't Start

**Problem:** Running `make PACKAGE` does nothing or fails immediately.

**Common Causes:**

1. **Missing `-precompiled` or `-recompile` suffix**
   - ❌ Wrong: `make zip`
   - ✅ Correct: `make zip-precompiled` or `make zip-recompile`. Always use `make help` for instructions.
   
   See *00_FAQ/FAQ.en.md* in the Wiki for the **description of the make options**.

2. **Package not registered in build system**
   - Missing from `make/pkgs/Config.in.generated` (auto-generated, don't edit manually)
   - Solution: Ensure `Config.in` exists and run `make config-clean-deps`

3. **Makefile syntax errors**
   - Check for proper tab indentation (Makefiles require tabs, not spaces!)
   - Validate variable references: use `$(ZIP_DIR)` not `$($(PKG)_DIR)` for direct access

**Diagnostic Steps:**

```bash
# Step 1: List available targets for your package
make help | grep -i PACKAGE

# Step 2: Clean and rebuild configuration
make config-clean-deps
make menuconfig  # Enable your package

# Step 3: Clean build test
make PACKAGE-dirclean
make PACKAGE-precompiled

# Step 4: Check for errors in Config.in
cat make/pkgs/PACKAGE/Config.in
# Verify: proper syntax, no typos in config names

# Step 5: Validate makefile syntax
make -n PACKAGE-precompiled  # Dry run to check make logic
```

**Target Suffixes Reference:**

| Target | Description | When to Use |
|--------|-------------|-------------|
| `PACKAGE` | Alias, usually does nothing | Don't use directly |
| `PACKAGE-precompiled` | Build and install to staging | First build, fresh compile |
| `PACKAGE-recompile` | Rebuild without dirclean | Iterative development |
| `PACKAGE-clean` | Clean build artifacts | After source changes |
| `PACKAGE-dirclean` | Complete clean, re-extract source | Reset to pristine state |
| `PACKAGE-uninstall` | Remove from staging | Testing removal |

See *00_FAQ/FAQ.en.md* in the Wiki.

### Problem: While loop in makefile doesn't modify files

**Cause:** Pipe creates subshell, changes don't persist

**Solution:** Use temp file:
```makefile
find ... > /tmp/list_$$$$; \
while read item; do \
	# modifications happen in main shell
done < /tmp/list_$$$$; \
rm /tmp/list_$$$$
```

Or: **Extract to separate bash script!**

---

## Freetz-NG Specific Coding Conventions

### Shell Coding Standards

**TAB Indentation (REQUIRED)**
- Makefiles and shell scripts MUST use TAB characters (not spaces)
- Visual display: 4 spaces, but character MUST be TAB
- Continuation lines: TAB + 2 spaces

### Package Initialization Macros

**PKG_INIT_BIN vs PKG_INIT_LIB**
```makefile
# For binary packages
$(call PKG_INIT_BIN, VERSION)

# For library packages
$(call PKG_INIT_LIB, VERSION)
```

**Naming Conventions**
- `$pkg` (lowercase) = package name
- `$PKG` (uppercase) = makefile variables
- Example: `$(PKG)_VERSION`, `$(PKG)_SOURCE`, `$(PKG)_BINARY`

**Target Directory Conventions**
```makefile
# Binary packages
$(PKG)_TARGET_DIR := $(TARGET_SPECIFIC_ROOT_DIR)/usr/bin

# Library packages
$(PKG)_TARGET_DIR := $(TARGET_SPECIFIC_ROOT_DIR)$(FREETZ_LIBRARY_DIR)
```

### Standard Makefile Targets

All packages should support:
- `PACKAGE-download` - Download source archive
- `PACKAGE-source` - Download and extract source
- `PACKAGE-unpacked` - Extract and apply patches
- `PACKAGE-precompiled` - Build and install to staging
- `PACKAGE-clean` - Clean build artifacts
- `PACKAGE-dirclean` - Remove source directory completely
- `PACKAGE-list` - List installed files
- `PACKAGE-uninstall` - Remove installed files

### STARTLEVEL System

Package initialization order (00-99):
- **00**: Critical services (crond, telnetd, webcfg)
- **10-14**: Basics (inotify, usbroot, syslogd, downloader, inetd)
- **20-25**: Network interfaces and firewall
- **30**: SSH services (authorized-keys, ca-bundle, dropbear)
- **40**: DNS services (bind, dnsmasq, unbound)
- **50**: Mounting services (autofs, cifsmount, davfs2)
- **60-90**: Various application services
- **99**: Default (no runscript needed)

Set in makefile:
```makefile
$(PKG)_STARTLEVEL=50  # Custom start level
```

### Multi-Binary Packages Pattern

Use static pattern rules to avoid code duplication:

```makefile
# Define all possible binaries
$(PKG)_BINARIES_ALL := binary1 binary2 binary3

# Filter based on user selection
$(PKG)_BINARIES := $(strip $(foreach binary,$($(PKG)_BINARIES_ALL),\
    $(if $(FREETZ_PACKAGE_$(PKG)_$(shell echo $(binary) | tr [a-z] [A-Z])),$(binary))))

# Build directory paths
$(PKG)_BINARIES_BUILD_DIR := $($(PKG)_BINARIES:%=$($(PKG)_DIR)/%)

# Target directory paths
$(PKG)_BINARIES_TARGET_DIR := $($(PKG)_BINARIES:%=$($(PKG)_DEST_DIR)/usr/bin/%)

# Cleanup non-included binaries
$(PKG)_NOT_INCLUDED := $(patsubst %,$($(PKG)_DEST_DIR)/usr/bin/%,\
    $(filter-out $($(PKG)_BINARIES),$($(PKG)_BINARIES_ALL)))

# Static pattern rule for installation
$($(PKG)_BINARIES_TARGET_DIR): $($(PKG)_DEST_DIR)/usr/bin/%: $($(PKG)_DIR)/%
	$(INSTALL_BINARY_STRIP)
```

### Device Table Format

For creating device nodes without root privileges:

```
#<name>          <type> <mode> <uid> <gid> <major> <minor> <start> <inc> <count>
/dev/ttyS        c      666    0     0     4       64      0       1     4
```

**Types**: `f` (file), `d` (directory), `c` (char device), `b` (block device), `p` (fifo)

**Device Ranges**: Use start/inc/count to create multiple devices:
```
/dev/hda         b      640    0     0     3       1       1       1     15
# Creates /dev/hda1 through /dev/hda15
```

### Persistent Configuration

Packages requiring persistent settings:

**Location**: `/etc/default.$package/$package.cfg`

**Format**: Shell variables with package prefix
```bash
export PACKAGE_VARIABLE="value"
export PACKAGE_OPTION="enabled"
```

**Save Mechanism**:
```bash
pkg_pre_save() {
    # Pre-processing before save
}

pkg_apply_save() {
    # Actual save operation
    modconf set $package VAR=value
}

pkg_post_save() {
    # Post-processing after save
}
```

**User Commands**:
```bash
# Set configuration
modconf set package VARIABLE=value

# Save to package config
modconf save package

# Flash to permanent storage
modsave flash

# Shortcut (save + flash)
modsave
```

### Patch Format and Best Practices

**Patch Structure**:
```
Description of what this patch does and why

--- original/file.c
+++ modified/file.c
@@ -51,6 +51,7 @@
 context line before
 context line before
 context line before
+new line added
 context line after
 context line after
 context line after
```

**Creating Patches**:
```bash
# Single file
svn diff Config.in > Config.patch

# All changes
svn diff > all.patch

# Add new files first
svn add filename
```

**Applying Patches**:
```bash
# Apply
patch -p0 < file.patch

# Revert
patch -Rp0 < file.patch

# Failed patch creates .rej file
```

---

## Troubleshooting Build Issues

### Build Won't Start

**Symptoms**: Build fails immediately or configuration issues

**Solutions**:
1. **Clean generated config files**:
   ```bash
   rm -f make/pkgs/Config.in.generated make/pkgs/external.in.generated config/.cache.in
   make config-clean-deps
   ```

2. **Verify Config.in syntax**:
   - Check for missing `endif`, `endchoice`, `endmenu`
   - Ensure proper indentation (TABs not spaces)
   - Run `make menuconfig` to catch warnings

3. **Check dependencies**:
   - Verify `select` and `depends on` statements
   - Ensure selected packages exist

### Make Fail Strategies

**dirclean Strategy**:
```bash
make PACKAGE-dirclean
make PACKAGE-precompiled
```
- Removes source directory completely
- Regenerates all Makefiles from scratch
- Use when configure options change

**precompiled Strategy**:
```bash
make PACKAGE-precompiled
```
- Builds package from clean state
- Doesn't remove source directory
- Faster than dirclean

**recompile Strategy**:
```bash
make PACKAGE-recompile
```
- Recompiles without full cleanup
- Quick iteration during development
- May miss dependency changes

### GCC Target Compilation Troubleshooting

**CFLAGS Pollution Issue**:

**Symptom**: Host compiler receives target flags
```
error: unknown argument: '-march=34kc'
```

**Root Cause**: `TARGET_CONFIGURE_ENV` sets CFLAGS with MIPS flags, inherited by host compiler during GCC build

**Solution**: Reset CFLAGS during configure and make
```makefile
$($(PKG)_DIR)/.configured:
	CFLAGS="" CXXFLAGS="" \
	CFLAGS_FOR_BUILD="$(TOOLCHAIN_HOST_CFLAGS)" \
	CXXFLAGS_FOR_BUILD="$(TOOLCHAIN_HOST_CXXFLAGS)" \
	$(TARGET_CONFIGURE_ENV) \
	./configure $(TARGET_CONFIGURE_OPTIONS)
	touch $@

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	CFLAGS= CXXFLAGS= \
	$(MAKE) -C $($(PKG)_DIR) -j1
```

**Cached Makefiles**:
- Always use `make PACKAGE-dirclean` before rebuild after changing configure options
- GCC configure caches flags in generated Makefiles

**libcc1 Plugin Bug**:

**Symptom**: 
```
configure: line 15097: -T: command not found
```

**Root Cause**: libcc1 plugin has broken configure script for MIPS cross-compile

**Solution**: Disable libcc1 (not needed for compiler functionality)
```makefile
$(GCC_TARGET_DIR)/.configured: $(GCC_DIR)/.configured
	mkdir -p $(GCC_TARGET_DIR)
	cd $(GCC_TARGET_DIR) && \
	CFLAGS="" CXXFLAGS="" \
	$(GCC_CONFIGURE_ENV) \
	$(GCC_DIR)/configure \
		--disable-libcc1 \
		$(GCC_TARGET_CONFIGURE_OPTIONS)
	touch $@
```

### Target Suffix Reference

| Suffix | Host Compiler | Target Architecture | Example |
|--------|--------------|---------------------|---------|
| `_initial` | Build (x86_64) | Build (x86_64) | gcc_initial |
| (none/stage2) | Build (x86_64) | Target (MIPS) | gcc (cross-compiler) |
| `_target` | Target (MIPS) | Target (MIPS) | gcc_target (native) |

---

## Precompiled Host-Tools System

Freetz-NG uses a **precompiled host-tools package** to speed up builds for end users. Understanding this system is crucial when updating host-tools.

### How It Works

**1. GitHub Actions Workflow (`.github/workflows/dl-hosttools.yml`)**

The workflow automatically builds and packages all host-tools when triggered:

```yaml
on:
  push:
    branches: [ master ]
    paths:
      - '.github/workflows/dl-hosttools.yml'
      - 'tools/dl-hosttools'
      - 'make/host-tools/tools-host/tools-host.mk'
  workflow_dispatch:  # Manual trigger
```

**Triggers:**
- Push to `master` branch
- Changes to workflow, packaging script, or `tools-host.mk`
- **Manual trigger** via `workflow_dispatch` (Actions → Run workflow)

**2. Build Process (`tools/dl-hosttools` script)**

The script compiles all host-tools from source:

```bash
make tools-allexcept-local  # Compiles ALL host-tools
```

This includes:
- `patchelf` - ELF binary patcher
- `fakeroot` - Fake root privileges
- `autoconf`, `automake`, `libtool` - Build system tools
- `squashfs-tools` - Filesystem tools
- Many others (see `tools/.gitignore`)

**3. Packaging**

Creates a single tarball with all compiled tools:

```bash
tar cf - $(tools listed in .gitignore) | xz -9 - > "dl/tools-VERSION.tar.xz"
```

**4. Release**

Uploads the package to GitHub Releases for public download.

**5. Version Bump**

Updates `make/host-tools/tools-host/tools-host.mk` with new version and SHA256 hash.

### User Perspective

**Fresh Clone with Precompiled Tools (Default)**:

```bash
git clone https://github.com/Ircama/freetz-ng.git
cd freetz-ng
make menuconfig
make
```

What happens:
1. `make` detects `FREETZ_HOSTTOOLS_DOWNLOAD=y` (default)
2. Downloads `tools-VERSION.tar.xz` from GitHub Releases
3. Extracts to `tools/` directory
4. **Skips compilation** of individual host-tools (saves ~30 minutes!)

**Build from Source**:

```bash
make menuconfig
# Set: Advanced → Freetz NG Compilation Environment → Download precompiled tools → NO
make
```

What happens:
1. Compiles each host-tool from source using `make/host-tools/TOOL/TOOL.mk`
2. Takes longer but always uses latest makefile definitions

### Developer Perspective: Updating a Host-Tool

**Example: Upgrading patchelf from 0.15.0 to 0.18.0**

#### Step 1: Update the Host-Tool Makefile

```makefile
# In make/host-tools/patchelf-host/patchelf-host.mk
$(call TOOLS_INIT, 0.18.0)  # Was: 0.15.0
$(PKG)_SOURCE:=$(pkg)-$($(PKG)_VERSION).tar.bz2
$(PKG)_HASH:=1952b2a782ba576279c211ee942e341748fdb44997f704dd53def46cd055470b
$(PKG)_SITE:=https://github.com/NixOS/patchelf/releases/download/$($(PKG)_VERSION)
```

#### Step 2: Test Locally

**CRITICAL**: You must manually compile the tool to test your changes:

```bash
# Clean old version
make patchelf-host-dirclean

# Compile new version
make patchelf-host-precompiled

# Verify
tools/patchelf --version
# Should output: patchelf 0.18.0
```

**Why?** If you just run `make`, it will download the old precompiled package and skip compilation!

#### Step 3: Test in Real Build

```bash
# Use the updated tool in actual build
make menuconfig
# Select packages that use patchelf
make
```

#### Step 4: Submit Pull Request

Include a reminder in your PR description in case the precompiled tools package needs to be rebuilt.

Use `make TOOL-precompiled` to test locally (it forces compilation from source using your updated makefile).

### Debugging Host-Tools Issues

**Check which version is being used:**

```bash
# Check version
tools/patchelf --version

# Check file timestamp
ls -la tools/patchelf

# Check if from precompiled package or compiled locally
find source/host-tools -name "patchelf-*" -type d
# If found → compiled locally
# If not found → from precompiled package
```

**Force local compilation:**

```bash
# Remove precompiled tool
rm tools/patchelf

# Remove downloaded package
rm dl/tools-*.tar.xz

# Compile from source
make patchelf-host-precompiled
```

**Check tools-host version:**

```bash
# See current precompiled package version
grep TOOLS_INIT make/host-tools/tools-host/tools-host.mk
# Output: $(call TOOLS_INIT, r12345)
```

## Essential Wiki Documentation

The following wiki documents provide detailed information on Freetz-NG development:

### Package Development
- **[Package Development Start](../wiki/60_Development/package_development_start.en.md)** - Getting started with your first package
- **[Package Development Basics](../wiki/60_Development/package_development_basics.en.md)** - Fundamental concepts and persistent settings
- **[Package Development Makefiles](../wiki/60_Development/package_development_makefiles.en.md)** - Makefile conventions and macros
- **[Package Development Advanced](../wiki/60_Development/package_development_advanced.en.md)** - Multi-binary packages and patterns
- **[Shell Coding Conventions](../wiki/60_Development/shell_coding_conventions.en.md)** - Shell scripting standards

### Specific Topics
- **[STARTLEVEL of Packages](../wiki/60_Development/startlevel_of_packages.en.md)** - Package initialization order (00-99)
- **[Device Table](../wiki/60_Development/device_table.md)** - Creating device nodes on-the-fly
- **[Patch Format](../wiki/60_Development/patch.md)** - Creating and applying patches
- **[Package Configuration](../wiki/60_Development/package_development_config.en.md)** - modconf and modsave commands

### Troubleshooting
- **[Make Fail Strategies](../wiki/40_Troubleshooting/make_fail.md)** - dirclean, precompiled, recompile strategies

### Examples
- **[Package Example 1](../wiki/60_Development/package_development_pkgexample1.en.md)** - Simple binary package
- **[Package Example 2](../wiki/60_Development/package_development_pkgexample2.en.md)** - Package with patches
- **[Package Example 3](../wiki/60_Development/package_development_pkgexample3.en.md)** - Package with library dependencies

**Tip**: Always consult these documents when implementing complex features or troubleshooting build issues.

---

## Package Documentation

### Documentation Location

**All package-specific documentation must be placed in `docs/make/`.**

This directory contains user-facing documentation for individual packages, following a consistent naming convention:

**Naming Convention**: `package-name.md` (lowercase, hyphen-separated)

**Examples**:
- `gcc-toolchain.md` - GCC native compiler documentation
- `python3.md` - Python 3 interpreter
- `python-cffi.md` - Python CFFI module
- `binary-tools.md` - Binary utilities (readelf, objdump, etc.)

### When to Create Package Documentation

Create documentation in `docs/make/` when:

1. **Complex Setup Required** - Package needs configuration beyond default
2. **Non-Obvious Usage** - Special commands or workflows needed
3. **Important Limitations** - Size requirements, dependencies, compatibility issues
4. **Integration Examples** - How to use with other packages
5. **Troubleshooting** - Common issues and solutions

### Documentation Template

```markdown
# Package Name

## Overview
Brief description of what the package does.

## Installation
Size, dependencies, special requirements.

## Configuration
How to configure via menuconfig or config files.

## Usage
Basic usage examples and commands.

## Troubleshooting
Common issues and solutions.

## See Also
Related packages, wiki links, external resources.
```

### Current Package Documentation

The following packages have dedicated documentation in `docs/make/`:

**Development Tools**:
- `gcc-toolchain.md` - Native GCC compiler for on-device compilation
- `gcc-toolchain-summary.md` - Quick start guide and executive summary
- `gcc-toolchain-changes.md` - Technical changelog of all modifications
- `binary-tools.md` - Binary utilities (readelf, objdump, nm, strings, ar, ranlib, strip, addr2line, size)

**Python Ecosystem**:
- `python.md` - Python 2.x (legacy)
- `python3.md` - Python 3.13.7 interpreter
- `python-cffi.md` - C Foreign Function Interface for Python (1.17.1)
- `python-pycryptodome.md` - Cryptographic library for Python (3.23.0)

**Note**: Not all packages require documentation. Small, self-explanatory packages (like `file`, `zip`, `unzip`) can rely on Config.in help text alone. Create documentation when setup is complex, usage is non-obvious, or troubleshooting guidance is needed.

### Updating the Package Index

**IMPORTANT**: After creating or updating package documentation, you MUST regenerate the package index.

The file `docs/make/README.md` is **auto-generated** and should NEVER be edited manually. It serves as the main index for all packages and their documentation.

**Regeneration Process**:

```bash
# From the repository root
cd docs/make
bash generate.sh

# Or regenerate all documentation at once
cd docs
bash generate.sh
```

**What the script does**:

1. Scans all packages in `make/pkgs/`
2. Extracts package information from:
   - `Config.in` - Package title and help text
   - `PACKAGE.mk` - Metadata (SUPPORT, WEBSITE, MANPAGE, CHANGES, CVSREPO)
   - Existing `.md` files in `docs/make/` - Creates links if documentation exists
3. Organizes packages by category (Packages, Debug helpers, Unstable, etc.)
4. Generates alphabetical index with links
5. Creates both `make/pkgs/README.md` and `docs/make/README.md`

**When to regenerate**:

- After creating new package documentation (`.md` file)
- After adding new package to `make/pkgs/`
- After changing package title in `Config.in`
- After updating package metadata in `.mk` file (SUPPORT, WEBSITE, etc.)
- Before submitting a pull request

**Example workflow**:

```bash
# 1. Create your package
mkdir make/pkgs/mypackage
vim make/pkgs/mypackage/Config.in
vim make/pkgs/mypackage/mypackage.mk

# 2. Create documentation
vim docs/make/mypackage.md

# 3. Regenerate index
cd docs/make
bash generate.sh

# 4. Verify your package appears
grep "mypackage" README.md

# 5. Commit everything
git add make/pkgs/mypackage/
git add docs/make/mypackage.md
git add docs/make/README.md make/pkgs/README.md
git commit -m "Add mypackage: Brief description"
```

**Common mistakes**:

- Editing `docs/make/README.md` manually (changes will be overwritten!)
- Forgetting to regenerate after creating documentation
- Committing package without regenerating index

**Verification**:

After regeneration, check that:
- Your package appears in the correct category
- Documentation link works (if `.md` file exists)
- Help text is properly extracted from `Config.in`
- Metadata links are correct (if defined in `.mk`)

---

## Resources

- Main Makefile: `Makefile`
- Package macros: `make/pkgs/Makefile.in`
- Python helpers: `make/pkgs/python3/python3.mk`
- Existing packages: `make/pkgs/*/`
- Tools directory: `tools/`
- Wiki documentation: `docs/wiki/`
- Package documentation: `docs/make/`

------------

# Freetz-NG Library Management Guide

This document explains how Freetz-NG manages shared libraries, handles potential conflicts with AVM firmware libraries, and implements library externalization.

## Table of Contents

1. [Overview](#overview)
2. [AVM Firmware Library Structure](#avm-firmware-library-structure)
3. [Freetz-NG Library Structure](#freetz-ng-library-structure)
4. [Library Separation Strategy](#library-separation-strategy)
5. [RPATH and Dynamic Linking](#rpath-and-dynamic-linking)
6. [ABI Configuration](#abi-configuration)
7. [Library Externalization](#library-externalization)
8. [Best Practices for Package Developers](#best-practices-for-package-developers)
9. [External Configuration Guidelines](#external-configuration-guidelines)

---

## Overview

Freetz-NG extends AVM FRITZ!Box firmware by adding additional functionality while maintaining compatibility with the original firmware. A critical aspect of this integration is managing shared libraries to avoid conflicts between AVM's native libraries and Freetz-added libraries.

---

## AVM Firmware Library Structure

### Core Libraries (`/lib/`)

AVM firmware uses **MUSL libc** as its C standard library, located in `/lib/`:

```
/lib/
├── ld-musl-mips-sf.so.1  # MUSL dynamic linker
├── libc.so.1              # MUSL C library (symlink)
└── [other AVM core libraries]
```

**Key Characteristics:**
- **C Library**: MUSL libc
- **Dynamic Linker**: `/lib/ld-musl-mips-sf.so.1`
- **Usage**: All native AVM binaries and services
- **Location**: `/lib/` (core system libraries)

### AVM User Libraries (`/usr/lib/`)

AVM also provides additional libraries in `/usr/lib/` for its applications:

```
/usr/lib/
├── libavmdb.so
├── libfbcp.so
└── [other AVM-specific libraries]
```

These libraries are specifically for AVM applications and services.

---

## Freetz-NG Library Structure

### Standard Freetz Libraries (`/usr/lib/`)

Freetz generally places additional libraries in `/usr/lib/` when they:
- Do NOT conflict with AVM libraries
- Are new libraries not present in AVM firmware
- Are required by Freetz packages

**Example: Freetz-only libraries**
```
/usr/lib/
├── libopenssl.so.3      # Added by Freetz (not in AVM)
├── libcurl.so.4         # Added by Freetz (not in AVM)
└── libsqlite3.so.0      # Added by Freetz (not in AVM)
```

### Separated Freetz Libraries (`/usr/lib/freetz/`)

When a library conflicts with an AVM library (same name, different version), Freetz uses a **separate directory** to avoid conflicts:

```
/usr/lib/freetz/
├── ld-uClibc.so.1       # uClibc dynamic linker (ABI1)
├── libc.so.0            # uClibc C library
├── libgcc_s.so.1        # GCC runtime library
├── libstdc++.so.6       # C++ standard library
├── libz.so.1            # zlib (if AVM also has libz)
└── [other separated libraries]
```

**Key Characteristics:**
- **C Library**: uClibc (version 1.0.55+)
- **Dynamic Linker**: `/usr/lib/freetz/ld-uClibc.so.1`
- **Usage**: Freetz binaries compiled with `FREETZ_SEPARATE_AVM_UCLIBC=y`
- **RPATH**: Freetz binaries have RPATH set to `/usr/lib/freetz/`

---

## Library Separation Strategy

### When to Use `/usr/lib/`

Use `/usr/lib/` when:
- The library is **new** (not present in AVM firmware)
- There is **no name conflict** with AVM libraries
- The library is **compatible** with AVM's runtime environment

**Example packages using `/usr/lib/`:**
- OpenSSL (libssl.so, libcrypto.so)
- cURL (libcurl.so)
- SQLite (libsqlite3.so)

### When to Use `/usr/lib/freetz/`

Use `/usr/lib/freetz/` when:
- The library **name conflicts** with an AVM library
- The library **version differs** from AVM's version
- The library is part of the **core runtime** (libc, libgcc, libstdc++)
- Package configuration enables `FREETZ_SEPARATE_AVM_UCLIBC=y`

**Example libraries requiring separation:**
- **libc.so**: AVM uses MUSL, Freetz uses uClibc
- **libz.so**: Different versions between AVM and Freetz
- **libgcc_s.so**: GCC runtime support library
- **libstdc++.so**: C++ standard library

### Configuration Variable: `FREETZ_SEPARATE_AVM_UCLIBC`

This configuration option controls library separation:

```kconfig
config FREETZ_SEPARATE_AVM_UCLIBC
	bool "Separate uClibc"
	default n
	help
		Puts uClibc of Freetz into /usr/lib/freetz/,
		needs about 1 MB (uncompressed).
```

**Effect when enabled:**
- Freetz uses uClibc in `/usr/lib/freetz/`
- All Freetz binaries use dynamic linker `/usr/lib/freetz/ld-uClibc.so.1`
- No conflicts with AVM's MUSL libraries in `/lib/`

**Important:** A library should exist in **either** `/usr/lib/` **or** `/usr/lib/freetz/`, but **never both**. Use `/usr/lib/freetz/` only when `/usr/lib/` contains the AVM version of the same library.

---

## RPATH and Dynamic Linking

### What is RPATH?

RPATH (Run-Path) is embedded into ELF binaries and tells the dynamic linker where to search for shared libraries at runtime.

### Freetz RPATH Configuration

Freetz binaries compiled with `FREETZ_SEPARATE_AVM_UCLIBC=y` have RPATH set to `/usr/lib/freetz/`:

```bash
$ readelf -d /usr/bin/php | grep RPATH
 0x0000000f (RPATH)    Library rpath: [/usr/lib/freetz/]
```

**Library Search Order for Freetz Binaries:**
1. **RPATH**: `/usr/lib/freetz/` (embedded in binary)
2. `/usr/lib/`
3. `/lib/`

**Library Search Order for AVM Binaries:**
- AVM binaries have **no RPATH** set
- They use system default search paths: `/lib/`, `/usr/lib/`
- They **completely ignore** `/usr/lib/freetz/`

### Complete Separation: No Conflicts Possible

This design ensures **complete isolation**:

| Binary Type | Dynamic Linker | Library Path Priority | C Library Used |
|-------------|----------------|----------------------|----------------|
| **AVM binaries** | `/lib/ld-musl-mips-sf.so.1` | `/lib/`, `/usr/lib/` | MUSL |
| **Freetz binaries** | `/usr/lib/freetz/ld-uClibc.so.1` | `/usr/lib/freetz/`, `/usr/lib/`, `/lib/` | uClibc |

**Result**: AVM and Freetz binaries run in separate "worlds" with zero library conflicts.

### Dynamic Linker Override

Freetz build system forces the correct dynamic linker at compile time:

```makefile
# From make/pkgs/Makefile.in
ifeq ($(strip $(FREETZ_SEPARATE_AVM_UCLIBC)),y)
FREETZ_LIBRARY_DIR:=/usr/lib/freetz
TARGET_CFLAGS_LD:=-Wl,-I$(FREETZ_LIBRARY_DIR)/ld-uClibc.so.1
else
FREETZ_LIBRARY_DIR:=/usr/lib
TARGET_CFLAGS_LD:=
endif
```

The `-Wl,-I/usr/lib/freetz/ld-uClibc.so.1` flag overrides GCC's default linker specs, ensuring all Freetz binaries use the correct dynamic linker.

---

## ABI Configuration

### What is ABI?

ABI (Application Binary Interface) defines the low-level interface between binary modules (programs, libraries, OS). For uClibc, the ABI version affects the dynamic linker name.

### uClibc ABI Versions

| uClibc Version | ABI | Dynamic Linker |
|----------------|-----|----------------|
| 0.9.28 - 0.9.33 | **ABI0** | `ld-uClibc.so.0` |
| 1.0.x+ | **ABI1** | `ld-uClibc.so.1` |

### Freetz ABI Configuration

Freetz-NG primarily uses **uClibc 1.0.55** with **ABI1**:

```makefile
# GCC specs file expects ABI0 by default
# Freetz overrides this at runtime with TARGET_CFLAGS_LD
TARGET_CFLAGS_LD:=-Wl,-I/usr/lib/freetz/ld-uClibc.so.1
```

**Key Points:**
- GCC toolchain specs file may reference ABI0 (`ld-uClibc.so.0`)
- Freetz **overrides** at runtime using `-Wl,-I` flag
- Final binaries use ABI1 linker (`ld-uClibc.so.1`)
- This override happens during compilation, not installation

### Verification on a device

You can verify the dynamic linker on a running device via SSH:

```bash
# Check Freetz binary
$ readelf -l /usr/bin/php | grep interpreter
  [Requesting program interpreter: /usr/lib/freetz/ld-uClibc.so.1]

# Check library dependencies
$ ldd /usr/bin/php
	libc.so.0 => /usr/lib/freetz/libc.so.0
	ld-uClibc.so.1 => /usr/lib/freetz/ld-uClibc.so.1
```

---

## Library Externalization

### What is Externalization?

Library externalization moves library files from internal flash memory to external storage (USB stick, SD card) to save flash space. This is implemented through:
1. **Moving files**: Real library files → `/mod/external/usr/lib/freetz/`
2. **Creating symlinks**: Original locations → external storage

### Directory Structure

#### Before Externalization
```
/usr/lib/freetz/
├── libiconv.so.2.7.0    # Real file in flash (1.2 MB)
├── libiconv.so.2        # Symlink → libiconv.so.2.7.0
└── libiconv.so          # Symlink → libiconv.so.2
```

#### After Externalization
```
# External storage (real files)
/mod/external/usr/lib/freetz/
├── libiconv.so.2.7.0    # Real file (1.2 MB)
├── libiconv.so.2        # Symlink → libiconv.so.2.7.0
└── libiconv.so          # Symlink → libiconv.so.2

# Flash memory (symlinks)
/usr/lib/freetz/
├── libiconv.so.2.7.0    # Symlink → /mod/external/usr/lib/freetz/libiconv.so.2.7.0
├── libiconv.so.2        # Symlink → /mod/external/usr/lib/freetz/libiconv.so.2
└── libiconv.so          # Symlink → /mod/external/usr/lib/freetz/libiconv.so
```

**Result**: Flash memory savings = library size (in this case, 1.2 MB)

### Externalization Paths

Libraries externalize to directories matching their original location:

| Original Location | External Storage Location |
|-------------------|---------------------------|
| `/usr/lib/` | `/mod/external/usr/lib/` |
| `/usr/lib/freetz/` | `/mod/external/usr/lib/freetz/` |

**Important**: Libraries in `/usr/lib/` externalize to `/mod/external/usr/lib/`, while libraries in `/usr/lib/freetz/` externalize to `/mod/external/usr/lib/freetz/`.

### Boot Order and External Dependencies

**Critical Issue**: External storage is mounted **after** core services start.

#### Boot Sequence
```
1. Mount filesystems (flash, tmpfs)
2. Start core services (e.g., Dropbear SSH server)
   ├─ Dropbear reads libraries from /usr/lib/freetz/
   └─ External storage NOT YET MOUNTED
3. Mount external storage (/mod/external)
4. Start external services (from /mod/etc/external.pkg)
```

**Problem Example**: If `libz.so.1` (required by Dropbear) is externalized:
- Dropbear tries to start at step 2
- `libz.so.1` is not yet available (external storage not mounted)
- Dropbear **fails with segmentation fault**

#### Solution: external.pkg

Services depending on externalized libraries must be listed in `/mod/etc/external.pkg`:

```bash
# /mod/etc/external.pkg
dropbear
sshd
```

Services listed in `external.pkg`:
- Are **NOT started** at step 2
- Are started at step 4 (after external storage is mounted)
- Can safely use externalized libraries

**Example Configuration**:
```bash
# If you externalize libz, add Dropbear to external.pkg
ssh root@192.168.178.1
echo "dropbear" >> /mod/etc/external.pkg
```

### Configuring Externalization

Externalization is configured in `make menuconfig`:

```
Advanced options → External → [package name]
```

Example for PHP:
```
Advanced options → External → php → PHP dependency libraries
```

---

## Best Practices for Package Developers

### 1. Choosing Library Location

**Decision Flow:**
```
Does AVM firmware have this library?
├─ NO → Use /usr/lib/
│         Example: libcurl, libssl, libsqlite
└─ YES → Does version conflict exist?
		  ├─ NO → Can use /usr/lib/
		  └─ YES → MUST use /usr/lib/freetz/
				   Example: libz, libiconv
```

### 2. Package Configuration

#### For packages using `/usr/lib/` (no conflicts)
```makefile
$(call PKG_INIT_BIN, 1.2.3)
$(PKG)_DEPENDS_ON += openssl

# Libraries installed to /usr/lib/ automatically
```

#### For packages using `/usr/lib/freetz/` (with conflicts)
```makefile
$(call PKG_INIT_BIN, 1.2.3)
$(PKG)_DEPENDS_ON += zlib

# Ensure FREETZ_SEPARATE_AVM_UCLIBC is enabled
# Libraries installed to /usr/lib/freetz/
```

### 3. Library Dependencies

When adding library dependencies, use `select` statements in `Config.in`:

```kconfig
config FREETZ_PACKAGE_MYPACKAGE
	bool "mypackage"
	select FREETZ_LIB_libz         # Select library
	select FREETZ_LIB_libiconv     # Select library
	default n
	help
		My package description.
```

### 4. RPATH Configuration

Most packages inherit RPATH automatically from Freetz build system. If manual configuration is needed:

```makefile
# RPATH is automatically set by TARGET_CFLAGS_LD
# For special cases, use:
$(PKG)_LDFLAGS := -Wl,-rpath,$(FREETZ_LIBRARY_DIR)
```

---

## External Configuration Guidelines

### Creating external.in Files

Library externalization is configured in `external.in` files:

```
make/libs/LIBRARY_NAME/external.in      # For individual libraries
make/pkgs/PACKAGE_NAME/external.in      # For package libraries
```

### Alphabetical Ordering

**Important**: List libraries in **alphabetical order** in `external.in` files for:
- Easier maintenance
- Better readability
- Consistent structure across packages

**Example: PHP library externalization** (`make/pkgs/php/external.in`)

```kconfig
config EXTERNAL_FREETZ_PACKAGE_PHP
	depends on EXTERNAL_ENABLED && FREETZ_PACKAGE_PHP
	bool "php (binaries only)"
	default n
	help
		Externalizes PHP binaries only (php, php-cgi).
		Libraries remain in firmware for faster boot.

menu "PHP dependency libraries"
	depends on EXTERNAL_FREETZ_PACKAGE_PHP

config EXTERNAL_FREETZ_PACKAGE_PHP_LIBS
	bool "Externalize all PHP dependency libraries"
	default n
	select EXTERNAL_FREETZ_LIB_libgcc_s      if FREETZ_LIB_libgcc_s
	select EXTERNAL_FREETZ_LIB_libiconv      if FREETZ_LIB_libiconv
	select EXTERNAL_FREETZ_LIB_libintl       if FREETZ_LIB_libintl
	select EXTERNAL_FREETZ_LIB_libonig       if FREETZ_LIB_libonig
	select EXTERNAL_FREETZ_LIB_libpcre2      if FREETZ_LIB_libpcre2
	select EXTERNAL_FREETZ_LIB_libstdcxx     if FREETZ_LIB_libstdcxx
	select EXTERNAL_FREETZ_LIB_libxml2       if FREETZ_LIB_libxml2
	select EXTERNAL_FREETZ_LIB_libz          if FREETZ_LIB_libz
	help
		Externalizes all PHP dependency libraries.
		Saves ~4 MB flash but requires external storage.

if !EXTERNAL_FREETZ_PACKAGE_PHP_LIBS
	# Listed alphabetically
	config EXTERNAL_FREETZ_LIB_libgcc_s
		depends on FREETZ_LIB_libgcc_s
		bool "libgcc_s (~112 KB)"
		default n
	
	config EXTERNAL_FREETZ_LIB_libiconv
		depends on FREETZ_LIB_libiconv
		bool "libiconv (~1.2 MB)"
		default n
	
	config EXTERNAL_FREETZ_LIB_libintl
		depends on FREETZ_LIB_libintl
		bool "libintl (~110 KB)"
		default n
	
	config EXTERNAL_FREETZ_LIB_libonig
		depends on FREETZ_LIB_libonig
		bool "libonig (~600 KB)"
		default n
	
	config EXTERNAL_FREETZ_LIB_libpcre2
		depends on FREETZ_LIB_libpcre2
		bool "libpcre2 (~600 KB)"
		default n
	
	config EXTERNAL_FREETZ_LIB_libstdcxx
		depends on FREETZ_LIB_libstdcxx
		bool "libstdc++ (~2.7 MB)"
		default n
	
	config EXTERNAL_FREETZ_LIB_libxml2
		depends on FREETZ_LIB_libxml2
		bool "libxml2 (~1.5 MB)"
		default n
	
	config EXTERNAL_FREETZ_LIB_libz
		depends on FREETZ_LIB_libz
		bool "libz (~80 KB)"
		default n
		help
			WARNING: Dropbear SSH requires libz at boot time.
			If externalized, add dropbear to /mod/etc/external.pkg
endif

endmenu
```

### Key Configuration Principles

1. **Default to NOT externalize** (`default n`)
   - Libraries in firmware provide faster boot
   - Avoids boot dependency issues
   - External storage may not always be available

2. **Provide bulk option** for convenience
   - One option to externalize all libraries
   - Individual options when bulk is disabled

3. **Include size information** in descriptions
   - Helps users make informed decisions
   - Format: `"library_name (~size)"`

4. **Document boot dependencies**
   - Warn about services requiring libraries at boot
   - Example: Dropbear needs libz

5. **Alphabetical ordering**
   - Both in `select` statements
   - And in individual config blocks

### Creating external.files

Companion file to `external.in` that lists actual files to externalize:

```bash
# make/libs/iconv/external.files
[ "$EXTERNAL_FREETZ_LIB_libiconv" == "y" ] && EXTERNAL_FILES+=" ${FREETZ_LIBRARY_DIR}/libiconv.so.2.7.0"
```

**Important**:
- Use `${FREETZ_LIBRARY_DIR}` variable (expands to `/usr/lib/freetz/` or `/usr/lib/`)
- List **versioned files only** (symlinks created automatically)
- Match version exactly (e.g., `2.7.0` not `2.5.0`)

---

## Summary

### Key Takeaways

1. **AVM uses MUSL** in `/lib/`, **Freetz uses uClibc** in `/usr/lib/freetz/`
2. **Complete separation** via RPATH ensures zero conflicts
3. **Use `/usr/lib/`** for new libraries, **use `/usr/lib/freetz/`** for conflicting libraries
4. **Never duplicate** a library in both `/usr/lib/` and `/usr/lib/freetz/`
5. **Externalization saves flash** but requires careful boot dependency management
6. **Alphabetize external.in** configurations for maintainability
7. **Document boot dependencies** (e.g., Dropbear + libz)

### Quick Reference

| Scenario | Library Location | Example |
|----------|-----------------|---------|
| New library (no AVM conflict) | `/usr/lib/` | libssl, libcurl |
| Conflicting library | `/usr/lib/freetz/` | libz, libc, libgcc_s |
| Externalized `/usr/lib/` library | `/mod/external/usr/lib/` | libssl externalized |
| Externalized `/usr/lib/freetz/` library | `/mod/external/usr/lib/freetz/` | libz externalized |

### Configuration Quick Start

```bash
# Enable library separation
make menuconfig
  → Advanced options
	→ Toolchain options
	  → [x] Separate uClibc

# Configure externalization
make menuconfig
  → Advanced options
	→ External
	  → [package/library name]
```

---

## Additional Resources

- **External Documentation**: `docs/wiki/20_Advanced/external.md`
- **Package Development**: `docs/make/CODING_GUIDE_gcc-python3.md`
- **Build System**: `make/pkgs/Makefile.in`
- **Example Configurations**: `make/pkgs/php/external.in`, `make/libs/*/external.in`

-----

# Library Version Selection in Freetz-NG

## Overview

Freetz-NG supports **version selection** for certain libraries to maintain backward compatibility with older devices and applications. Users can choose between:

- **ABANDON version**: Older, stable version (usually for older uClibc toolchains and older devices)
- **CURRENT version**: Latest, updated version (recommended for newer devices)

This mechanism allows building firmware that remains compatible with legacy applications compiled against older library versions.

## When to Use Version Selection

### Use ABANDON version when:
- Building for older devices with limited resources
- Need compatibility with existing binaries compiled against older library versions
- Using older uClibc toolchains (0.9.28 or 0.9.29)
- Targeting FRITZ!Box devices with old kernels (kernel 2.x)

### Use CURRENT version when:
- Building for newer devices
- Want latest features and security fixes
- Using modern toolchains
- No legacy compatibility requirements

## Libraries Supporting Version Selection

### 1. **libiconv / iconv**

**Configuration**: `FREETZ_LIB_libiconv_WITH_VERSION_ABANDON`

| Version | Package | Library Version | Use Case |
|---------|---------|----------------|----------|
| ABANDON | 1.13.1  | 2.5.0          | uClibc 0.9.28/0.9.29, older devices |
| CURRENT | 1.18    | 2.7.0          | Modern toolchains, newer devices |

**Files Modified**:
- `make/libs/libiconv/Config.in` - Version selection menu
- `make/libs/libiconv/libiconv.mk` - Makefile with version logic
- `make/pkgs/iconv/Config.in` - Package version selection
- `make/pkgs/iconv/iconv.mk` - Package makefile with version logic

**What Changed**:
- Package version: 1.13.1 → 1.18
- Library version: 2.5.0 → 2.7.0

**Impact**: Applications linked against `libiconv.so.2.5.0` will fail if only version 2.7.0 is present. Use ABANDON to maintain compatibility.

---

### 2. **libsqlite3 / sqlite**

**Configuration**: `FREETZ_LIB_libsqlite3_WITH_VERSION_ABANDON`

| Version | Package | Library Version | Use Case |
|---------|---------|----------------|----------|
| ABANDON | 3.40.1  | 0.8.6          | uClibc 0.9.28/0.9.29, older applications |
| CURRENT | 3.50.4  | 3.50.4         | Modern systems |

**Files Modified**:
- `make/pkgs/sqlite/Config.in` - Version selection menu (already existed)
- `make/pkgs/sqlite/sqlite.mk` - **FIXED** to properly handle both LIB_VERSIONs

**What Changed**:
- Package version: 3.47.1 → 3.50.4 (CURRENT only)
- Library version: 0.8.6 → 3.50.4 **(CRITICAL CHANGE)**

**Critical Fix Applied**:
Previous implementation had a bug where both ABANDON and CURRENT versions used the same `LIB_VERSION`. Fixed by implementing:
```makefile
$(PKG)_LIB_VERSION_ABANDON:=0.8.6
$(PKG)_LIB_VERSION_CURRENT:=3.50.4
$(PKG)_LIB_VERSION:=$($(PKG)_LIB_VERSION_$(if $(FREETZ_LIB_libsqlite3_WITH_VERSION_ABANDON),ABANDON,CURRENT))
```

**Impact**: Applications linked against `libsqlite3.so.0.8.6` would fail with new version. ABANDON version now correctly provides the old library version.

---

### 3. **libreadline / readline**

**Configuration**: `FREETZ_LIB_libreadline_VERSION_ABANDON`

| Version | Library Version | Use Case |
|---------|----------------|----------|
| ABANDON | 6.3  | Kernel 2.x devices only |
| CURRENT | 8.3  | Modern kernels |

**Constraint**: ABANDON version only available on `FREETZ_KERNEL_VERSION_2_MAX`

---

### 4. **libusb-1.0 / libusb1**

**Configuration**: `FREETZ_LIB_libusb_1_WITH_ABANDON`

| Version | Library Version | Use Case |
|---------|----------------|----------|
| ABANDON | 1.0.23 | GCC 4.x or Kernel 2.x |
| CURRENT | 1.0.29 | Modern toolchains |

**Constraint**: ABANDON version auto-selected for `FREETZ_TARGET_GCC_4_MAX || FREETZ_KERNEL_VERSION_2_MAX`

---

### 5. **liblua / lua**

**Configuration**: `FREETZ_LIB_liblua_WITH_VERSION_ABANDON`

| Version | Use Case |
|---------|----------|
| ABANDON | 5.1.5 | Legacy compatibility |
| CURRENT | 5.4.8 | Modern Lua features |

---

## How Version Selection Works

### Makefile Implementation Pattern

```makefile
# Define package version based on config
$(call PKG_INIT_BIN, $(if $(FREETZ_LIB_libfoo_WITH_VERSION_ABANDON),OLD_VERSION,NEW_VERSION))

# Define library versions
$(PKG)_LIB_VERSION_ABANDON:=OLD_LIB_VERSION
$(PKG)_LIB_VERSION_CURRENT:=NEW_LIB_VERSION
$(PKG)_LIB_VERSION:=$($(PKG)_LIB_VERSION_$(if $(FREETZ_LIB_libfoo_WITH_VERSION_ABANDON),ABANDON,CURRENT))

# Define source hashes
$(PKG)_HASH_ABANDON:=hash_of_old_version
$(PKG)_HASH_CURRENT:=hash_of_new_version
$(PKG)_HASH:=$($(PKG)_HASH_$(if $(FREETZ_LIB_libfoo_WITH_VERSION_ABANDON),ABANDON,CURRENT))

# Optional: Different download sites
$(PKG)_SITE_ABANDON:=old_mirror_url
$(PKG)_SITE_CURRENT:=new_mirror_url
$(PKG)_SITE:=$($(PKG)_SITE_$(if $(FREETZ_LIB_libfoo_WITH_VERSION_ABANDON),ABANDON,CURRENT))

# Conditional patches
$(PKG)_CONDITIONAL_PATCHES+=$(if $(FREETZ_LIB_libfoo_WITH_VERSION_ABANDON),abandon,current)
```

### Config.in Pattern

```kconfig
config FREETZ_LIB_libfoo
	bool "libfoo (libfoo.so)"
	default n
	help
		Library description.

if FREETZ_LIB_libfoo

	choice
		prompt "Version"
			default FREETZ_LIB_libfoo_WITH_VERSION_CURRENT

		config FREETZ_LIB_libfoo_WITH_VERSION_ABANDON
			bool "OLD_VERSION"
			depends on (constraints_for_old_version)

		config FREETZ_LIB_libfoo_WITH_VERSION_CURRENT
			bool "NEW_VERSION"
			depends on !(constraints_for_old_version)

	endchoice

endif # FREETZ_LIB_libfoo
```

## Library Versioning in Detail

### Understanding Shared Library Versioning

Shared libraries use **SONAME** versioning:

```
libfoo.so          → symlink to libfoo.so.X (used for linking)
libfoo.so.X        → symlink to libfoo.so.X.Y.Z (ABI compatibility)
libfoo.so.X.Y.Z    → actual library file (full version)
```

**Example for libiconv**:
```bash
# ABANDON version (2.5.0):
libiconv.so → libiconv.so.2 → libiconv.so.2.5.0

# CURRENT version (2.7.0):
libiconv.so → libiconv.so.2 → libiconv.so.2.7.0
```

**Key Point**: Both versions share the same **major version** (2), ensuring ABI compatibility. The minor/patch versions differ.

### Why This Matters

Applications are linked against the **full version** at build time:
```
ldd /usr/bin/some_app
	libiconv.so.2.5.0 => /usr/lib/freetz/libiconv.so.2.5.0
```

If firmware provides only `libiconv.so.2.7.0`, the application will fail:
```
error while loading shared libraries: libiconv.so.2.5.0: cannot open shared object file
```

**Solution**: Use ABANDON version to provide the exact library version the application expects.

## Configuration in menuconfig

```
Packages  --->
	Libraries  --->
		[*] Iconv (libiconv.so)  --->
			Version (2.7.0 (from libiconv 1.18))  --->
				( ) 2.5.0 (from libiconv 1.13.1)   # ABANDON
				(X) 2.7.0 (from libiconv 1.18)     # CURRENT

		[*] libsqlite (libsqlite3.so)  --->
			Version (3.50.4)  --->
				( ) 3.40.1   # ABANDON
				(X) 3.50.4   # CURRENT
```

## Automatic Version Selection

Some libraries **automatically select ABANDON version** based on toolchain constraints:

### libsqlite3
- **Auto-ABANDON**: When `FREETZ_TARGET_UCLIBC_0_9_28` or `FREETZ_TARGET_UCLIBC_0_9_29`
- **Reason**: Older uClibc versions need older sqlite3

### libiconv
- **Auto-ABANDON**: When `FREETZ_TARGET_UCLIBC_0_9_28` or `FREETZ_TARGET_UCLIBC_0_9_29`
- **Reason**: Older toolchains require older iconv

### libreadline
- **Auto-ABANDON**: When `FREETZ_KERNEL_VERSION_2_MAX`
- **Reason**: Old kernels only support readline 6.3

### libusb1
- **Auto-ABANDON**: When `FREETZ_TARGET_GCC_4_MAX` or `FREETZ_KERNEL_VERSION_2_MAX`
- **Reason**: Old toolchains/kernels need libusb 1.0.23

## Migration Guide

### Migrating from Single Version to Multi-Version

If you previously built firmware with the old version and now need to update:

1. **Check existing applications**:
   ```bash
   ssh root@192.168.178.1
   find /usr/lib/freetz -name "*.so*" -exec ldd {} \; | grep -i "libiconv\|sqlite"
   ```

2. **Identify required library versions**:
   - If apps need `libiconv.so.2.5.0` → use ABANDON
   - If apps need `libsqlite3.so.0.8.6` → use ABANDON

3. **Configure menuconfig**:
   - Select ABANDON versions for libraries used by existing apps
   - Select CURRENT versions for new builds without legacy requirements

4. **Rebuild firmware**:
   ```bash
   make dirclean
   make menuconfig  # Select appropriate versions
   make
   ```

### Updating Existing Devices

**Scenario**: Device has old applications expecting old library versions

**Solution**:
1. Build new firmware with **ABANDON versions** selected
2. Flash firmware - old apps continue working
3. Gradually update applications to newer versions
4. Once all apps updated, rebuild with **CURRENT versions**

## Implementation Changes Summary

### Changes Made in This Branch

| Library | Files Modified | What Changed |
|---------|---------------|--------------|
| **iconv/libiconv** | `make/pkgs/iconv/Config.in`<br>`make/pkgs/iconv/iconv.mk`<br>`make/libs/libiconv/Config.in`<br>`make/libs/libiconv/libiconv.mk` | Added version selection: 1.13.1 (ABANDON) vs 1.18 (CURRENT)<br>Library versions: 2.5.0 vs 2.7.0 |
| **sqlite3** | `make/pkgs/sqlite/sqlite.mk` | **FIXED** LIB_VERSION to differentiate: 0.8.6 (ABANDON) vs 3.50.4 (CURRENT) |

### Total Changes
- **5 files modified**
- **57 lines added**, 9 lines removed
- **2 libraries** now properly support version selection

## Best Practices

1. **Default to CURRENT**: Unless you have specific compatibility requirements, use CURRENT versions for latest features and security fixes.

2. **Test Both Versions**: When developing packages, test with both ABANDON and CURRENT to ensure compatibility.

3. **Document Dependencies**: If your package requires specific library versions, document in `Config.in` help text.

4. **Use Conditional Patches**: Store version-specific patches in separate directories:
   ```
   make/pkgs/foo/patches/
   ├── abandon/
   │   └── 100-old-fix.patch
   └── current/
	   └── 100-new-fix.patch
   ```

5. **Verify ABI Compatibility**: When adding new library versions, ensure the major version number is appropriate for ABI compatibility.

## Troubleshooting

### Build Fails with "Hash Mismatch"

**Cause**: Wrong hash for selected version

**Solution**: Verify `$(PKG)_HASH_ABANDON` and `$(PKG)_HASH_CURRENT` in `.mk` file

### Application Fails with "cannot open shared object file"

**Cause**: Application expects different library version

**Solution**: 
1. Check which version app needs: `ldd /path/to/app`
2. Select matching ABANDON/CURRENT version in menuconfig
3. Rebuild firmware

### Both Versions Selected in menuconfig

**Cause**: Configuration conflict

**Solution**: Run `make menuconfig` and ensure only ONE version is selected per library

## Future Work

### Additional Libraries to Consider

Other libraries that might benefit from version selection:

- **libcurl**: Often has compatibility issues between versions
- **openssl**: Critical for security, but major version changes break compatibility
- **ncurses**: Terminal library with ABI changes between versions
- **zlib**: Compression library sometimes has version-specific behavior

### Automated Testing

Consider implementing automated tests to verify:
- Both versions build successfully
- Correct library versions are installed
- No symlink conflicts
- ABI compatibility is maintained

## References

- [Shared Library Versioning](https://tldp.org/HOWTO/Program-Library-HOWTO/shared-libraries.html)
- [ABI Compatibility](https://www.akkadia.org/drepper/dsohowto.pdf)
- [GNU Libtool Versioning](https://www.gnu.org/software/libtool/manual/html_node/Libtool-versioning.html)

---

# Meson Cross-Compilation Configuration

## Overview

Freetz-NG supports **Meson build system** for cross-compiling packages to MIPS/ARM targets. Meson requires a **cross-compilation file** that describes the target environment, toolchain paths, and system properties.

## Cross-Compilation File Structure

Cross-compilation files are located in `include/meson.cross/` directory with the naming pattern:

```
meson-cross-ARCH-ENDIAN.conf
```

**Examples:**
- `meson-cross-mips-be.conf` - MIPS Big-Endian
- `meson-cross-mips-le.conf` - MIPS Little-Endian  
- `meson-cross-arm-le.conf` - ARM Little-Endian

## File Format

### [binaries] Section

Defines toolchain executables:

```ini
[binaries]
c = '/path/to/gcc'
cpp = '/path/to/g++'
ar = '/path/to/ar'
strip = '/path/to/strip'
pkgconfig = '/path/to/pkg-config'
```

### [properties] Section

**CRITICAL**: Must appear **exactly once** in the file!

Defines target-specific properties:

```ini
[properties]
sys_root = '/path/to/sysroot'
pkg_config_libdir = '/path/to/pkgconfig'
```

### [host_machine] Section

Describes the target architecture:

```ini
[host_machine]
system = 'linux'
cpu_family = 'mips'
cpu = '24kc'
endian = 'big'       # or 'little'
```

**Important Endianness Values:**
- Use `'big'` for big-endian (NOT `'BIG'`)
- Use `'little'` for little-endian (NOT `'LITTLE'`)

## Common Issues and Solutions

### Problem: Duplicate [properties] Section

**Symptom:**
```
meson.build:1:0: ERROR: Only one [properties] section may exist
```

**Cause:** Configuration file has `[properties]` section defined multiple times

**Solution:** Ensure **exactly ONE** `[properties]` section in the cross-file:

```ini
# WRONG - Two [properties] sections
[properties]
sys_root = '/path1'

[properties]
pkg_config_libdir = '/path2'

# CORRECT - Single [properties] section
[properties]
sys_root = '/path1'
pkg_config_libdir = '/path2'
```

### Problem: Wrong Endianness Placeholder

**Symptom:**
```
meson.build:1:0: ERROR: Unknown value 'BIG' for endian
```

**Cause:** Using uppercase placeholders `BIG`/`LITTLE` instead of lowercase values

**Solution:** Use correct values in meson.cross file generation:

```makefile
# WRONG - Uses uppercase
sed 's|@ENDIAN@|BIG|g' template.conf

# CORRECT - Uses lowercase
sed 's|@ENDIAN@|big|g' template.conf
# Or for little-endian:
sed 's|@ENDIAN@|little|g' template.conf
```

### Problem: Unrecognized Configure Options

**Symptom:**
```
configure: WARNING: unrecognized options: --with-tree, --disable-nls
```

**Cause:** Using configure options that don't exist in the library version being built

**Solution:** Verify available options before using them:

```bash
# Check what options are available
cd source/target-ARCH/PACKAGE-VERSION
./configure --help | grep "with-tree\|disable-nls"

# Only use options that actually exist
```

**Example - libxml2 2.15.x:**
```makefile
# These options NO LONGER EXIST in 2.15.x:
--with-tree        # Removed (tree API always included)
--with-lzma        # Removed  
--disable-nls      # Removed

# These options STILL EXIST:
--with-html        # HTML support
--with-relaxng     # Relax-NG schemas
```

## Makefile Integration

### Generating Cross-File

Typical pattern in package makefiles:

```makefile
$(PKG)_MESON_CROSS_FILE := $(TARGET_TOOLCHAIN_STAGING_DIR)/meson-cross.conf

$($(PKG)_DIR)/.configured: $($(PKG)_DIR)/.unpacked
	# Generate cross-file from template
	sed -e 's|@CC@|$(TARGET_CC)|g' \
	    -e 's|@CXX@|$(TARGET_CXX)|g' \
	    -e 's|@AR@|$(TARGET_AR)|g' \
	    -e 's|@STRIP@|$(TARGET_STRIP)|g' \
	    -e 's|@ENDIAN@|$(FREETZ_TARGET_ENDIANNESS_DEPENDENT)|g' \
	    -e 's|@SYSROOT@|$(TARGET_TOOLCHAIN_SYSROOT)|g' \
	    include/meson.cross/template.conf > $(PKG_MESON_CROSS_FILE)
	
	# Run meson setup
	cd $($(PKG)_DIR) && \
	meson setup builddir \
		--cross-file=$(PKG_MESON_CROSS_FILE) \
		--prefix=/usr \
		$(PKG_MESON_OPTIONS)
	touch $@
```

### Build Pattern

```makefile
$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	ninja -C $($(PKG)_DIR)/builddir
```

## Best Practices

1. **Use Template Files**: Store meson cross-file templates in `include/meson.cross/` with placeholders

2. **Validate Options**: Always check `./configure --help` or `meson configure` output before adding options

3. **Test Both Endianness**: If supporting both BE/LE, test both configurations

4. **Document Requirements**: Add meson version requirements to `Config.in` if needed:
   ```kconfig
   config FREETZ_PACKAGE_FOO
       bool "foo"
       depends on FREETZ_HOSTTOOLS_MESON_VERSION_MIN_0_61
   ```

5. **Clean on Reconfig**: Meson caches configuration, always clean when changing options:
   ```makefile
   $(pkg)-dirclean:
       $(RM) -r $($(PKG)_DIR)/builddir
   ```

## Testing Meson Packages

```bash
# 1. Clean previous build
make PACKAGE-dirclean

# 2. Build with verbose output
make PACKAGE-precompiled V=1

# 3. Check generated cross-file
cat toolchain/.../meson-cross.conf

# 4. Verify endianness is correct
grep "endian" toolchain/.../meson-cross.conf
# Should show: endian = 'big' OR endian = 'little'
```

## Meson vs Autotools

| Feature | Meson | Autotools |
|---------|-------|-----------|
| **Cross-file** | Required | Optional |
| **Configuration** | `meson setup` | `./configure` |
| **Build** | `ninja` | `make` |
| **Out-of-tree** | Always | Optional |
| **Speed** | Faster | Slower |
| **Reconfigure** | Cached | From scratch |

## Common Meson Options

```makefile
# Installation paths
-Dprefix=/usr
-Dlibdir=lib
-Dbindir=bin

# Build type
-Dbuildtype=release
-Doptimization=2
-Ddebug=false

# Features (library-specific)
-Denable-feature=true
-Dwith-backend=system
```

## Troubleshooting Meson Builds

### Build fails with "cross file not found"

**Solution**: Ensure cross-file is generated before meson setup:

```makefile
$(PKG_MESON_CROSS_FILE): $(TARGET_TOOLCHAIN_STAGING_DIR)/.installed
	# Generate cross-file here
	touch $@

$($(PKG)_DIR)/.configured: $(PKG_MESON_CROSS_FILE)
	meson setup ...
```

### Configuration changes not applied

**Solution**: Meson caches configuration. Force reconfigure:

```bash
make PACKAGE-dirclean
make PACKAGE-precompiled
```

Or use meson reconfigure:

```bash
cd source/.../PACKAGE/builddir
meson configure -Doption=value
ninja
```

### Wrong architecture detected

**Solution**: Verify `[host_machine]` section in cross-file matches your target.

---

# Patch Management Best Practices

## Overview

This section covers advanced patch management techniques discovered during Freetz-NG development, particularly for handling patches across different package versions.

## Patch Organization Strategies

### Strategy 1: Old Patch Directory

When updating a package to a new version where old patches no longer apply:

**Directory Structure:**
```
make/pkgs/PACKAGE/patches/
├── old/                    # Archive for obsolete patches
│   ├── 010-fix.patch      # Was for version 1.x
│   └── 020-another.patch
└── 100-current.patch       # For version 2.x
```

**When to Use:**
- Updating to a new upstream version
- Old patches were integrated upstream
- Want to keep patch history for reference

**Example - ldd package:**
```
make/pkgs/ldd/patches/
└── old/
    ├── 010-open_3rd_param.upstream.patch    # Fixed in ldd 1.0.55
    ├── 020-lib_segfault.upstream.patch      # Fixed in ldd 1.0.55
    ├── 030-null-check.upstream.patch        # Fixed in ldd 1.0.55
    └── 100-fix-byteswap32_to_host.patch     # Fixed in ldd 1.0.55
```

### Strategy 2: Conditional Patches by Version

For packages with version selection (ABANDON vs CURRENT):

**Directory Structure:**
```
make/pkgs/PACKAGE/patches/
├── abandon/               # Patches for ABANDON version
│   └── 100-old-fix.patch
└── current/               # Patches for CURRENT version
    └── 100-new-fix.patch
```

**Makefile Integration:**
```makefile
# Conditional patch directory
$(PKG)_CONDITIONAL_PATCHES+=$(if $(FREETZ_PACKAGE_FOO_VERSION_ABANDON),abandon,current)
```

**When to Use:**
- Package supports multiple versions
- Patches differ significantly between versions
- Need to maintain both versions actively

### Strategy 3: Numbered Patch Series

Use consistent numbering for patch series:

```
000-099: Upstream patches (will be integrated)
100-199: Build system fixes
200-299: Feature patches
300-399: Cross-compilation fixes
400-499: Freetz-specific modifications
500-599: Security patches
900-999: Temporary workarounds
```

**Example:**
```
010-fix-typo.upstream.patch           # Will go upstream
100-disable-tests.patch               # Build system
250-add-feature-x.patch               # New feature
310-fix-mips-compilation.patch        # Cross-compile fix
450-freetz-config-paths.patch         # Freetz paths
510-CVE-2024-XXXXX.patch             # Security
950-workaround-gcc-bug.patch          # Temporary
```

## Documenting Patch Status

### Patch Headers

Include comprehensive metadata in patch headers:

```patch
Description: Fix buffer overflow in parse_input()
Bug: https://github.com/upstream/project/issues/123
Forwarded: yes
Author: Your Name <your@email.com>
Last-Update: 2025-10-21

This patch fixes a buffer overflow that occurs when processing
inputs larger than 4096 bytes. The fix adds bounds checking.

--- a/src/parser.c
+++ b/src/parser.c
@@ -42,6 +42,8 @@
 void parse_input(char *input) {
     char buffer[4096];
+    if (strlen(input) >= sizeof(buffer))
+        return -1;
     strcpy(buffer, input);
 }
```

### Patch Status Markers

Use filename suffixes to indicate patch status:

```
010-fix.upstream.patch       # Submitted/accepted upstream
020-fix.pending.patch        # Submitted, awaiting review
030-fix.freetz.patch         # Freetz-specific, won't go upstream
040-fix.temporary.patch      # Workaround, will be removed
```

## Verifying Patches Still Needed

Before updating a package, check if patches are still required:

### Method 1: Manual Source Inspection

```bash
# Extract new version
cd source/target-ARCH/PACKAGE-NEW-VERSION

# Check if patch is already applied
grep -r "fix_content" .
# If found → patch no longer needed

# Check specific function/line mentioned in patch
vim src/file.c
# Search for the function/code being patched
```

### Method 2: Attempt Patch Application

```bash
# Try applying old patch
cd source/target-ARCH/PACKAGE-NEW-VERSION
patch -p1 --dry-run < ../../../make/pkgs/PACKAGE/patches/010-fix.patch

# Results:
# - "Reversed (or previously applied) patch detected" → No longer needed
# - "Hunk #1 succeeded" → Still needed
# - "Hunk #1 FAILED" → Needs updating
```

### Method 3: Check Upstream Changelog

```bash
# Review upstream changes
cat CHANGELOG.md | grep -A5 "version NEW_VERSION"
cat NEWS | grep "fix\|bug"
git log OLD_VERSION..NEW_VERSION
```

## Updating Patches for New Versions

### When Patch Conflicts

**Symptom:**
```
Hunk #1 FAILED at 248.
1 out of 1 hunk FAILED -- saving rejects to file.c.rej
```

**Solution Process:**

1. **Check .rej file:**
   ```bash
   cat file.c.rej
   # Shows what couldn't be applied
   ```

2. **Find new location:**
   ```bash
   # Old patch tried to modify line 248
   # Search for similar context
   grep -n "function_name\|unique_string" file.c
   ```

3. **Regenerate patch:**
   ```bash
   # Make changes manually
   vim file.c
   
   # Create new patch
   diff -Naur original/file.c modified/file.c > new-patch.patch
   ```

4. **Test new patch:**
   ```bash
   make PACKAGE-dirclean
   make PACKAGE-precompiled
   ```

### Rebasing Patch Series

When updating package version:

```bash
# 1. Apply all old patches manually
cd source/target-ARCH/NEW-VERSION
for patch in ../../../../make/pkgs/PACKAGE/patches/*.patch; do
    patch -p1 < "$patch" || echo "FAILED: $patch"
done

# 2. For failed patches, fix manually

# 3. Regenerate patch series
git init
git add -A
git commit -m "Baseline"

# Make changes
vim file.c
git add file.c
git commit -m "Fix: description"

# Generate new patches
git format-patch -1
mv 0001-Fix-description.patch ../../../../make/pkgs/PACKAGE/patches/100-fix.patch
```

## Common Patch Mistakes

### Mistake 1: Overly Broad Patches

**Wrong:**
```patch
diff -Naur original modified
# Includes .gitignore, Makefile.in, config.h changes
# 500+ lines of auto-generated cruft
```

**Right:**
```patch
diff -Naur original/src/main.c modified/src/main.c
# Only the specific file that needs changing
# 10 lines, clear purpose
```

**Solution:** Use `--path=` or manually specify files:
```bash
svn diff src/main.c > fix.patch  # SVN
git diff -- src/main.c > fix.patch  # Git
```

### Mistake 2: Including Binary Files

**Wrong:**
```patch
diff -Naur original/logo.png modified/logo.png
Binary files differ
```

**Right:** Don't include binary files in patches. If needed, place them in `make/pkgs/PACKAGE/files/` directory.

### Mistake 3: Absolute Paths in Patches

**Wrong:**
```patch
--- /home/user/freetz/source/package/file.c
+++ /home/user/freetz/source/package/file.c
```

**Right:**
```patch
--- original/file.c
+++ modified/file.c
```

Or better (patch -p1 style):
```patch
--- a/file.c
+++ b/file.c
```

### Mistake 4: No Context Lines

**Wrong:**
```patch
@@ -42 +42 @@
-    old line
+    new line
```

**Right:** Include 3+ context lines before and after:
```patch
@@ -40,7 +40,7 @@
     context line 1
     context line 2
     context line 3
-    old line
+    new line
     context line 4
     context line 5
     context line 6
```

## Tools for Patch Management

### quilt

```bash
# Initialize quilt for package
cd source/target-ARCH/PACKAGE
export QUILT_PATCHES=../../../../make/pkgs/PACKAGE/patches
quilt push -a  # Apply all patches

# Make changes
quilt new 100-myfix.patch
quilt add src/file.c
vim src/file.c
quilt refresh

# Generate patch
quilt header -e  # Add description
```

### git format-patch

```bash
# Work with git
cd source/target-ARCH/PACKAGE
git init
git add -A && git commit -m "Baseline"

# Make changes in commits
vim file.c && git commit -am "Fix bug X"
vim file2.c && git commit -am "Add feature Y"

# Generate patches
git format-patch -2  # Last 2 commits
# Creates: 0001-Fix-bug-X.patch, 0002-Add-feature-Y.patch

# Rename to Freetz convention
mv 0001-*.patch ../../../../make/pkgs/PACKAGE/patches/100-fix.patch
mv 0002-*.patch ../../../../make/pkgs/PACKAGE/patches/200-feature.patch
```

## Patch Testing Checklist

Before committing patches:

- [ ] Patch applies cleanly: `make PACKAGE-dirclean && make PACKAGE-source`
- [ ] Build succeeds: `make PACKAGE-precompiled`
- [ ] Runtime tested: Install on device, test functionality
- [ ] Patch header complete: Description, author, upstream status
- [ ] File paths relative: No absolute paths in patch
- [ ] Minimal changes: Only necessary modifications
- [ ] Context lines included: 3+ lines before/after
- [ ] Forwarded upstream: If generally useful
- [ ] Documented in commit: Why patch is needed

---

# Archive Directory Name Mismatches

## Problem Description

A common issue when packaging software is that the **archive filename** doesn't match the **directory name** after extraction.

**Example:**
```bash
# Archive name
zip30.tar.gz

# Directory after extraction
zip30/       # NOT zip-3.0/
```

This causes make to fail because it looks for `source/target-ARCH/zip-3.0/` but finds `source/target-ARCH/zip30/`.

## Symptoms

```
make: *** No rule to make target 'source/target-mips/zip-3.0/.unpacked'
ERROR: Directory not found: source/target-mips/zip-3.0
```

Or:

```
tar: cannot open source/target-mips/zip-3.0: No such file or directory
```

## Root Cause

Default Freetz-NG naming assumes:
```makefile
$(PKG)_VERSION := 3.0
$(PKG)_SOURCE := $(pkg)-$($(PKG)_VERSION).tar.gz  # "zip-3.0.tar.gz"
$(PKG)_DIR := $($(PKG)_SOURCE_DIR)/$(pkg)-$($(PKG)_VERSION)  # "zip-3.0"
```

But upstream provides:
- Archive: `zip30.tar.gz` (no hyphen!)
- Directory: `zip30/` (version embedded, no hyphen!)

## Solution: Override $(PKG)_DIR and $(PKG)_SOURCE

```makefile
$(call PKG_INIT_BIN, 3.0)

# Custom source filename
$(PKG)_SOURCE:=zip30.tar.gz
$(PKG)_HASH:=<sha256>
$(PKG)_SITE:=https://downloads.sourceforge.net/infozip

# Override directory name to match actual extracted directory
$(PKG)_SOURCE_DIR:=$(SOURCE_DIR)/$(PKG_LANG)
$(PKG)_DIR:=$($(PKG)_SOURCE_DIR)/zip30  # Match actual extracted directory name!

### WEBSITE:=https://infozip.sourceforge.net/Zip.html
### SUPPORT:=YourUsername

# Now all variables reference the correct directory
$(PKG)_BINARY_BUILD := $(ZIP_DIR)/zip
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/zip
```

**Key Points:**
1. Set `$(PKG)_SOURCE` to exact filename: `zip30.tar.gz`
2. Override `$(PKG)_DIR` to match extracted directory: `zip30`
3. Use direct variable names (`ZIP_DIR`) in recipes, NOT nested variables (`$($(PKG)_DIR)`)

## Common Patterns

### Pattern 1: Version Embedded (No Separator)

```makefile
# Example: zip30, p7zip_16.02
$(PKG)_VERSION := 3.0
$(PKG)_SOURCE := zip$(subst .,,$($(PKG)_VERSION)).tar.gz  # "zip30.tar.gz"
$(PKG)_DIR := $($(PKG)_SOURCE_DIR)/zip$(subst .,,$($(PKG)_VERSION))  # "zip30"
```

### Pattern 2: Different Separator

```makefile
# Example: package_1.2.3 instead of package-1.2.3
$(PKG)_VERSION := 1.2.3
$(PKG)_SOURCE := $(pkg)_$($(PKG)_VERSION).tar.gz  # "package_1.2.3.tar.gz"
$(PKG)_DIR := $($(PKG)_SOURCE_DIR)/$(pkg)_$($(PKG)_VERSION)  # "package_1.2.3"
```

### Pattern 3: Project Name Differs

```makefile
# Example: archive "foo-src-1.0.tar.gz" extracts to "foo-1.0/"
$(PKG)_VERSION := 1.0
$(PKG)_SOURCE := $(pkg)-src-$($(PKG)_VERSION).tar.gz  # "foo-src-1.0.tar.gz"
$(PKG)_DIR := $($(PKG)_SOURCE_DIR)/$(pkg)-$($(PKG)_VERSION)  # "foo-1.0"
```

### Pattern 4: Completely Custom Name

```makefile
# Example: archive "release-v1.0.tar.gz" extracts to "project-release-1.0/"
$(PKG)_VERSION := 1.0
$(PKG)_SOURCE := release-v$($(PKG)_VERSION).tar.gz
$(PKG)_DIR := $($(PKG)_SOURCE_DIR)/project-release-$($(PKG)_VERSION)
```

## Verification Steps

After setting `$(PKG)_DIR`, verify it's correct:

```bash
# 1. Download and extract manually
cd dl
wget <source_url>/archive.tar.gz
tar -tzf archive.tar.gz | head -1
# Shows: zip30/  (directory name in archive)

# 2. Test with make
make PACKAGE-source
ls source/target-ARCH/
# Should show the actual extracted directory

# 3. Verify makefile variables
make PACKAGE-show-vars | grep DIR
# Should show correct paths
```

## Advanced: Handling $(transform)

Some packages extract to a directory with `--strip-components`:

```makefile
# Archive contains: "projectname-1.0/src/..." 
# But we want: "projectname-1.0/..."

$(PKG_UNPACKED)
	mkdir -p $($(PKG)_DIR)
	$(call UNPACK_TARBALL,$(DL_DIR)/$($(PKG)_SOURCE),$($(PKG)_DIR),--transform='s|^[^/]*/||')
	$(call APPLY_PATCHES,$($(PKG)_MAKE_DIR)/patches,$($(PKG)_DIR))
	touch $@
```

## Complete Example: zip Package

```makefile
$(call PKG_INIT_BIN, 3.0)
$(PKG)_SOURCE:=zip30.tar.gz
$(PKG)_HASH:=f0e8bb1f9b7eb0b01285495a2699df3a4b766784c1765a8f1aeedf63c0806369
$(PKG)_SITE:=https://downloads.sourceforge.net/infozip

# CRITICAL: Override default directory name
$(PKG)_SOURCE_DIR:=$(SOURCE_DIR)/$(PKG_LANG)
$(PKG)_DIR:=$($(PKG)_SOURCE_DIR)/zip30  # Matches extracted directory!

### WEBSITE:=https://infozip.sourceforge.net/Zip.html
### SUPPORT:=Ircama

$(PKG)_BINARY_BUILD := $(ZIP_DIR)/zip
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/zip

$(PKG)_MAKE_OPTIONS += -f unix/Makefile
$(PKG)_MAKE_OPTIONS += CC="$(TARGET_CC)"
$(PKG)_MAKE_OPTIONS += CPP="$(TARGET_CC) -E"
$(PKG)_MAKE_OPTIONS += CFLAGS="$(TARGET_CFLAGS)"
$(PKG)_MAKE_OPTIONS += generic

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)

# No configure script - create marker manually
$(ZIP_DIR)/.configured: $(ZIP_DIR)/.unpacked
	touch $@

$(ZIP_BINARY_BUILD): $(ZIP_DIR)/.configured
	$(SUBMAKE) -C $(ZIP_DIR) $(ZIP_MAKE_OPTIONS)

$(ZIP_BINARY_TARGET): $(ZIP_BINARY_BUILD)
	$(INSTALL_BINARY_STRIP)

$(pkg):

$(pkg)-precompiled: $(ZIP_BINARY_TARGET)

$(pkg)-clean:
	-$(SUBMAKE) -C $(ZIP_DIR) $(ZIP_MAKE_OPTIONS) clean

$(pkg)-uninstall:
	$(RM) $(ZIP_BINARY_TARGET)

$(PKG_FINISH)
```

## Testing Archive Extraction

```bash
# Test extraction locally
cd /tmp
wget https://downloads.sourceforge.net/infozip/zip30.tar.gz
tar -xzf zip30.tar.gz
ls -la
# Output: zip30/  <- This is the directory name to use!

# Clean up
rm -rf zip30/ zip30.tar.gz
```

---

# Handling C++ Standard Library Requirements

## Problem: uClibc++ Limitations

**Background:** Freetz-NG uses **uClibc++**, a minimal C++ standard library designed for embedded systems. It **does NOT support**:

- C++11/14/17/20 features fully
- Modern STL containers (`unordered_map`, `unordered_set`)  
- Smart pointers (`shared_ptr`, `unique_ptr`, `weak_ptr`)
- Many `<algorithm>` functions
- Regular expressions (`<regex>`)
- Threading support (`<thread>`, `<mutex>`)

**Impact:** Many modern C++ programs fail to compile:

```
fatal error: unordered_map: No such file or directory
   27 | #include <unordered_map>
      |          ^~~~~~~~~~~~~~~
```

## Solutions for C++ Packages

### Solution 1: Use Older Package Version

Find a version that uses C++03 or basic C++11:

```makefile
# Example: patchelf
# Version 0.15+ requires C++17 (unordered_map)
# Version 0.9 uses C++03 (compatible with uClibc++)

$(call PKG_INIT_BIN, 0.9)  # Use old version
```

**How to Find Compatible Versions:**

1. **Check release notes/CHANGELOG:**
   ```bash
   git log --oneline --all | grep -i "c++\|require"
   ```

2. **Inspect source code:**
   ```bash
   git show v0.15:src/patchelf.cc | grep -o "#include <[^>]*>" | sort -u
   # Shows: unordered_map, memory, algorithm -> C++11+
   
   git show v0.9:src/patchelf.cc | grep -o "#include <[^>]*>" | sort -u
   # Shows: vector, string, iostream -> C++03 compatible
   ```

3. **Check configure.ac/CMakeLists.txt:**
   ```bash
   grep "CXX.*STANDARD\|std=c++" configure.ac CMakeLists.txt
   ```

### Solution 2: Compile as Host-Tool Only

If the tool isn't needed on the device, compile it as a **host-tool** instead:

```makefile
# make/host-tools/patchelf-host/patchelf-host.mk
$(call TOOLS_INIT, 0.18.0)
$(PKG)_SOURCE:=$(pkg)-$($(PKG)_VERSION).tar.bz2
$(PKG)_HASH:=...
$(PKG)_SITE:=https://github.com/NixOS/patchelf/releases/download/$($(PKG)_VERSION)
### WEBSITE:=https://github.com/NixOS/patchelf
### SUPPORT:=Ircama

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

# Host tools compile with system g++ (has full libstdc++)
$($(PKG)_DIR)/.compiled: $($(PKG)_DIR)/.configured
	$(MAKE_IN) $($(PKG)_DIR)
	@touch $@

$($(PKG)_BINARY): $($(PKG)_DIR)/.compiled
	$(MAKE_IN) $($(PKG)_DIR) install

$(pkg)-precompiled: $($(PKG)_BINARY)
```

**When to Use:**
- Tool is only needed during build (like patchelf)
- Tool is for development/debugging (like readelf, objdump)
- No runtime use on the Fritz!Box device

### Solution 3: Separate Versions (Host vs Target)

Maintain **two separate versions**:
- **Modern version** (C++17) for host-tools
- **Old version** (C++03) for target packages

**Example: patchelf**

```makefile
# Host tool (modern version)
# make/host-tools/patchelf-host/patchelf-host.mk
$(call TOOLS_INIT, 0.18.0)  # Latest, requires C++17

# Target package (compatible version)  
# make/pkgs/binary-tools/binary-tools.mk
BINARY_TOOLS_PATCHELF_VERSION := 0.9  # Old, C++03 compatible
```

**Important:** Don't make target package depend on host-tool source!

```makefile
# WRONG - Creates dependency on incompatible version
$(PKG)_PATCHELF_DIR := $(PATCHELF_HOST_DIR)

# CORRECT - Separate download and build
BINARY_TOOLS_PATCHELF_VERSION := 0.9
BINARY_TOOLS_PATCHELF_SOURCE := patchelf-$(BINARY_TOOLS_PATCHELF_VERSION).tar.bz2
BINARY_TOOLS_PATCHELF_HASH := <hash_of_0.9>
```

### Solution 4: Exclude from Package (Mark as Broken)

If no compatible version exists and host-only isn't appropriate:

```kconfig
# Config.in
config FREETZ_PACKAGE_BINARY_TOOLS_PATCHELF
	bool "patchelf"
	depends on BROKEN  # Requires C++17, incompatible with uClibc++
	default n
	help
		Modify ELF executables and libraries.
		
		NOTE: Currently broken due to C++ standard library requirements.
		Use patchelf-host instead.
```

## Debugging C++ Compilation Issues

### Check Required C++ Features

```bash
# 1. Find #include directives
cd source/target-ARCH/PACKAGE-VERSION
grep -rh "^#include <" --include="*.cc" --include="*.cpp" --include="*.cxx" | sort -u

# 2. Check for C++11+ features
grep -rn "std::" --include="*.cc" --include="*.cpp" | grep -E "unique_ptr|shared_ptr|unordered|regex|thread"

# 3. Check configure requirements
cat configure.ac CMakeLists.txt | grep -E "CXX.*STANDARD|std=c\+\+|REQUIRE.*CXX"
```

### Verify uClibc++ Capabilities

```bash
# Check what headers uClibc++ provides
ls toolchain/build/ARCH/arm-linux-uclibcgnueabi/usr/include/uClibc++/

# Common MISSING headers:
# - unordered_map, unordered_set
# - memory (for smart pointers)
# - regex
# - thread, mutex, condition_variable
# - chrono (partially missing)

# Common AVAILABLE headers:
# - vector, list, map, set
# - string, iostream
# - algorithm (basic functions only)
# - iterator
```

### Testing Compilation

```bash
# Try minimal test
cat > test.cpp << 'EOF'
#include <unordered_map>
int main() {
    std::unordered_map<int,int> m;
    return 0;
}
EOF

arm-linux-g++-wrapper -std=c++17 test.cpp
# If fails: uClibc++ doesn't support this feature
```

## Best Practices

1. **Default to Older Versions** for target packages
   - Prefer C++03 compatible code
   - Check release history for compatibility

2. **Host Tools Can Be Modern**
   - Use latest versions for host-tools
   - System libstdc++ has full support

3. **Document C++ Requirements**
   ```makefile
   ### NOTE: Requires C++17, only available as host-tool
   ```

4. **Provide Alternatives**
   - If tool is useful, provide host-tool version
   - Document in Config.in help text

5. **Test Both Environments**
   ```bash
   # Test host compilation
   make patchelf-host-precompiled
   
   # Test target compilation (if claiming support)
   make binary-tools-precompiled
   ```

## Example: Complete patchelf Solution

**Host Tool (modern):**
```makefile
# make/host-tools/patchelf-host/patchelf-host.mk
$(call TOOLS_INIT, 0.18.0)
$(PKG)_SOURCE:=$(pkg)-$($(PKG)_VERSION).tar.bz2
$(PKG)_HASH:=1952b2a782ba576279c211ee942e341748fdb44997f704dd53def46cd055470b
$(PKG)_SITE:=https://github.com/NixOS/patchelf/releases/download/$($(PKG)_VERSION)
### WEBSITE:=https://github.com/NixOS/patchelf
### NOTE: Requires C++17 (std::unordered_map), not compatible with uClibc++

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_DIR)/.compiled: $($(PKG)_DIR)/.configured
	$(MAKE_IN) $($(PKG)_DIR)
	@touch $@

$($(PKG)_BINARY): $($(PKG)_DIR)/.compiled
	$(MAKE_IN) $($(PKG)_DIR) install

$(pkg)-precompiled: $($(PKG)_BINARY)
```

**Target Package (compatible):**
```makefile
# make/pkgs/binary-tools/binary-tools.mk (excerpt)

# Separate patchelf version for target
BINARY_TOOLS_PATCHELF_VERSION := 0.9
BINARY_TOOLS_PATCHELF_SOURCE := patchelf-$(BINARY_TOOLS_PATCHELF_VERSION).tar.bz2
BINARY_TOOLS_PATCHELF_HASH := f2a...
BINARY_TOOLS_PATCHELF_SITE := https://github.com/NixOS/patchelf/archive/refs/tags

# Download separately (don't reuse patchelf-host source!)
$(DL_DIR)/$(BINARY_TOOLS_PATCHELF_SOURCE):
	$(DL_TOOL) $(DL_DIR) $(BINARY_TOOLS_PATCHELF_SOURCE) \
		$(BINARY_TOOLS_PATCHELF_SITE)/$(BINARY_TOOLS_PATCHELF_VERSION).tar.gz \
		$(BINARY_TOOLS_PATCHELF_HASH)

# Build with uClibc++ (works because 0.9 uses C++03)
$(BINARY_TOOLS_PATCHELF_BINARY): $(BINARY_TOOLS_DIR)/.configured
	$(SUBMAKE) -C $(BINARY_TOOLS_PATCHELF_DIR)
```

## Summary Table

| Scenario | Solution | Example |
|----------|----------|---------|
| Tool for build-time only | Host-tool (modern version) | patchelf 0.18 |
| Tool for device, old version exists | Target package (old version) | patchelf 0.9 |
| Tool for device, no compatible version | Mark as BROKEN | Some C++20 tools |
| Library needed by other packages | Find C++03 compatible version | libfoo 1.x instead of 2.x |

---

## References

- [Shared Library Versioning](https://tldp.org/HOWTO/Program-Library-HOWTO/shared-libraries.html)
- [ABI Compatibility](https://www.akkadia.org/drepper/dsohowto.pdf)
- [GNU Libtool Versioning](https://www.gnu.org/software/libtool/manual/html_node/Libtool-versioning.html)
- [Meson Build System](https://mesonbuild.com/Cross-compilation.html)
- [uClibc++ Documentation](https://cxx.uclibc.org/)
- [C++ ABI Compatibility](https://gcc.gnu.org/onlinedocs/libstdc++/manual/abi.html)
