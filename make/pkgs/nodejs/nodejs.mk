$(call PKG_INIT_BIN, 18.20.8)
$(PKG)_SOURCE:=node-v$($(PKG)_VERSION).tar.gz
$(PKG)_HASH:=ec60a6d2344ef9e1f093991ca1bb6bbe92c61c29d1762c4b99e08f87dbb91e2f
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

$(PKG)_CONDITIONAL_PATCHES += $($(PKG)_VERSION)

$(PKG)_CONFIGURE_ENV += CC="$(TARGET_CC)"
$(PKG)_CONFIGURE_ENV += CXX="$(TARGET_TOOLCHAIN_STAGING_DIR)/bin/$(TARGET_ARCH)-linux-uclibc-g++"
$(PKG)_CONFIGURE_ENV += LD="$(TARGET_LD)"
$(PKG)_CONFIGURE_ENV += PATH="$(TARGET_TOOLCHAIN_PATH):$(PATH)"
$(PKG)_CONFIGURE_ENV += CFLAGS="$(TARGET_CFLAGS)"
$(PKG)_CONFIGURE_ENV += CXXFLAGS="$(TARGET_CXXFLAGS)"
$(PKG)_CONFIGURE_ENV += LDFLAGS="$(TARGET_LDFLAGS) -lstdc++ -Wl,--as-needed"

# Map Freetz TARGET_ARCH to Node.js dest-cpu values
# Freetz uses: mips, mipsel, arm, armeb, x86_64, i686, powerpc, etc.
# Node.js expects: mips, mipsel, arm, arm64, x64, ia32, ppc, ppc64, etc.
ifeq ($(strip $(TARGET_ARCH)),mips)
NODEJS_DEST_CPU := mips
else ifeq ($(strip $(TARGET_ARCH)),mipsel)
NODEJS_DEST_CPU := mipsel
else ifeq ($(strip $(TARGET_ARCH)),arm)
NODEJS_DEST_CPU := arm
else ifeq ($(strip $(TARGET_ARCH)),armv7)
NODEJS_DEST_CPU := arm
else ifeq ($(strip $(TARGET_ARCH)),aarch64)
NODEJS_DEST_CPU := arm64
else ifeq ($(strip $(TARGET_ARCH)),x86_64)
NODEJS_DEST_CPU := x64
else ifeq ($(strip $(TARGET_ARCH)),i686)
NODEJS_DEST_CPU := ia32
else ifeq ($(strip $(TARGET_ARCH)),powerpc)
NODEJS_DEST_CPU := ppc
else
$(error Unsupported TARGET_ARCH=$(TARGET_ARCH) for Node.js build)
endif

$(PKG)_CONFIGURE_OPTIONS += --prefix=/usr
$(PKG)_CONFIGURE_OPTIONS += --cross-compiling
$(PKG)_CONFIGURE_OPTIONS += --dest-cpu=$(NODEJS_DEST_CPU)
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
# For soft-float MIPS: disable FPU instructions and set appropriate flags
$(PKG)_CONFIGURE_ENV += GYP_DEFINES="node_no_browser=1 tests=0 v8_no_strict_aliasing=1 v8_static_library=1 v8_can_use_fpu_instructions=0 v8_use_mips_abi_hardfloat=0"

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)

# Custom configure target for Node.js (doesn't use --quiet which gyp doesn't understand)
$($(PKG)_DIR)/.configured: $($(PKG)_DIR)/.unpacked
	cd $(NODEJS_DIR) && \
		$(NODEJS_CONFIGURE_ENV) \
		./configure $(NODEJS_CONFIGURE_OPTIONS)
	touch $@

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	@# Patch gyp-generated makefiles to use libstdc++ instead of uClibc++
	@for mk in $$(find $(NODEJS_DIR)/out -name "*.target.mk" -o -name "*.host.mk" 2>/dev/null); do \
		sed -i 's/-luClibc++/ -lstdc++/g' "$$mk"; \
		sed -i 's|-I$(TARGET_TOOLCHAIN_STAGING_DIR)/include/c++/$(TARGET_TOOLCHAIN_GCC_VERSION)/uClibc++||g' "$$mk"; \
		sed -i 's|-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/uClibc++||g' "$$mk"; \
		sed -i 's|GYP_CXXFLAGS :=.*|& -I$(TARGET_TOOLCHAIN_STAGING_DIR)/include/c++/$(TARGET_TOOLCHAIN_GCC_VERSION)/$(TARGET_ARCH)-linux-uclibc -I$(TARGET_TOOLCHAIN_STAGING_DIR)/include/c++/$(TARGET_TOOLCHAIN_GCC_VERSION)|g' "$$mk"; \
		sed -i 's|$$(obj)\.target/deps/googletest/gtest_prod\.stamp||g' "$$mk"; \
	done
	@# Remove test and gtest related targets from Makefile
	@sed -i '/include.*test.*\.mk/d' $(NODEJS_DIR)/out/Makefile 2>/dev/null || true
	@sed -i '/include.*deps\/googletest.*\.mk/d' $(NODEJS_DIR)/out/Makefile 2>/dev/null || true
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