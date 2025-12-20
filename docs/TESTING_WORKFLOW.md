# Freetz-NG Testing Workflows Guide

Freetz-NG provides a comprehensive testing framework that combines local development capabilities with automated validation across multiple platforms. Understanding both approaches is crucial for effective package and firmware development.

## Overview

When developing packages or modifying firmware configurations, you'll first work directly on your development machine. This local testing phase allows you to compile packages, build firmware images, and test them on devices you physically own. It's the foundation of the development process, where you can quickly iterate, debug issues, and verify that your changes work as expected. Local testing gives you full control over the build environment and immediate access to debugging tools.

While local testing ensures your changes work on your specific setup, Freetz-NG's ecosystem spans approximately tens of different device models, each with unique hardware characteristics, firmware versions, and toolchain requirements. To ensure compatibility across this diverse ecosystem, Freetz-NG uses GitHub Actions workflows that automatically test your changes across all supported platforms. This automated testing catches platform-specific issues that might not appear in your local environment and provides confidence that your modifications work consistently across the entire Freetz-NG user base.

This guide first explains the local build system, then covers automated workflow testing to provide a complete testing strategy.

------------------

## Understanding Freetz-NG Build System

We will now understand the main parameters offered by Freetz-NG's `make` command.

The simplest way to use `make` is through the following commands:

```bash
make menuconfig  # configure your Freetz-NG firmware build options (device, packages, toolchain, etc.)
make  # build the firmware
```

The following two paragraphs better explain the above commands.

### make menuconfig

This is Freetz-NG's implementation of the [Kconfig](https://docs.kernel.org/kbuild/kconfig-language.html) system (derived from Linux kernel configuration tools). It provides an interactive menu-driven [Ncurses](https://en.wikipedia.org/wiki/Ncurses) textual user interface for configuring the firmware build options. It generates the `.config` file that serves as the authoritative configuration for the subsequent `make`.

**What it does:**
- Launches the `tools/kconfig/mconf` binary (built automatically via `make tools` or `make kconfig-host`)
- Displays a hierarchical menu structure based on `Config.in` files
- Allows users to select/deselect packages, libraries, kernel options, and device-specific features
- Generates the `.config` file that serves as the authoritative configuration for subsequent builds
- The `.config` file contains all user selections in `FREETZ_PACKAGE_*=y/n` format

**Key files involved:**
- `Config.in` - Main configuration skeleton written in Kconfig language
- `.config` - User-generated configuration file (should not be edited manually)
- `tools/kconfig/mconf` - The menu interface binary
- `tools/kconfig/conf` - Command-line version with more features

**Alternative menuconfig targets:**
- `make menuconfig-single` - Shows configuration as a flat tree structure without subpages
- `make config` - Text-based configuration using `tools/kconfig/conf`

### make (without arguments)

This is the main build command that compiles the complete firmware image based on the configuration in `.config`.

**What it does:**
- Downloads required source packages and firmware files
- Builds the cross-compilation toolchain (GCC, binutils, etc.)
- Compiles selected packages and libraries
- Creates the final firmware image (`.image` file)
- Generates build artifacts in the `images/` directory

**Build process overview:**
1. **Preparation**: Downloads and extracts source packages
2. **Toolchain**: Builds cross-compilation tools for target architecture
3. **Kernel**: Compiles kernel modules and headers
4. **Packages**: Builds user-space applications and libraries
5. **Image creation**: Assembles final firmware using `fwmod`

### tools/genin

This is a validation tool that checks the consistency of package configurations.

**What it does:**
- Parses all `Config.in` files in the package directories
- Validates menu structure and dependencies
- Should return no errors if package configurations are properly set up
- Helps catch configuration issues before attempting builds

**Usage:**
```bash
tools/genin
```

If `tools/genin` returns errors, it indicates problems with package configuration files that need to be fixed before building.

### make olddefconfig

This target updates an existing `.config` file to match the current menu structure, setting any new options to their default values.

**What it does:**
- Takes an existing `.config` file as input
- Adds any new configuration options that have been added to `Config.in` files
- Sets new options to their default values (usually 'n' for packages)
- Maintains existing user selections
- Updates dependencies and selects based on current menu logic

**When to use:**
- After pulling updates that add new configuration options
- When switching between different branches with different menu structures
- To ensure `.config` is compatible with current codebase

**Related targets:**
- `make oldconfig` - Interactive version that prompts for new options
- `make silentoldconfig` - Non-interactive version (same as olddefconfig)
- `make defconfig` - Creates new config with all defaults

### make help

This target displays a summary of all available make targets and their descriptions.

**What it shows:**
- Package-specific targets (compile, clean, dirclean, etc.)
- Global build targets (menuconfig, firmware, etc.)
- Development and debugging targets
- Tool-related targets

**Usage:**
```bash
make help
```

This is useful for discovering available build options and understanding the build system capabilities.

## Make Clean Targets

When you want to restart the build process from scratch, you need to use `make dirclean`. However, Freetz-NG provides several cleaning options with different scopes:

### make cacheclean

**What it does:**
- Removes small cached files and directories
- Cleans temporary configuration files (`.config.*.tmp`, `.config.old`, `.config.compressed`)
- Removes generated Config.in files (`make/pkgs/Config.in.generated`, `make/pkgs/external.in.generated`)
- Cleans build directory (`$(BUILD_DIR)`)
- Removes fakeroot cache directory
- Removes detected firmware images in download directory
- Runs custom fwmod cleanup scripts

**Scope:** Minimal cleanup, preserves source code and compiled packages
**Use when:** You want to refresh caches and temporary files without rebuilding everything

### make clean

**What it does:**
- Everything that `cacheclean` does
- Additionally cleans tools (host tools, cross-compilation tools)

**Scope:** Cache cleanup + tools cleanup
**Relationship:** `clean` ⊃ `cacheclean` (clean is a superset of cacheclean)
**Use when:** You want to recompile tools but keep source code and packages

### make dirclean

**What it does:**
- Everything that `clean` does
- Additionally removes:
  - Package build directories (`$(PACKAGES_DIR)`)
  - Source code directories (`$(SOURCE_DIR)`)
  - Target toolchain directory (`$(TARGET_TOOLCHAIN_DIR)`)
  - Kernel build directory (if `.config` exists)

**Scope:** Complete source cleanup except tools and configuration
**Relationship:** `dirclean` ⊃ `clean` ⊃ `cacheclean`
**Use when:** You want to restart compilation from scratch, forcing re-download and re-extraction of sources

### make distclean

**What it does:**
- Everything that `dirclean` does
- Additionally removes:
  - Configuration files (`.config.cmd`, `.tmpconfig.h`)
  - Include config directory (`$(INCLUDE_DIR)/config`)
  - Firmware images directory (`$(FW_IMAGES_DIR)`)
  - Kernel target directory (`$(KERNEL_TARGET_DIR)`)
  - All package and source directories
  - Toolchain directory (`$(TOOLCHAIN_DIR)`)
  - Tools build directory (`$(TOOLS_BUILD_DIR)`)

**Scope:** Complete cleanup except download directory
**Relationship:** `distclean` ⊃ `dirclean` ⊃ `clean` ⊃ `cacheclean`
**Use when:** You want a completely fresh environment, equivalent to a fresh checkout
**Note:** Preserves `.config`, `config/custom.in`, `.fwmod_custom`, and download directory (`~/.freetz-dl/`)

### Quick Reference

| Target | Removes Sources | Removes Tools | Removes Config | Preserves |
|--------|----------------|---------------|----------------|-----------|
| `cacheclean` | ❌ | ❌ | Temp files only | Sources, packages, tools |
| `clean` | ❌ | ✅ | Temp files only | Sources, packages |
| `dirclean` | ✅ | ✅ | Temp files only | `.config`, downloads |
| `distclean` | ✅ | ✅ | ✅ | Downloads only |

**Recommendation:** Use `dirclean` for most rebuild scenarios. Use `distclean` only when you want to start completely fresh.

## Menuconfig Maintenance - Technical Notes

### Configuration File Properties
- `.config` serves as the authoritative configuration file for all build processes
- Manual editing is not recommended; always use `make menuconfig`
- File is copied to `/etc/.config` in final firmware (unless disabled in menuconfig)
- Primary debugging resource for configuration-related user issues

### Dependency Warning Analysis
Configuration save operations may produce warnings such as:
```
warning: (FREETZ_PACKAGE_AUTOFS_NFS && FREETZ_PACKAGE_NFSROOT) selects FREETZ_MODULE_nfs which has unmet direct dependencies (FREETZ_KERNEL_VERSION_2_6_13_1 || FREETZ_KERNEL_VERSION_2_6_28 || FREETZ_KERNEL_VERSION_2_6_32)
```

**Interpretation:**
- Package selection requires kernel module support unavailable in current kernel version
- Resolution options: update kernel dependencies or disable package for incompatible kernels

### Remove-Patch Configuration Pattern
For remove-patches (AVM feature removal), implement this dependency structure:

```
FREETZ_PACKAGE_FOO
    select FREETZ_REMOVE_MY_FEATURE if FREETZ_HAS_AVM_MY_FEATURE

FREETZ_REMOVE_MY_FEATURE
    depends on FREETZ_HAS_AVM_MY_FEATURE

FREETZ_HAS_AVM_MY_FEATURE
    depends on FREETZ_TYPE_A || FREETZ_TYPE_B || ...
```

**Purpose:** Ensures remove-patches are selectable only when AVM feature exists on target device.

### Syntax Error Diagnostics
When `make menuconfig` reports syntax errors:

**Cache-enabled diagnosis:**
- Examine line number in `Config.in.cache`
- Search backwards for `INCLUDE_BEGIN` to identify source file

**Cache-disabled diagnosis:**
- Execute `make menuconfig-nocache` for precise file and line error location

### Configuration Maintenance Procedures
- Execute `tools/genin` after `Config.in` file modifications to validate syntax
- Run `make olddefconfig` post-update to process new configuration options
- Validate configurations across multiple device types to detect dependency conflicts
- Document hardware/firmware-specific features with appropriate dependency declarations

## Package-Specific Make Targets

Freetz-NG provides specific make targets for individual packages. Each package supports several build operations with convenient shortcuts that combine multiple steps.

For example, the `-recompile` target is equivalent to running `-dirclean` followed by `-precompiled` - both achieve a complete clean rebuild.

Throughout this section, we use the `bzip2` package as an example. To work with other packages, simply replace `bzip2` with the desired package name (which corresponds to the package's `.mk` filename in `make/pkgs/`).

For example, to work with the PHP package, you would use `php` (from `make/pkgs/php/php.mk`), or for OpenSSL you would use `openssl` (from `make/pkgs/openssl/openssl.mk`).

Here are the main target patterns:

### bzip2-clean

**What it does:**
- Removes only compiled files and build artifacts
- Preserves downloaded and extracted source code
- Keeps local source code modifications

**Use when:** You want to recompile without re-downloading everything, maintaining local source changes

### bzip2-dirclean

**What it does:**
- Completely removes the package build directory (`$(BZIP2_DIR)`) and target directory
- `bzip2-dirclean` is a superset of `bzip2-clean` - it includes everything `bzip2-clean` does plus more
- Forces complete re-download and re-extraction of sources

**Use when:** You want to restart compilation from scratch, forcing re-download and complete recompilation

**Relationship:** `bzip2-dirclean` ⊃ `bzip2-clean`

### bzip2-precompiled

**What it does:**
- Compiles and installs the package in the target directory, making it ready for firmware inclusion
- Main target for compiling the package
- Includes automatic dependencies based on configuration (e.g., library if `FREETZ_LIB_libbz2=y`)

**Use when:** Standard package compilation with dependency resolution

### bzip2-recompile

**What it does:**
- Combination of `dirclean` + `precompiled` - removes everything and recompiles from scratch
- Ensures completely clean compilation

**Use when:** You want to be sure of a completely clean build, useful after significant configuration changes or code modifications

### General Package Target Patterns

All packages support these target suffixes:

| Suffix | Description | Use Case |
|--------|-------------|----------|
| `-clean` | Remove build artifacts, keep sources | Quick rebuild |
| `-dirclean` | Remove build directory and sources | Full rebuild |
| `-precompiled` | Standard compilation with dependencies | Normal build |
| `-recompile` | Clean + recompile from scratch | Clean build |

**Examples:**
```bash
# Clean rebuild of bzip2
make bzip2-clean bzip2-precompiled

# Full rebuild of bzip2
make bzip2-dirclean bzip2-precompiled

# Or simply:
make bzip2-recompile

# Multiple packages
make bzip2-recompile patchelf-recompile
```

------------------

## Local vs. Workflow-Based Testing

Freetz-NG supports two main approaches for testing packages and firmware builds:

### Local Testing (Understanding Freetz-NG Build System)
The previous section explains how to compile the system or individual packages directly on your local machine. This approach is essential for:
- Initial development and debugging
- Testing on devices you physically own
- Quick iteration during package development
- Understanding the build process in detail

### Workflow-Based Testing (make_package.yml)
The following section describes automated testing using GitHub Actions workflows. This approach is crucial for:
- Testing across multiple device/toolchain combinations simultaneously
- Ensuring compatibility across the entire Freetz-NG ecosystem
- Automated regression testing
- CI/CD integration

## make_package.yml

This section explains how to use GitHub Actions workflows for comprehensive automated testing. Workflows provide significant advantages over local testing alone:

### Why Use GitHub Actions Workflows?

GitHub Actions workflows automate the build process in isolated environments, allowing you to:

1. **Test Multiple Configurations Simultaneously**: Instead of testing on just one device, workflows can test across dozens of device/firmware/toolchain combinations in parallel
2. **Ensure Ecosystem Compatibility**: Freetz-NG supports approximately 30 pre-configured devices with different hardware capabilities and firmware versions
3. **Catch Platform-Specific Issues**: Different devices may have unique kernel versions, toolchain requirements, or hardware-specific code that needs validation
4. **Automate Regression Testing**: Workflows can run automatically on code changes, catching issues before they reach users

### The Testing Workflow

A typical testing process follows this progression:

1. **Local Testing**: Start by testing on devices you physically own and can access for debugging
2. **Device-Specific Testing**: Test on specific device configurations you're targeting
3. **Comprehensive Workflow Testing**: Use GitHub Actions to verify compilation across all supported devices and toolchains

This multi-stage approach ensures both thorough testing and efficient development workflows.

### Workflow Architecture

The `make_package.yml` workflow uses a matrix strategy to test packages across multiple dimensions:

#### What are GitHub Actions Workflows?

GitHub Actions workflows are automated processes that run on GitHub's infrastructure. For Freetz-NG, they provide:

- **Isolated Build Environments**: Each test runs in a clean Ubuntu environment with no interference from local machine state
- **Parallel Execution**: Multiple device/toolchain combinations can be tested simultaneously
- **Version Control Integration**: Workflows can trigger automatically on pull requests, pushes, or scheduled intervals
- **Artifact Storage**: Build outputs can be stored and downloaded for further analysis

#### Pre-configured Devices and Toolchains

Freetz-NG comes with approximately 30 pre-configured device profiles, each representing different:

- **Hardware Platforms**: Different router models (7590, 7530, 7490, etc.)
- **Firmware Versions**: Various AVM firmware releases (08.0X, 08.2X, 08.3X, etc.)
- **Kernel Versions**: Different Linux kernel versions with varying feature sets
- **Toolchain Configurations**: GCC versions, optimization flags, and architecture-specific settings

Additional device configurations can be added manually by modifying the workflow matrix or using the `custom_config` parameter.

#### The Complete Testing Process

A comprehensive testing approach follows this sequence:

1. **Local Development Testing**:
   - Test on devices you physically own
   - Use local build system for quick iteration
   - Debug issues directly on target hardware

2. **Device-Specific Testing**:
   - Test on specific device models you're targeting
   - Verify functionality on particular firmware versions
   - Check hardware-specific features

3. **Workflow-Based Comprehensive Testing**:
   - Use GitHub Actions to test across all supported devices
   - Catch platform-specific compilation issues
   - Ensure compatibility across the entire ecosystem
   - Generate reports for all device combinations

This multi-layered approach ensures both development efficiency and ecosystem-wide compatibility.

**Purpose**: Comprehensive testing of packages and firmware builds across multiple toolchain configurations using a matrix build strategy. Supports both individual package testing and full firmware builds.

**Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `make_target` | string | No | `""` | Make target: `'pkg1,pkg2'`, `'package-precompiled'`, `'package-recompile'`, `'firmware'`, `'-firmware'`, `'fake-firmware'`, `'libs'`, `'=package'`, or `'pkg-firmware'`, `'pkg-recompile-firmware'`, `'pkg-precompiled-firmware'` (builds firmware and the specified package, gh param: -f make_target=php). Supports custom labels using `#` syntax (e.g., `'php#Test PHP 8.4'` or `'php # Test PHP 8.4'`) to customize the workflow run name. Spaces before and after `#` are optional and ignored |
| `url` | string | No | `""` | URL of config file (.tar, .tgz, .tbz, .config) or empty to use `secrets.ACTIONS_TESTER` |
| `verbosity` | choice | No | `"0"` | Build verbosity level: `0`=quiet, `1`=normal, `2`=verbose |
| `download_toolchain` | boolean | No | `false` | Try to download precompiled toolchain (may fail without AVX2 support) |
| `download_hosttools` | boolean | No | `false` | Try to download precompiled host tools |
| `cancel_previous` | boolean | No | `true` | Cancel previous runs of this workflow |
| `use_queue` | boolean | No | `true` | Use workflow queue to prevent concurrent runs |
| `custom_config` | string | No | `""` | Custom device/firmware/language (e.g., `'7530_W6_V1 08_2X EN'` or `'7590 08_0X'` or just `'7530'`, separators: space/tab/comma/semicolon/pipe/dash). When used with `-firmware` target, can specify custom pre-build commands to execute before firmware build (e.g., `'make python3-host-dirclean && make python3-host-precompiled'`) |
| `add_or_override` | choice | No | `"add"` | Add custom config to matrix or override with only custom configuration |
| `create_artifacts` | boolean | No | `false` | Create and upload build artifacts |

**Matrix Strategy**:
- Tests packages across all available toolchains (when `add_or_override="add"` or no overrides)
- Tests only custom configuration (when `add_or_override="override"`)
- Maximum 16 parallel jobs

**Target Suffixes**:
- `package` → `-precompiled` (default)
- `package-precompiled` → Compile precompiled package
- `package-recompile` → Force recompilation from source
- `firmware` → Build complete firmware image
- `-firmware` → Build firmware with native .config (no modifications, uses configuration as-is)
- `fake-firmware` → Generate fake firmware for testing device configuration
- `package-firmware` → Build firmware and the specified package
- `package-recompile-firmware` → Build firmware and force recompilation of the specified package
- `package-precompiled-firmware` → Build firmware and compile precompiled package
- `libs` → Build only libraries
- `=package` → Build package skipping library dependencies

**Special Packages**:
- `firmware` → Build complete firmware image instead of package
- `-firmware` → Build firmware with native .config (no modifications, preserves configuration exactly as downloaded/loaded)
- `fake-firmware` → Generate fake firmware structure for testing device configuration (no real firmware download required)
- `libs` → Build only libraries
- `=package` → Build package skipping library dependencies

## Initial Setup

### 1. Verify and Configure Remotes

Locally clone your already forked repository from GitHub:

```bash
git clone https://github.com/<your user>/freetz-ng
cd freetz-ng
```

Add upstream:

```bash
git remote -v
# If upstream is missing, add it:
git remote add upstream https://github.com/Freetz-NG/freetz-ng.git
```

### 2. Enable GitHub Actions

- Navigate to: `https://github.com/<your user>/freetz-ng/settings/actions`
- Select: "Allow all actions and reusable workflows"

Abilita GitHub Pages !!!!!!!!!!!!!!!!!!!!

### 3. Download Required Files !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

```bash
# Download workflow documentation
wget https://raw.githubusercontent.com/Ircama/freetz-ng/testing-tools/TESTING_WORKFLOW.md

# Download make_package.yml workflow
wget https://raw.githubusercontent.com/Ircama/freetz-ng/testing-tools/make_package.yml

# Download merge script
wget https://raw.githubusercontent.com/Ircama/freetz-ng/testing-tools/merge_all_prs.sh
chmod +x merge_all_prs.sh

# Alternative: checkout testing branch
git checkout testing-tools
cp TESTING_WORKFLOW.md make_package.yml merge_all_prs.sh ..
git checkout master
```

## Testing Workflow

### Step 1: Synchronize Master with Upstream

⚠️ **WARNING**: This command will delete all local changes on master!

```bash
git checkout master
git fetch upstream
git reset --hard upstream/master  # Align with upstream
git push origin master --force    # Force push to your fork
```

### Step 2: Generate Test Environment !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

**Option A - Merge All Open PRs:**
```bash
../merge_all_prs.sh
# Or specify a particular PR:
../merge_all_prs.sh 1276

# If successful:
git push origin master
```

**Option B - Merge Specific PRs:**
```bash
git merge ircama-python3 --no-edit
git merge ircama-php --no-edit
# ... add other PRs as needed

git push origin master
```

### Step 3: Configure Packages to Test

```bash
# Configure packages you want to test
# This will be your base configuration

# Optionally: rm .config

make menuconfig
```

### Step 4: Upload Configuration

**Option A - Copy to Workflow Directory:**
```bash
cp .config .github/workflows/myconfig
git add .github/workflows/myconfig
git commit -m "config: Update test configuration"
```

**Option B - Upload via GitHub Releases (for URL-based workflows):**
```bash
# Create a temporary release with your config file (example using label "none" for tag)
gh release delete none --yes 2>/dev/null || true
git tag -d none 2>/dev/null || true
git push origin :refs/tags/none 2>/dev/null || true

# Create release and get download URL
URL=$(gh release create none -t ".config" -n ".config" --prerelease .config | \
      sed 's#/releases/tag/#/releases/download/#; s#$#/default.config#')

echo "Config uploaded to: $URL"
# Use this URL in workflow parameters: -f url="$URL"
```

This method creates a temporary release and provides a direct download URL that can be used with the `url` parameter in workflows.

### Step 5: Copy Configurations !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

```bash
git fetch origin
git branch -D integration-testing
git push origin --delete integration-testing
git checkout -b integration-testing origin/ircama-python315a1
git checkout origin/testing-tools -- .github/workflows/make_package.yml
git add .github/workflows/make_package.yml
git commit -m "Use make_package.yml from testing-tools"
git push origin integration-testing

URL=$(gh release create python315 -t ".config" -n ".config" --prerelease .config | sed 's#/releases/tag/#/releases/download/#; s#$#/default.config#')
echo $URL


gh workflow run make_package.yml -r integration-testing -f make_target='firmware' -f url='https://github.com/Ircama/freetz-ng/releases/download/python315/default.config' -f verbosity="0" -f cancel_previous="true" -f use_queue=false
```

```bash
# Optionally clean existing workflows:
# rm .github/workflows/*  # Remove all workflows

# Alternatively to using URL configuration upload, copy current configuration to workflows directory
cp .config .github/workflows/myconfig
```

### Step 6: Commit and Push

```bash
git add .github/workflows/.
git commit -m "CI: Update myconfig for testing $(date +%Y-%m-%d)"
git push origin master
```

### Step 7: Execute Workflow Manually !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

**Via Web Interface:**
1. Go to: https://github.com/Ircama/freetz-ng/actions
2. Click on: "make_package"
3. Click: "Run workflow"
4. Enter package name (e.g., `php-recompile` or `patchelf,ncurses`)
5. Click: "Run workflow"

**Via GitHub CLI:**
```bash
gh repo set-default Ircama/freetz-ng
gh workflow run make_package.yml -f make_target="util-linux-recompile"
```

### Step 8: Monitor Execution !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

**Via CLI:**
```bash
gh repo set-default Ircama/freetz-ng
gh run watch
```

**Via Web:**
- https://github.com/Ircama/freetz-ng/actions

## Manual Workflow Triggers

### make_package.yml Examples

```bash

# Test single package with all configured devices; use myconfig if exists, otherwise generates a default .config file   
gh workflow run make_package.yml -f make_target="php"

# Build only libraries
gh workflow run make_package.yml -f make_target="libs"

# Build package skipping library dependencies
gh workflow run make_package.yml -f make_target="=php-precompiled"

# Generate fake firmware for testing device configuration
gh workflow run make_package.yml -f make_target="fake-firmware"
```

### Target Behavior Examples

The workflow interprets different `make_target` inputs as follows:

| Input | Action | Description |
|-------|--------|-------------|
| `php` | `make php-precompiled` | Build package with default precompiled target |
| `php-precompiled` | `make php-precompiled` | Explicitly build package as precompiled |
| `php-recompile` | `make php-recompile` | Force recompilation from source |
| `php-firmware` | `make` (with php enabled) | Build complete firmware including php package |
| `php-precompiled-firmware` | `make` (with php-precompiled) | Build firmware with php compiled as precompiled |
| `php-recompile-firmware` | `make` (with php-recompile) | Build firmware with php recompiled from source |
| `firmware` | `make` | Build complete firmware image only |
| `-firmware` | `make` (native .config) | Build firmware preserving .config exactly as-is (no modifications) |
| `fake-firmware` | Generate fake firmware | Test device configuration without downloading real firmware |
| `libs` | `make libs` | Build only libraries |
| `=php` | `make php-precompiled` (skip libs) | Build package skipping library dependencies |
| `=php-precompiled` | `make php-precompiled` (skip libs) | Build package as precompiled skipping library dependencies |
| `php,patchelf` | Multiple builds | Test multiple packages sequentially |
| `php#Test PHP 8.4` | `make php-precompiled` | Build package with custom label for workflow run name (spaces around `#` are optional) |

**Notes:**
- Firmware targets (`*-firmware`) build the complete firmware image with the specified package(s) included
- `-firmware` builds firmware with native .config (no modifications applied by workflow, uses configuration exactly as downloaded or from myconfig). This is useful for:
  - Testing custom configurations without workflow alterations
  - Building firmware with user-specific settings preserved
  - CI/CD testing of exact configuration files
  - Validating firmware builds with precise configuration control
  - Executing custom pre-build commands via `custom_config` parameter (e.g., for rebuilding host tools)
- `fake-firmware` generates a realistic fake firmware structure for testing device configuration without requiring real firmware download. This is useful for:
  - Testing device configurations when firmware is unavailable or obsolete
  - Validating build system configuration without full firmware build
  - Testing toolchain compatibility across multiple devices quickly
  - CI/CD testing without large firmware downloads
- Package-only targets build individual packages without full firmware
- Default behavior for packages without suffix is `-precompiled`
- All builds run across the configured device/toolchain matrix

```bash

# Make firmware for a specific device using the generic "make" compilation.
# It includes the standard download of the original firmware from AVM.
# The assumption for make_target="firmware" to work is that AVM has the hosted
# file of the requested firmware release. 
gh workflow run make_package.yml -f make_target="firmware" -f url="$URL" -f verbosity="0" -f cancel_previous="false" -f custom_config="7590_W6 08_2X EN" -f add_or_override=override -f use_queue=false -f create_artifacts=true

# Run a full build across all devices configured in the "integration-testing" branch.
# The URL references the python2-based ".config" generated manually via "make menuconfig".
# The "fake-firmware" target triggers a complete build ("make") for each device in the
# matrix without requiring the original AVM firmware, enabling end-to-end workflow testing
# even when the vendor firmware is unavailable.
gh workflow run make_package.yml -r integration-testing -f make_target='fake-firmware # python2' -f url='https://github.com/<your user>/freetz-ng/releases/download/python2/default.config' -f verbosity="0" -f cancel_previous="false" -f use_queue=false

# Test single package with all configured devices
gh workflow run make_package.yml -f make_target="patchelf" -f url="$URL" -f verbosity="0" -f cancel_previous="false" -f use_queue=false

# Test multiple packages
gh workflow run make_package.yml -f make_target="php,openssl,libxml2"

# Test with custom config URL (from GitHub Releases)
gh workflow run make_package.yml -f make_target="php" -f url="https://github.com/Ircama/freetz-ng/releases/download/none/default.config"

# Force recompilation with verbose output
gh workflow run make_package.yml -f make_target="patchelf-recompile,ncurses-recompile" -f verbosity="2"

# Full firmware build for toolchain package
gh workflow run make_package.yml -f make_target="gcc-toolchain,firmware"

# Test package on specific device/firmware (add to matrix)
gh workflow run make_package.yml -f make_target="php" -f custom_config="6670 07_5X" -f add_or_override="add"

# Test package ONLY on custom configuration (override matrix)
gh workflow run make_package.yml -f make_target="php" -f custom_config="6670 07_5X EN" -f add_or_override="override"

# Test package without workflow queue (allow concurrent runs)
gh workflow run make_package.yml -f make_target="php" -f use_queue="false"

# Test firmware build
gh workflow run make_package.yml -f make_target="firmware"

# Test firmware build with native configuration (no workflow modifications)
gh workflow run make_package.yml -f make_target="-firmware" -f url="$URL"

# Test firmware build with custom pre-build commands (e.g., rebuild Python host tools)
gh workflow run make_package.yml -f make_target="-firmware" -f url="$URL" -f custom_config="make python3-host-dirclean && make python3-host-precompiled"

# Test package with custom label for workflow run name
gh workflow run make_package.yml -f make_target="php#Test PHP 8.4 with libxml2"

# Test multiple packages with custom label
gh workflow run make_package.yml -f make_target="php,openssl,libxml2#Test PHP dependencies"

# Test device configuration with fake firmware
gh workflow run make_package.yml -f make_target="fake-firmware" -f custom_config="7530 08_2X EN"

# Test multiple devices with fake firmware
gh workflow run make_package.yml -f make_target="fake-firmware" -f custom_config="7530,7590,6670" -f add_or_override="override"

# Test libraries build
gh workflow run make_package.yml -f make_target="libs"

# Test package skipping library dependencies
gh workflow run make_package.yml -f make_target="=php-precompiled"

# Test with downloaded toolchain and hosttools
gh workflow run make_package.yml -f make_target="php" -f download_toolchain="true" -f download_hosttools="true"

# Create and upload build artifacts
gh workflow run make_package.yml -f make_target="php" -f create_artifacts="true"

# Build firmware and package
gh workflow run make_package.yml -f make_target="php-firmware"

# Build firmware and package with recompile
gh workflow run make_package.yml -f make_target="php-recompile-firmware"

# Build firmware and package precompiled
gh workflow run make_package.yml -f make_target="php-precompiled-firmware"
```

## Automatic Triggers !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

You can trigger workflows automatically by including build commands in commit messages:

```bash
# Single package test
git commit -m "test: make php-recompile"

# Multiple packages test
git commit -m "test: make php-recompile,patchelf-recompile"

# Full firmware build
git commit -m "test: make firmware"

# Build firmware with native configuration (no modifications)
git commit -m "test: make -firmware"

# Note: custom pre-build commands (custom_config) only work with manual triggers
# For custom commands use:
# gh workflow run make_package.yml -f make_target="-firmware" -f custom_config="<commands>"

# Build firmware and package
git commit -m "test: make php-firmware"

# Build only libraries
git commit -m "test: make libs"

# Test device configuration with fake firmware
git commit -m "test: make fake-firmware"

# Build package skipping library dependencies
git commit -m "test: make =php-precompiled"

# Build with custom label for workflow run name
git commit -m "test: make php#Test PHP 8.4 with all dependencies"

# Full build (not supported - will be skipped)
git commit -m "test: make"
```

**Note**: Commits starting with "CI:", "workflow:", "build:" are automatically skipped.

**Supported Patterns**

### Multiple Inputs

```bash
# Different targets for different packages
make php-recompile,patchelf-precompiled,ncurses-compile
```

**Other Examples**:
```bash
# Enable in menuconfig:
# Libraries → Compression, coding & regex → libxml2
make menuconfig
cp .config .github/workflows/myconfig
git add .github/workflows/myconfig
git commit -m "config: Enable libxml2"
git push
```

### Example: PHP Testing

```bash
# 1. Reset and sync
git checkout master
git fetch upstream
git reset --hard upstream/master
git push origin master --force

# 2. Merge PHP PR
git merge ircama-php --no-edit

# 3. Configure
make menuconfig
# Enable: PHP, libxml2, libatomic, openssl

# 4. Save config
cp .config .github/workflows/myconfig

# 5. Commit
git add .github/workflows/myconfig
git commit -m "test: make php-recompile

Enable PHP 8.4 with libxml2, libatomic, and openssl"

# 6. Push (automatic trigger)
git push origin master

# 7. Monitor
gh run watch
```

### Example: Toolchain Testing

```bash
# Test toolchain package across all configurations
gh workflow run make_package.yml -f make_target="gcc-toolchain,firmware"

# Test with custom configuration (using uploaded config)
URL="https://github.com/Ircama/freetz-ng/releases/download/none/default.config"
gh workflow run make_package.yml -f make_target="gcc-toolchain,firmware" -f url="$URL" -f verbosity="2"

# Test with custom configuration (direct URL)
gh workflow run make_package.yml -f make_target="gcc-toolchain,firmware" -f url="https://example.com/toolchain-test.config" -f verbosity="2"

# Test with downloaded toolchain and hosttools
gh workflow run make_package.yml -f make_target="gcc-toolchain,firmware" -f download_toolchain="true" -f download_hosttools="true" -f verbosity="2"
```

## Useful Commands

```bash
# Check workflow status
gh run list --workflow=make_package.yml --limit 5

# Cancel running workflow
gh run cancel <run-id>

# Download artifacts (if configured)
gh run download <run-id> --name myartifact.zip

# View logs
gh run view <run-id> --log

# List upstream PRs
gh pr list --repo Freetz-NG/freetz-ng --state open

# Interactive multi-merge
./merge_all_prs.sh
```

## Reset After Testing

```bash
# 1. Reset master to upstream
git fetch upstream
git checkout master
git reset --hard upstream/master
git push origin master --force

# 2. Clean local build files
make distclean

# 3. Optionally disable GitHub Actions
# Go to: https://github.com/Ircama/freetz-ng/settings/actions
# Select: "Disable actions"
```

---

## Quick Reference

### Manual Triggers
```bash
# Package testing
gh workflow run make_package.yml -f make_target="package-name"

# Full firmware build
gh workflow run make_package.yml -f make_target="firmware" -f verbosity="2"

# Firmware build with native configuration (no modifications)
gh workflow run make_package.yml -f make_target="-firmware" -f url="<config-url>"

# Firmware build with native configuration and custom pre-build commands
gh workflow run make_package.yml -f make_target="-firmware" -f url="<config-url>" -f custom_config="make python3-host-dirclean && make python3-host-precompiled"

# Fake firmware for device configuration testing
gh workflow run make_package.yml -f make_target="fake-firmware"

# Libraries build
gh workflow run make_package.yml -f make_target="libs"

# Package build skipping library dependencies
gh workflow run make_package.yml -f make_target="=package-name"
```

### Automatic Triggers !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
```bash
git commit -m "test: make php-recompile"

git commit -m "test: make -firmware"

git commit -m "test: make fake-firmware"

git commit -m "test: make libs"

git commit -m "test: make =php-precompiled"
```
