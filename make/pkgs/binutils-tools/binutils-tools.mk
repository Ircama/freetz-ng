$(call PKG_INIT_BIN, 2.45.1)
$(PKG)_LIB_VERSION:=$($(PKG)_VERSION)
$(PKG)_SOURCE:=binutils-$($(PKG)_VERSION).tar.xz
$(PKG)_HASH:=5fe101e6fe9d18fdec95962d81ed670fdee5f37e3f48f0bef87bddf862513aa5
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
$(PKG)_SRC_DIR:=$($(PKG)_SRC_BIN:%=$($(PKG)_DIR)/binutils/.libs/%)
$(PKG)_DST_DIR:=$($(PKG)_DST_BIN:%=$($(PKG)_DEST_DIR)/usr/bin/%)
$(PKG)_SEL_DIR:=$($(PKG)_SEL_BIN:%=$($(PKG)_DEST_DIR)/usr/bin/%)
$(PKG)_EXCLUDED:=$(filter-out $($(PKG)_SEL_DIR),$($(PKG)_DST_DIR))

$(PKG)_LIBRARIES_SHORT := libbfd                           libctf           libctf-nobfd           libsframe           libopcodes
$(PKG)_LIBRARIES_NAME  := libbfd-$($(PKG)_LIB_VERSION).so  libctf.so.0.0.0  libctf-nobfd.so.0.0.0  libsframe.so.2.0.0  libopcodes-$($(PKG)_LIB_VERSION).so
$(PKG)_LIBRARIES_DIR   := bfd                              libctf           libctf                 libsframe           opcodes
$(PKG)_LIBRARIES_BUILD_DIR:=$(join $($(PKG)_LIBRARIES_DIR:%=$($(PKG)_DIR)/%/.libs/),$($(PKG)_LIBRARIES_NAME))
$(PKG)_LIBRARIES_TARGET_DIR:=$($(PKG)_LIBRARIES_NAME:%=$($(PKG)_TARGET_LIBDIR)/%)
$(PKG)_LIBRARIES_STAGING_DIR:=$($(PKG)_LIBRARIES_NAME:%=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/%)

$(PKG)_CONFIGURE_OPTIONS += --target=$(REAL_GNU_TARGET_NAME)
$(PKG)_CONFIGURE_OPTIONS += --enable-shared
$(PKG)_CONFIGURE_OPTIONS += --enable-static
$(PKG)_CONFIGURE_OPTIONS += --disable-multilib
$(PKG)_CONFIGURE_OPTIONS += --disable-werror
$(PKG)_CONFIGURE_OPTIONS += --disable-sim
$(PKG)_CONFIGURE_OPTIONS += --disable-gdb
$(PKG)_CONFIGURE_OPTIONS += --without-included-gettext
$(PKG)_CONFIGURE_OPTIONS += --enable-deterministic-archives
# Disable gprofng (requires glibc-only features: dlvsym, Dl_serinfo, RTLD_DI_SERINFOSIZE)
$(PKG)_CONFIGURE_OPTIONS += --disable-gprofng


$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_SRC_DIR) $($(PKG)_LIBRARIES_BUILD_DIR): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(BINUTILS_TOOLS_DIR)

# lazy "install", libraries are only available for this package if binaries are selected
$($(PKG)_LIBRARIES_STAGING_DIR): $($(PKG)_LIBRARIES_BUILD_DIR)
	@for x in $^; do cp -p $$x $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/; done

$(foreach binary,$($(PKG)_SRC_DIR),$(eval $(call INSTALL_BINARY_STRIP_RULE,$(binary),/usr/bin,,$(patsubst %$($(PKG)_SRC_POSTFIX),%,$(binary)))))

$($(PKG)_LIBRARIES_TARGET_DIR): $($(PKG)_TARGET_LIBDIR)/%: $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/%
	$(INSTALL_LIBRARY_STRIP)

$(pkg): $($(PKG)_LIBRARIES_STAGING_DIR)
$($(PKG)_LIBRARIES_SHORT): $(pkg)

$(pkg)-precompiled: $($(PKG)_DST_DIR) $($(PKG)_LIBRARIES_TARGET_DIR)
$(patsubst %,%-precompiled,$($(PKG)_LIBRARIES_SHORT)): $(pkg)-precompiled


$(pkg)-clean:
	-$(SUBMAKE) -C $(BINUTILS_TOOLS_DIR) clean

$(pkg)-clean-staging:
	$(RM) $(BINUTILS_TOOLS_LIBRARIES_STAGING_DIR)

$(pkg)-uninstall:
	$(RM) $(BINUTILS_TOOLS_DST_DIR)
	$(RM) $(BINUTILS_TOOLS_LIBRARIES_TARGET_DIR)

$(call PKG_ADD_LIB,libbfd)
$(call PKG_ADD_LIB,libctf)
$(call PKG_ADD_LIB,libctf-nobfd)
$(call PKG_ADD_LIB,libsframe)
$(call PKG_ADD_LIB,libopcodes)
$(PKG_FINISH)
