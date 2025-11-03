# Freetz-NG Testing Workflows Guide

This document provides guidance for testing packages and firmware builds using two GitHub Actions workflows in Freetz-NG: .github/workflows/make_package.yml and .github/workflows/make_firmware.yml.

## Overview

Freetz-NG uses different GitHub Actions workflows; for testing, consider the following ones:

1. **`make_firmware.yml`** - Full firmware build testing (single configuration)
2. **`make_package.yml`** - Package testing matrix (multiple toolchains)

Both workflows support manual triggering via `workflow_dispatch` and automatic triggering via commit messages.

## Workflows Description

### make_firmware.yml

**Purpose**: Performs complete firmware builds for testing full system integration.

**Triggers**:
- Push to master branch affecting `.github/workflows/make_firmware.yml`
- Manual dispatch via GitHub UI or CLI

**Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `url` | string | No | `""` | URL of config file (.tar, .tgz, .tbz, .config) or empty to use `secrets.ACTIONS_TESTER` |
| `verbosity` | choice | No | `"0"` | Build verbosity level: `0`=quiet, `1`=normal, `2`=verbose |
| `download_toolchain` | boolean | No | `false` | Try to download precompiled toolchain (may fail without AVX2 support) |
| `cancel_previous` | boolean | No | `true` | Cancel previous runs of this workflow |
| `custom_device` | string | No | `""` | Override device type (e.g., `7530_W6_V1`, `7590_W5`) - empty uses config |
| `custom_firmware` | string | No | `""` | Override firmware version (e.g., `08_2X`, `07_5X`) - empty uses config |
| `custom_lang` | string | No | `""` | Override language (EN or DE) - empty uses config |

**Behavior**:
- Downloads and applies configuration from URL or secrets
- Builds complete firmware image
- Generates diagnostic information on failure
- Creates artifacts with built images
- Supports device/firmware/language overrides for testing compatibility

**Use Cases**:
- Full system integration testing
- Firmware release validation
- Testing configuration changes across different devices/firmware versions

### make_package.yml

**Purpose**: Tests individual packages across multiple toolchain configurations using a matrix build strategy.

**Triggers**:
- Push to master branch affecting workflow files or package/libs directories
- Manual dispatch via GitHub UI or CLI
- Automatic trigger via commit messages containing build commands

**Parameters**:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `make_target` | string | No | `""` | Make target: `'pkg1,pkg2'`, `'package-precompiled'`, `'package-recompile'`, or `'package-fullbuild'` |
| `url` | string | No | `""` | URL of config file or empty to use `secrets.ACTIONS_TESTER` |
| `verbosity` | choice | No | `"0"` | Build verbosity level: `0`=quiet, `1`=normal, `2`=verbose |
| `download_toolchain` | boolean | No | `false` | Try to download precompiled toolchain (may fail without AVX2) |
| `custom_device` | string | No | `""` | Override device (e.g., `7530_W6_V1`, `7590_W6`, `6670`) - empty uses matrix toolchains |
| `custom_firmware` | string | No | `""` | Override firmware version (e.g., `08_2X`, `08_0X`, `07_5X`) - empty uses matrix toolchains |
| `custom_lang` | string | No | `""` | Override language (EN or DE) - empty uses matrix toolchains |
| `add_or_override` | choice | No | `"add"` | Add custom config to matrix or override with only custom config |

**Matrix Strategy**:
- Tests packages across all available toolchains (when `add_or_override="add"` or no overrides)
- Tests only custom configuration (when `add_or_override="override"`)
- Maximum 16 parallel jobs
- Fail-fast disabled (continues testing other combinations on failure)
- Each job tests one package-toolchain combination

**Target Suffixes**:
- `package` → `-precompiled` (default)
- `package-precompiled` → Compile precompiled package
- `package-recompile` → Force recompilation from source
- `package-compile` → Standard compilation
- `package-fullbuild` → Build complete firmware (for toolchain packages)

**Behavior**:
- Parses make targets from manual input or commit messages
- Generates build matrix for all toolchain combinations
- Downloads base configuration or uses fallback
- Enables specified packages in configuration
- Builds packages and dependencies
- Reports results with file listings
- Skips gracefully if package cannot be enabled for a toolchain

**Use Cases**:
- Package compatibility testing across toolchains
- Regression testing for package updates
- Dependency validation
- Cross-platform build verification

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
# Create a temporary release with your config file
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
# rm .github/workflows/*  # Remove all workflows (keep make_firmware.yml if desired)

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

### make_firmware.yml Examples

```bash
# Firmware build using myconfig in the workflow directory
gh workflow run make_firmware.yml

# Build with custom config URL (from GitHub Releases)
gh workflow run make_firmware.yml -f url="https://github.com/Ircama/freetz-ng/releases/download/none/default.config"

# Build with custom config URL
gh workflow run make_firmware.yml -f url="https://example.com/myconfig.config"

# Verbose build with toolchain download
gh workflow run make_firmware.yml -f verbosity="2" -f download_toolchain="true"

# Test specific device/firmware/language combination
gh workflow run make_firmware.yml -f custom_device="7590_W5" -f custom_firmware="08_2X" -f custom_lang="DE" -f verbosity="1"
```

### make_package.yml Examples

```bash
# Test single package
gh workflow run make_package.yml -f make_target="php"

# Test multiple packages
gh workflow run make_package.yml -f make_target="php,openssl,libxml2"

# Test with custom config URL (from GitHub Releases)
gh workflow run make_package.yml -f make_target="php" -f url="https://github.com/Ircama/freetz-ng/releases/download/none/default.config"

# Force recompilation with verbose output
gh workflow run make_package.yml -f make_target="patchelf-recompile,ncurses-recompile" -f verbosity="2"

# Full firmware build for toolchain package
gh workflow run make_package.yml -f make_target="gcc-toolchain-fullbuild"

# Test package on specific device/firmware (add to matrix)
gh workflow run make_package.yml -f make_target="php" -f custom_device="6670" -f custom_firmware="07_5X" -f add_or_override="add"

# Test package ONLY on custom configuration (override matrix)
gh workflow run make_package.yml -f make_target="php" -f custom_device="6670" -f custom_firmware="07_5X" -f custom_lang="EN" -f add_or_override="override"
```

## Automatic Triggers

You can trigger workflows automatically by including build commands in commit messages:

```bash
# Single package test
git commit -m "test: make php-recompile"

# Multiple packages test
git commit -m "test: make php-recompile,patchelf-recompile"

# Full firmware build
git commit -m "test: make gcc-toolchain-fullbuild"

# Full build (not supported - will be skipped)
git commit -m "test: make"
```

**Note**: Commits starting with "CI:", "workflow:", "build:" are automatically skipped.

## Supported Patterns

### Target Formats

- `package` → `-precompiled` (default)
- `package-precompiled` → Compile precompiled package
- `package-recompile` → Force recompilation from source
- `package-compile` → Standard compilation
- `package-fullbuild` → Complete firmware build (toolchain packages)

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
gh workflow run make_package.yml -f make_target="gcc-toolchain-fullbuild"

# Test with custom configuration (using uploaded config)
URL="https://github.com/Ircama/freetz-ng/releases/download/none/default.config"
gh workflow run make_firmware.yml -f url="$URL" -f verbosity="2"

# Test with custom configuration (direct URL)
gh workflow run make_firmware.yml -f url="https://example.com/toolchain-test.config" -f verbosity="2"
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
gh workflow run make_firmware.yml -f verbosity="2"
```

### Automatic Triggers
```bash
git commit -m "test: make php-recompile"
```
