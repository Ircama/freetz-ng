$(call PKG_INIT_BIN, 2.72)
$(PKG)_SOURCE:=autoconf-$($(PKG)_VERSION).tar.xz
$(PKG)_HASH:=ba885c1319578d6c94d46e9b0dceb4014caafe2490e437a0dbca3f270a223f5a
$(PKG)_SITE:=https://ftp.gnu.org/gnu/autoconf
### WEBSITE:=https://www.gnu.org/software/autoconf/
### MANPAGE:=https://www.gnu.org/software/autoconf/manual/
### CHANGES:=https://ftp.gnu.org/gnu/autoconf/
### CVSREPO:=https://git.savannah.gnu.org/git/autoconf.git
### SUPPORT:=Ircama

$(PKG)_BINARY:=$($(PKG)_DIR)/bin/autoconf
$(PKG)_TARGET_BINARY:=$($(PKG)_DEST_DIR)/usr/bin/autoconf
$(PKG)_TARGET_MODULES_DIR:=$($(PKG)_DEST_DIR)/usr/share/autoconf
$(PKG)_TARGET_MODULES:=$($(PKG)_TARGET_DIR)/.modules_installed
$(PKG)_CATEGORY:=Debug helpers

$(PKG)_CONFIGURE_OPTIONS += --program-prefix=""

ifneq ($($(PKG)_SOURCE),$(AUTOCONF_HOST_SOURCE))
$(PKG_SOURCE_DOWNLOAD)
endif
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(AUTOTOOLS_DIR)

$($(PKG)_TARGET_BINARY): $($(PKG)_BINARY)
	$(INSTALL_FILE)
	sed -i '1s|.*|#!/usr/bin/microperl|' $(AUTOTOOLS_TARGET_BINARY)

$($(PKG)_TARGET_MODULES): $($(PKG)_DIR)/.configured
	mkdir -p $(AUTOTOOLS_TARGET_MODULES_DIR)/Autom4te
	cp -dpf $(AUTOTOOLS_DIR)/lib/Autom4te/*.pm $(AUTOTOOLS_TARGET_MODULES_DIR)/Autom4te/
	touch $@

$(pkg):

$(pkg)-precompiled: $($(PKG)_TARGET_BINARY) $($(PKG)_TARGET_MODULES)


$(pkg)-clean:
	-$(SUBMAKE) -C $(AUTOTOOLS_DIR) clean

$(pkg)-uninstall:
	$(RM) $(AUTOTOOLS_TARGET_BINARY)
	$(RM) -r $(AUTOTOOLS_TARGET_MODULES_DIR)
	$(RM) $(AUTOTOOLS_TARGET_MODULES)

$(PKG_FINISH)