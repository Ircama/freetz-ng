$(call PKG_INIT_BIN, 2.1.4)
$(PKG)_SOURCE:=$(pkg)-v$($(PKG)_VERSION).tar.gz
$(PKG)_HASH:=c9d76a627839b5f779e21dd49c40762918f47b46197418b3715ec0c52e3c5cb7
$(PKG)_SITE:=https://www.rutschle.net/tech/sslh
### WEBSITE:=https://www.rutschle.net/tech/sslh/README.html
### MANPAGE:=https://www.rutschle.net/tech/sslh/doc/config
### CHANGES:=https://www.rutschle.net/tech/sslh/download.html
### CVSREPO:=https://github.com/yrutschle/sslh
### SUPPORT:=fda77

$(PKG)_BINARY:=$($(PKG)_DIR)/sslh-fork
$(PKG)_TARGET_BINARY:=$($(PKG)_DEST_DIR)/usr/sbin/sslh

$(PKG)_DEPENDS_ON += libconfig pcre2


$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(SSLH_DIR) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		sslh-fork

$($(PKG)_TARGET_BINARY): $($(PKG)_BINARY)
	$(INSTALL_BINARY_STRIP)

$(pkg):

$(pkg)-precompiled: $($(PKG)_TARGET_BINARY)


$(pkg)-clean:
	-$(SUBMAKE) -C $(SSLH_DIR) clean

$(pkg)-uninstall:
	$(RM) $(SSLH_TARGET_BINARY)

$(PKG_FINISH)

