$(call PKG_INIT_BIN, 2.41)
$(PKG)_SOURCE:=binutils-$($(PKG)_VERSION).tar.xz
$(PKG)_HASH:=ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450
$(PKG)_SITE:=https://ftp.gnu.org/gnu/binutils,https://mirror.dogado.de/gnu/binutils
### WEBSITE:=https://www.gnu.org/software/binutils/
### MANPAGE:=https://sourceware.org/binutils/docs/
### CHANGES:=https://sourceware.org/binutils/docs-2.41/binutils/
### CVSREPO:=https://sourceware.org/git/binutils-gdb.git
### SUPPORT:=Ircama

$(PKG)_CATEGORY:=Debug helpers

# List of all available binutils tools
$(PKG)_BINUTILS_SIMPLE := readelf objdump objcopy strings ar ranlib addr2line size
$(PKG)_BINUTILS_RENAMED := nm strip

# Selected binutils tools based on user configuration  
$(PKG)_BINUTILS_SIMPLE_SELECTED := $(call PKG_SELECTED_SUBOPTIONS,$($(PKG)_BINUTILS_SIMPLE))
$(PKG)_BINUTILS := $($(PKG)_BINUTILS_SIMPLE_SELECTED)
ifneq ($(strip $(FREETZ_PACKAGE_BINUTILS_TOOLS_NM)),)
$(PKG)_BINUTILS += nm
endif
ifneq ($(strip $(FREETZ_PACKAGE_BINUTILS_TOOLS_STRIP)),)
$(PKG)_BINUTILS += strip
endif

# Build directory paths for binutils tools
$(PKG)_BINUTILS_SIMPLE_BUILD_DIR := $($(PKG)_BINUTILS_SIMPLE:%=$($(PKG)_DIR)/binutils/%)
$(PKG)_BINUTILS_BUILD_DIR := $($(PKG)_BINUTILS_SIMPLE_BUILD_DIR)
$(PKG)_BINUTILS_BUILD_DIR += $(BINUTILS_TOOLS_DIR)/binutils/nm-new
$(PKG)_BINUTILS_BUILD_DIR += $(BINUTILS_TOOLS_DIR)/binutils/strip-new

# Target directory paths for binutils tools
$(PKG)_BINUTILS_TARGET_DIR := $($(PKG)_BINUTILS:%=$($(PKG)_DEST_DIR)/usr/bin/%)

$(PKG)_CONFIGURE_OPTIONS += --target=$(REAL_GNU_TARGET_NAME)
$(PKG)_CONFIGURE_OPTIONS += --disable-shared
$(PKG)_CONFIGURE_OPTIONS += --enable-static
$(PKG)_CONFIGURE_OPTIONS += --disable-multilib
$(PKG)_CONFIGURE_OPTIONS += --disable-werror
$(PKG)_CONFIGURE_OPTIONS += --disable-sim
$(PKG)_CONFIGURE_OPTIONS += --disable-gdb
$(PKG)_CONFIGURE_OPTIONS += --without-included-gettext
$(PKG)_CONFIGURE_OPTIONS += --enable-deterministic-archives


# Standard download and unpack for binutils
$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

# Build all binutils tools together
$($(PKG)_BINUTILS_SIMPLE_BUILD_DIR) $(BINUTILS_TOOLS_DIR)/binutils/nm-new $(BINUTILS_TOOLS_DIR)/binutils/strip-new: $(BINUTILS_TOOLS_DIR)/.configured
	$(SUBMAKE) -C $(BINUTILS_TOOLS_DIR)

# Install binutils simple tools (no rename needed)
$(foreach binary,$($(PKG)_BINUTILS_SIMPLE_BUILD_DIR),$(eval $(call INSTALL_BINARY_STRIP_RULE,$(binary),/usr/bin)))

# Install binutils tools with renamed outputs
ifeq ($(strip $(FREETZ_PACKAGE_BINUTILS_TOOLS_NM)),y)
$(BINUTILS_TOOLS_DEST_DIR)/usr/bin/nm: $(BINUTILS_TOOLS_DIR)/binutils/nm-new
	$(INSTALL_BINARY_STRIP)
endif

ifeq ($(strip $(FREETZ_PACKAGE_BINUTILS_TOOLS_STRIP)),y)
$(BINUTILS_TOOLS_DEST_DIR)/usr/bin/strip: $(BINUTILS_TOOLS_DIR)/binutils/strip-new
	$(INSTALL_BINARY_STRIP)
endif

$(pkg):

$(pkg)-precompiled: $($(PKG)_BINUTILS_TARGET_DIR)


$(pkg)-clean:
	-$(SUBMAKE) -C $(BINUTILS_TOOLS_DIR) clean

$(pkg)-uninstall:
	$(RM) $($(PKG)_BINUTILS_TARGET_DIR)

$(PKG_FINISH)