$(call PKG_INIT_BIN, 43.0.3)
$(PKG)_SOURCE:=cryptography-py3-$($(PKG)_VERSION).tar.gz
$(PKG)_SOURCE_DOWNLOAD_NAME:=cryptography-$($(PKG)_VERSION).tar.gz
$(PKG)_SITE:=https://files.pythonhosted.org/packages/source/c/cryptography
$(PKG)_HASH:=315b9001266a492a6ff443b61238f956b214dbec9910a081ba5b6646a055a805
### WEBSITE:=https://cryptography.io/
### MANPAGE:=https://cryptography.io/en/latest/
### CHANGES:=https://cryptography.io/en/latest/changelog/
### CVSREPO:=https://github.com/pyca/cryptography

$(PKG)_DEPENDS_ON += openssl python3 python3-cffi

$(PKG)_CONDITIONAL_PATCHES+=$(if $(FREETZ_OPENSSL_VERSION_09),openssl-0.9,) \
	$(if $(FREETZ_OPENSSL_VERSION_10),openssl-1.0,) \
	$(if $(FREETZ_OPENSSL_VERSION_11),openssl-1.1,)

# Rebuild Python package from source, with cross-compilation setup
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_PYTHON3_CRYPTOGRAPHY
$(PKG)_CATEGORY:=External (3rd party) modules

# Python 3 build using setuptools with Rust support
$(PKG)_BUILD_PREREQ += python3
$(PKG)_BUILD_PREREQ += cargo

# Cross-compilation environment for Rust
$(PKG)_CARGO_TARGET := mips-unknown-linux-uclibc
$(PKG)_RUSTFLAGS := -C target-cpu=mips32r2 -C opt-level=2

$(PKG)_CONFIGURE_ENV += CARGO_BUILD_TARGET=$($(PKG)_CARGO_TARGET)
$(PKG)_CONFIGURE_ENV += RUSTFLAGS="$($(PKG)_RUSTFLAGS)"
$(PKG)_CONFIGURE_ENV += OPENSSL_DIR="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr"
$(PKG)_CONFIGURE_ENV += OPENSSL_LIB_DIR="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib"
$(PKG)_CONFIGURE_ENV += OPENSSL_INCLUDE_DIR="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include"

# Standard Python 3 cross-compilation variables
$(PKG)_CONFIGURE_ENV += _PYTHON_HOST_PLATFORM=linux-mips
$(PKG)_CONFIGURE_ENV += PYTHONPATH=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages
$(PKG)_CONFIGURE_ENV += _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_mips-linux-uclibc

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_NOP)

$($(PKG)_DIR)/.compiled: $($(PKG)_DIR)/.configured
	$(call HostPython, \
		cd $(PYTHON3_CRYPTOGRAPHY_DIR); \
		$(TARGET_CONFIGURE_ENV) \
		CFLAGS="$(TARGET_CFLAGS) -I$(PYTHON3_STAGING_INC_DIR)" \
		CXXFLAGS="$(TARGET_CFLAGS) -I$(PYTHON3_STAGING_INC_DIR)" \
		$(FREETZ_LD_RUN_PATH) \
		CARGO_BUILD_TARGET="$(PYTHON3_CRYPTOGRAPHY_CARGO_TARGET)" \
		RUSTFLAGS="$(PYTHON3_CRYPTOGRAPHY_RUSTFLAGS)" \
		OPENSSL_DIR="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr" \
		OPENSSL_LIB_DIR="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib" \
		OPENSSL_INCLUDE_DIR="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		PIP_NO_BUILD_ISOLATION=1 \
		, \
		-m pip install --no-build-isolation --no-deps --prefix=/usr --root=$(abspath $(PYTHON3_CRYPTOGRAPHY_DEST_DIR)) . \
	)
	find $(PYTHON3_CRYPTOGRAPHY_DEST_DIR)$(PYTHON3_SITE_PKG_DIR) -type f -name "*.so" -exec $(TARGET_STRIP) \{\} \+ || true
	@touch $@

$(pkg):

$(pkg)-precompiled: $($(PKG)_DIR)/.compiled

$(pkg)-clean:
	-$(RM) -r $(PYTHON3_CRYPTOGRAPHY_DIR)/.configured
	-$(RM) -r $(PYTHON3_CRYPTOGRAPHY_DIR)/.compiled
	-$(RM) -r $(PYTHON3_CRYPTOGRAPHY_DIR)/build

$(pkg)-uninstall:
	$(RM) -r $(PYTHON3_CRYPTOGRAPHY_DEST_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/cryptography
	$(RM) -r $(PYTHON3_CRYPTOGRAPHY_DEST_DIR)/usr/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/cryptography-$(PYTHON3_CRYPTOGRAPHY_VERSION)*.egg-info

$(PKG_FINISH)
