$(call PKG_INIT_BIN, 5.46)
$(PKG)_SOURCE:=$(pkg)-$($(PKG)_VERSION).tar.gz
$(PKG)_HASH:=c9cc77c7c560c543135edc555af609d5619dbef011997e988ce40a3d75d86088
$(PKG)_SITE:=http://ftp.astron.com/pub/file,ftp://ftp.astron.com/pub/file
### WEBSITE:=https://www.darwinsys.com/file/
### MANPAGE:=https://linux.die.net/man/1/file
### CHANGES:=http://ftp.astron.com/pub/file
### CVSREPO:=https://github.com/file/file
### SUPPORT:=Ircama

$(PKG)_CATEGORY:=Debug helpers

$(PKG)_BINARY_BUILD := $($(PKG)_DIR)/src/file
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/file

$(PKG)_MAGIC_BUILD := $($(PKG)_DIR)/magic/magic.mgc
$(PKG)_MAGIC_TARGET := $($(PKG)_DEST_DIR)/usr/share/misc/magic.mgc

$(PKG)_DEPENDS_ON += file-host

$(PKG)_CONFIGURE_OPTIONS += --enable-static
$(PKG)_CONFIGURE_OPTIONS += --disable-shared
$(PKG)_CONFIGURE_OPTIONS += --enable-elf
$(PKG)_CONFIGURE_OPTIONS += --enable-elf-core
$(PKG)_CONFIGURE_OPTIONS += --disable-zlib
$(PKG)_CONFIGURE_OPTIONS += --disable-bzlib
$(PKG)_CONFIGURE_OPTIONS += --disable-xzlib
$(PKG)_CONFIGURE_OPTIONS += --disable-zstdlib
$(PKG)_CONFIGURE_OPTIONS += --disable-lzlib
$(PKG)_CONFIGURE_OPTIONS += --disable-libseccomp


ifneq ($($(PKG)_SOURCE),$(FILE_HOST_SOURCE))
$(PKG_SOURCE_DOWNLOAD)
endif
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BINARY_BUILD) $($(PKG)_MAGIC_BUILD): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(FILE_DIR)

$($(PKG)_BINARY_TARGET): $($(PKG)_BINARY_BUILD)
	$(INSTALL_BINARY_STRIP)

$($(PKG)_MAGIC_TARGET): $($(PKG)_MAGIC_BUILD)
	$(INSTALL_FILE)

$(pkg):

$(pkg)-precompiled: $($(PKG)_BINARY_TARGET) $($(PKG)_MAGIC_TARGET)


$(pkg)-clean:
	-$(SUBMAKE) -C $(FILE_DIR) clean

$(pkg)-uninstall:
	$(RM) $($(PKG)_BINARY_TARGET)
	$(RM) $($(PKG)_MAGIC_TARGET)

$(PKG_FINISH)
