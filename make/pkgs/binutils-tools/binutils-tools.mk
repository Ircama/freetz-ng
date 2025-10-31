$(call PKG_INIT_BIN, 2.45)
$(PKG)_SOURCE:=binutils-$($(PKG)_VERSION).tar.xz
$(PKG)_HASH:=c50c0e7f9cb188980e2cc97e4537626b1672441815587f1eab69d2a1bfbef5d2
$(PKG)_SITE:=@GNU/binutils
### WEBSITE:=https://www.gnu.org/software/binutils/
### MANPAGE:=https://sourceware.org/binutils/docs/
### CHANGES:=https://sourceware.org/git/gitweb.cgi?p=binutils-gdb.git;a=blob_plain;f=binutils/NEWS
### CVSREPO:=https://sourceware.org/git/binutils-gdb.git
### SUPPORT:=Ircama

$(PKG)_CATEGORY:=Debug helpers

$(PKG)_SRC_POSTFIX:=-new
$(PKG)_SRC_BIN:=ar addr2line nm-new objcopy objdump ranlib readelf size strings strip-new
$(PKG)_DST_BIN:=$(patsubst %$($(PKG)_SRC_POSTFIX),%,$($(PKG)_SRC_BIN))
$(PKG)_SEL_BIN:=$(call PKG_SELECTED_SUBOPTIONS,$($(PKG)_DST_BIN))
$(PKG)_SRC_DIR:=$($(PKG)_SRC_BIN:%=$($(PKG)_DIR)/binutils/%)
$(PKG)_DST_DIR:=$($(PKG)_DST_BIN:%=$($(PKG)_DEST_DIR)/usr/bin/%)
$(PKG)_SEL_DIR:=$($(PKG)_SEL_BIN:%=$($(PKG)_DEST_DIR)/usr/bin/%)
$(PKG)_EXCLUDED:=$(filter-out $($(PKG)_SEL_DIR),$($(PKG)_DST_DIR))

$(PKG)_CONFIGURE_OPTIONS += --target=$(REAL_GNU_TARGET_NAME)
$(PKG)_CONFIGURE_OPTIONS += --disable-shared
$(PKG)_CONFIGURE_OPTIONS += --enable-static
$(PKG)_CONFIGURE_OPTIONS += --disable-multilib
$(PKG)_CONFIGURE_OPTIONS += --disable-werror
$(PKG)_CONFIGURE_OPTIONS += --disable-sim
$(PKG)_CONFIGURE_OPTIONS += --disable-gdb
$(PKG)_CONFIGURE_OPTIONS += --without-included-gettext
$(PKG)_CONFIGURE_OPTIONS += --enable-deterministic-archives
# Disable gprofng (requires glibc-only features: dlvsym, Dl_serinfo, RTLD_DI_SERINFOSIZE)
# Not useful for embedded devices, only adds build complexity
$(PKG)_CONFIGURE_OPTIONS += --disable-gprofng


$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_SRC_DIR): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(BINUTILS_TOOLS_DIR)

$(foreach binary,$($(PKG)_SRC_DIR),$(eval $(call INSTALL_BINARY_STRIP_RULE,$(binary),/usr/bin,,$(patsubst %$($(PKG)_SRC_POSTFIX),%,$(binary)))))

$(pkg):

$(pkg)-precompiled: $($(PKG)_DST_DIR)


$(pkg)-clean:
	-$(SUBMAKE) -C $(BINUTILS_TOOLS_DIR) clean

$(pkg)-uninstall:
	$(RM) $(BINUTILS_TOOLS_DST_DIR)

$(PKG_FINISH)
