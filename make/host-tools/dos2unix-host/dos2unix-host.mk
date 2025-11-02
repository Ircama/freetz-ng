$(call TOOLS_INIT, 7.5.3)
$(PKG)_SOURCE:=dos2unix-$($(PKG)_VERSION).tar.gz
$(PKG)_HASH:=28a4b0d9f9179da4e44c567b9c01f818b070a20827115fffd96f760dcfa0f3b2
$(PKG)_SITE:=@SF/dos2unix
### WEBSITE:=https://dos2unix.sourceforge.io/
### MANPAGE:=https://waterlan.home.xs4all.nl/dos2unix/man1/dos2unix.htm
### CHANGES:=https://dos2unix.sourceforge.io/dos2unix/NEWS.txt
### CVSREPO:=https://sourceforge.net/p/dos2unix/dos2unix/ci/master/tree/
### SUPPORT:=fda77

$(PKG)_BINARY:=$($(PKG)_DIR)/dos2unix
$(PKG)_TARGET_BINARY:=$(TOOLS_DIR)/dos2unix


$(TOOLS_SOURCE_DOWNLOAD)
$(TOOLS_UNPACKED)
$(TOOLS_CONFIGURED_NOP)

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	$(TOOLS_SUBMAKE) -C $(DOS2UNIX_HOST_DIR)

$($(PKG)_TARGET_BINARY): $($(PKG)_BINARY)
	$(INSTALL_FILE)

$(pkg)-precompiled: $($(PKG)_TARGET_BINARY)


$(pkg)-clean:
	-$(MAKE) -C $(DOS2UNIX_HOST_DIR) clean

$(pkg)-dirclean:
	$(RM) -r $(DOS2UNIX_HOST_DIR)

$(pkg)-distclean: $(pkg)-dirclean
	$(RM) $(DOS2UNIX_HOST_TARGET_BINARY)

$(TOOLS_FINISH)
