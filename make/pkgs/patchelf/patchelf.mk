$(call PKG_INIT_BIN, 0.18.0)
$(PKG)_SOURCE:=patchelf-$($(PKG)_VERSION).tar.bz2
$(PKG)_HASH:=e9dc4d53c2db7a31fd2c0d0e4b0e6b89d2d87e3fb1ba92b001f8f32432bb3444
$(PKG)_SITE:=https://github.com/NixOS/patchelf/releases/download/$($(PKG)_VERSION)
### WEBSITE:=https://github.com/NixOS/patchelf
### MANPAGE:=https://github.com/NixOS/patchelf/blob/master/README.md
### CHANGES:=https://github.com/NixOS/patchelf/releases
### CVSREPO:=https://github.com/NixOS/patchelf
### SUPPORT:=Ircama

$(PKG)_CATEGORY:=Debug helpers

$(PKG)_BINARY_BUILD := $($(PKG)_DIR)/src/patchelf
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/patchelf


$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)

# Patchelf configuration - bypass wrapper to use libstdc++ instead of uClibc++
# Use dynamic linking with libstdc++ from /usr/lib/freetz (RPATH already configured in libstdcxx package)
$($(PKG)_DIR)/.configured: $($(PKG)_DIR)/.unpacked | $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libc.a
	(cd $(PATCHELF_DIR); \
		$(AUTORECONF) \
		rm -f config.cache; \
		$(TARGET_CONFIGURE_ENV) \
		CXX="$(TARGET_CROSS)g++" \
		./configure \
		$(TARGET_CONFIGURE_OPTIONS) \
	);
	touch $@

$($(PKG)_BINARY_BUILD): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(PATCHELF_DIR)

$($(PKG)_BINARY_TARGET): $($(PKG)_BINARY_BUILD)
	$(INSTALL_BINARY_STRIP)

$(pkg):

$(pkg)-precompiled: $($(PKG)_BINARY_TARGET)


$(pkg)-clean:
	-$(SUBMAKE) -C $(PATCHELF_DIR) clean

$(pkg)-uninstall:
	$(RM) $(PATCHELF_BINARY_TARGET)

$(PKG_FINISH)
