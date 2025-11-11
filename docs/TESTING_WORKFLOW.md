# Freetz-NG Testing Workflows Guide

This document provides guidance for testing packages and firmware builds using the GitHub Actions workflow in Freetz-NG: .github/workflows/make_package.yml.

## Overview

Freetz-NG uses GitHub Actions workflows for testing and for building firmwares; the related workflow is:

- **`make_package.yml`** - Comprehensive package and firmware testing matrix (multiple toolchains and configurations)

The workflow supports manual triggering via `workflow_dispatch`.

## Workflows Description

### make_package.yml

**Purpose**: Comprehensive testing of packages and firmware builds across multiple toolchain configurations using a matrix build strategy. Supports both individual package testing and full firmware builds.

**Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `make_target` | string | No | `""` | Make target: `'pkg1,pkg2'`, `'package-precompiled'`, `'package-recompile'`, `'firmware'`, `'libs'`, `'=package'`, or `'pkg-firmware'`, `'pkg-recompile-firmware'`, `'pkg-precompiled-firmware'` (builds firmware and the specified package, gh param: -f make_target=php) |
| `url` | string | No | `""` | URL of config file (.tar, .tgz, .tbz, .config) or empty to use `secrets.ACTIONS_TESTER` |
| `verbosity` | choice | No | `"0"` | Build verbosity level: `0`=quiet, `1`=normal, `2`=verbose |
| `download_toolchain` | boolean | No | `false` | Try to download precompiled toolchain (may fail without AVX2 support) |
| `download_hosttools` | boolean | No | `false` | Try to download precompiled host tools |
| `cancel_previous` | boolean | No | `true` | Cancel previous runs of this workflow |
| `use_queue` | boolean | No | `true` | Use workflow queue to prevent concurrent runs |
| `custom_config` | string | No | `""` | Custom device/firmware/language (e.g., `'7530_W6_V1 08_2X EN'` or `'7590 08_0X'` or just `'7530'`, separators: space/tab/comma/semicolon/pipe/dash) |
| `add_or_override` | choice | No | `"add"` | Add custom config to matrix or override with only custom configuration |
| `create_artifacts` | boolean | No | `false` | Create and upload build artifacts |

**Matrix Strategy**:
- Tests packages across all available toolchains (when `add_or_override="add"` or no overrides)
- Tests only custom configuration (when `add_or_override="override"`)
- Maximum 16 parallel jobs
- Fail-fast disabled (continues testing other combinations on failure)
- Each job tests one package-toolchain combination

**Build Output Categorization**:
- **System packages**: Core Freetz components (mod, modcgi, haserl, inetd, dropbear, etc.)
- **User packages**: User-selected packages
- **Base libraries**: uClibc/GCC runtime and AVM compatibility (libgcc_s, ld-uClibc, libcrypt, libdl, libm, libpthread, librt, libuClibc, libctlmgr, libavmhmac, libcapi, libmultid, etc.)
- **User libraries**: Additional libraries selected by user or required by packages

**Target Suffixes**:
- `package` → `-precompiled` (default)
- `package-precompiled` → Compile precompiled package
- `package-recompile` → Force recompilation from source
- `firmware` → Build complete firmware image
- `package-firmware` → Build firmware and the specified package
- `package-recompile-firmware` → Build firmware and force recompilation of the specified package
- `package-precompiled-firmware` → Build firmware and compile precompiled package

**Special Packages**:
- `firmware` → Build complete firmware image instead of package
- `libs` → Build only libraries
- `=package` → Build package skipping library dependencies

## Initial Setup

### 1. Verify and Configure Remotes

```bash
git remote -v
# If upstream is missing, add it:
git remote add upstream https://github.com/Freetz-NG/freetz-ng.git
```

### 2. Enable GitHub Actions

- Navigate to: https://github.com/Ircama/freetz-ng/settings/actions
- Select: "Allow all actions and reusable workflows"

### 3. Download Required Files

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

### Step 2: Generate Test Environment

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

### Step 5: Copy Configurations

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

### Step 7: Execute Workflow Manually

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

### Step 8: Monitor Execution

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
| `libs` | `make libs` | Build only libraries |
| `=php` | `make php-precompiled` (skip libs) | Build package skipping library dependencies |
| `=php-precompiled` | `make php-precompiled` (skip libs) | Build package as precompiled skipping library dependencies |
| `php,patchelf` | Multiple builds | Test multiple packages sequentially |

**Notes:**
- Firmware targets (`*-firmware`) build the complete firmware image with the specified package(s) included
- Package-only targets build individual packages without full firmware
- Default behavior for packages without suffix is `-precompiled`
- All builds run across the configured device/toolchain matrix

```bash

# Make firmware for a specific device
gh workflow run make_package.yml -f make_target="firmware" -f url="$URL" -f verbosity="0" -f cancel_previous="false" -f custom_config="7590_W6 08_2X EN" -f add_or_override=override -f use_queue=false -f create_artifacts=true

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

## Automatic Triggers

You can trigger workflows automatically by including build commands in commit messages:

```bash
# Single package test
git commit -m "test: make php-recompile"

# Multiple packages test
git commit -m "test: make php-recompile,patchelf-recompile"

# Full firmware build
git commit -m "test: make firmware"

# Build firmware and package
git commit -m "test: make php-firmware"

# Build only libraries
git commit -m "test: make libs"

# Build package skipping library dependencies
git commit -m "test: make =php-precompiled"

# Full build (not supported - will be skipped)
git commit -m "test: make"
```

**Note**: Commits starting with "CI:", "workflow:", "build:" are automatically skipped.

**Supported Patterns**

### Target Formats

- `package` → `-precompiled` (default)
- `package-precompiled` → Compile precompiled package
- `package-recompile` → Force recompilation from source
- `firmware` → Build complete firmware image
- `package-firmware` → Build firmware and the specified package
- `package-recompile-firmware` → Build firmware and force recompilation of the specified package
- `package-precompiled-firmware` → Build firmware and compile precompiled package
- `libs` → Build only libraries
- `=package` → Build package skipping library dependencies

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

# Libraries build
gh workflow run make_package.yml -f make_target="libs"

# Package build skipping library dependencies
gh workflow run make_package.yml -f make_target="=package-name"
```

### Automatic Triggers
```bash
git commit -m "test: make php-recompile"

git commit -m "test: make libs"

git commit -m "test: make =php-precompiled"
```
