$(call PKG_INIT_BIN, 20.18.1)
$(PKG)_SOURCE:=node-v$($(PKG)_VERSION).tar.gz
$(PKG)_HASH:=5bad8ced873eef3b32e7daee703156bce9224920ac6044f4232f5393df0628b8
$(PKG)_SITE:=https://nodejs.org/dist/v$($(PKG)_VERSION)
### WEBSITE:=https://nodejs.org/
### MANPAGE:=https://nodejs.org/en/docs/
### CHANGES:=https://nodejs.org/en/blog/
### CVSREPO:=https://github.com/nodejs/node

$(PKG)_BINARY:=$($(PKG)_DIR)/out/Release/node
$(PKG)_TARGET_BINARY:=$($(PKG)_DEST_DIR)/usr/bin/node

$(PKG)_STARTLEVEL=40

$(PKG)_CONFIGURE_DEFOPTS := n

$(PKG)_DEPENDS_ON += python3-host zlib openssl

$(PKG)_CONFIGURE_ENV += CC="$(TARGET_CC)"
$(PKG)_CONFIGURE_ENV += CXX="$(TARGET_CXX)"
$(PKG)_CONFIGURE_ENV += LD="$(TARGET_LD)"
$(PKG)_CONFIGURE_ENV += CFLAGS="$(TARGET_CFLAGS) -I$(TARGET_TOOLCHAIN_STAGING_DIR)/include/c++/$(TARGET_TOOLCHAIN_GCC_VERSION)"
$(PKG)_CONFIGURE_ENV += CXXFLAGS="$(TARGET_CXXFLAGS)"
$(PKG)_CONFIGURE_ENV += LDFLAGS="$(TARGET_LDFLAGS) -lstdc++ -Wl,--as-needed"

$(PKG)_CONFIGURE_OPTIONS += --prefix=/usr
$(PKG)_CONFIGURE_OPTIONS += --cross-compiling
$(PKG)_CONFIGURE_OPTIONS += --dest-cpu=mips
$(PKG)_CONFIGURE_OPTIONS += --dest-os=linux
$(PKG)_CONFIGURE_OPTIONS += --without-intl
$(PKG)_CONFIGURE_OPTIONS += --without-npm
$(PKG)_CONFIGURE_OPTIONS += --shared-zlib
$(PKG)_CONFIGURE_OPTIONS += --shared-openssl
$(PKG)_CONFIGURE_OPTIONS += --without-node-code-cache
$(PKG)_CONFIGURE_OPTIONS += --without-node-snapshot

# Tell gyp to skip building tests and other components that require modern C++ headers
# `tests=0` disables building googletest and many test targets; `node_no_browser` and
# `v8_static_library` reduce V8 host-target complexity.
$(PKG)_CONFIGURE_ENV += GYP_DEFINES="node_no_browser=1 tests=0 v8_no_strict_aliasing=1 v8_static_library=1"

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	@# Patch gyp-generated makefiles to use libstdc++ instead of uClibc++
	@for mk in $$(find $(NODEJS_DIR)/out -name "*.target.mk" 2>/dev/null); do \
		sed -i 's/-luClibc++/ -lstdc++/g' "$$mk"; \
		sed -i 's|-I$(TARGET_TOOLCHAIN_STAGING_DIR)/include/c++/$(TARGET_TOOLCHAIN_GCC_VERSION)/uClibc++|-I$(TARGET_TOOLCHAIN_STAGING_DIR)/include/c++/$(TARGET_TOOLCHAIN_GCC_VERSION)|g' "$$mk"; \
		sed -i "s|-I$(TARGET_TOOLCHAIN_STAGING_DIR)/include/c++/$(TARGET_TOOLCHAIN_GCC_VERSION)/uClibc++||g" "$$mk"; \
	done
	@# Remove test target includes from Makefile to avoid building tests
	@sed -i '/include.*test.*\.mk/d' $(NODEJS_DIR)/out/Makefile 2>/dev/null || true
	$(SUBMAKE) -C $(NODEJS_DIR)

$($(PKG)_TARGET_BINARY): $($(PKG)_BINARY)
	$(INSTALL_BINARY_STRIP)

$(pkg):

$(pkg)-precompiled: $($(PKG)_TARGET_BINARY)

$(pkg)-clean:
	-$(SUBMAKE) -C $(NODEJS_DIR) clean
	$(RM) $(NODEJS_DIR)/.configured

$(pkg)-uninstall:
	$(RM) $($(PKG)_DEST_DIR)/usr/bin/node

$(PKG_FINISH)