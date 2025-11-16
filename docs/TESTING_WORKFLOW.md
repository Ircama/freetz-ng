# Freetz-NG Testing Workflows Guide

This document provides guidance for testing packages and firmware builds using the GitHub Actions workflow in Freetz-NG: .github/workflows/make_package.yml.

## Overview

Freetz-NG uses GitHub Actions workflows for testing and for building firmwares; the related workflow is:

- **`make_package.yml`** - Comprehensive package and firmware testing matrix (multiple toolchains and configurations)

The workflow supports manual triggering via `workflow_dispatch`.

## Workflows Description

### Come usare make

Esempio per `bzip2`:

`bzip2-clean`

- Cosa fa: Rimuove solo i file compilati e gli artefatti di build, mantenendo il codice sorgente scaricato e spacchettato.
- Uso: Quando vuoi ricompilare senza riscaricare tutto, mantenendo le modifiche locali ai sorgenti.

`bzip2-dirclean`

- Cosa fa: Rimuove completamente la directory di build del pacchetto `($(BZIP2_DIR))` e la directory target del pacchetto. `bzip2-dirclean` è un superset di `bzip2-clean` e quindi comprende tutto quello che fa `bzip2-clean`, più altro.
- Uso: Quando vuoi ricominciare da zero la compilazione, forzando il riscaricamento e la ricompilazione completa.

`bzip2-precompiled`

- Cosa fa: Compila e installa il pacchetto nella directory target, rendendolo pronto per l'inclusione nel firmware.
- Uso: Target principale per compilare il pacchetto. Include dipendenze automatiche basate sulla configurazione (es. libreria se `FREETZ_LIB_libbz2=y`).

`bzip2-recompile`

- Cosa fa: Combinazione di dirclean + precompiled - rimuove tutto e ricompila da zero.
- Uso: Quando vuoi essere sicuro di una compilazione completamente pulita, utile dopo modifiche significative alla configurazione o al codice.

### make_package.yml

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
