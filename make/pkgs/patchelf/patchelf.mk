$(call PKG_INIT_BIN, 0.18.0)
$(PKG)_SOURCE:=patchelf-$($(PKG)_VERSION).tar.bz2
$(PKG)_HASH:=1952b2a782ba576279c211ee942e341748fdb44997f704dd53def46cd055470b
$(PKG)_SITE:=https://github.com/NixOS/patchelf/releases/download/$($(PKG)_VERSION)
### WEBSITE:=https://github.com/NixOS/patchelf
### MANPAGE:=https://github.com/NixOS/patchelf/blob/master/README.md
### CHANGES:=https://github.com/NixOS/patchelf/releases
### CVSREPO:=https://github.com/NixOS/patchelf
### SUPPORT:=Ircama

$(PKG)_CATEGORY:=Debug helpers

$(PKG)_DEPENDS_ON += $(STDCXXLIB)

$(PKG)_BINARY_BUILD := $($(PKG)_DIR)/src/patchelf
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/patchelf


ifneq ($($(PKG)_SOURCE),$(PATCHELF_HOST_SOURCE))
$(PKG_SOURCE_DOWNLOAD)
endif
$(PKG_UNPACKED)

# Force CXX to real compiler to bypass ccache wrapper issues during cross-compilation
$(PKG)_CONFIGURE_ENV += CXX="$(TARGET_CROSS)g++"
# Fix i686 uClibc linking issue with pthread symbols (6591, 6660 devices)
$(PKG)_CONFIGURE_ENV += $(if $(FREETZ_TARGET_ARCH_X86),CXXFLAGS="$(TARGET_CFLAGS) -fPIC")

$(PKG_CONFIGURED_CONFIGURE)

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
