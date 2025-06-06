$(call PKG_INIT_BIN, $(if $(FREETZ_PACKAGE_OPENSSH_VERSION_ABANDON),9.3p2,10.0p1))
$(PKG)_SOURCE:=$(pkg)-$($(PKG)_VERSION).tar.gz
$(PKG)_HASH_ABANDON:=200ebe147f6cb3f101fd0cdf9e02442af7ddca298dffd9f456878e7ccac676e8
$(PKG)_HASH_CURRENT:=021a2e709a0edf4250b1256bd5a9e500411a90dddabea830ed59cef90eb9d85c
$(PKG)_HASH:=$($(PKG)_HASH_$(if $(FREETZ_PACKAGE_OPENSSH_VERSION_ABANDON),ABANDON,CURRENT))
$(PKG)_SITE:=https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable,$(PKG)_SITE:=https://mirror.planetunix.net/pub/OpenBSD/OpenSSH/portable
### WEBSITE:=https://www.openssh.com/
### MANPAGE:=https://www.openssh.com/manual.html
### CHANGES:=https://www.openssh.com/releasenotes.html
### CVSREPO:=https://github.com/openssh/openssh-portable
### SUPPORT:=fda77

$(PKG)_CONDITIONAL_PATCHES+=$(if $(FREETZ_PACKAGE_OPENSSH_VERSION_ABANDON),abandon,current)

$(PKG)_REBUILD_SUBOPTS += FREETZ_OPENSSL_SHORT_VERSION

$(PKG)_BIN_BINARIES             := ssh scp ssh-add ssh-agent ssh-keygen ssh-keysign ssh-keyscan sftp
$(PKG)_BIN_BINARIES_INCLUDED    := $(call PKG_SELECTED_SUBOPTIONS,$($(PKG)_BIN_BINARIES))
$(PKG)_BIN_BINARIES_BUILD_DIR   := $(addprefix $($(PKG)_DIR)/,$($(PKG)_BIN_BINARIES))
$(PKG)_BIN_BINARIES_TARGET_DIR  := $(addprefix $($(PKG)_DEST_DIR)/usr/bin/,$($(PKG)_BIN_BINARIES))

$(PKG)_SBIN_BINARIES            := sshd
$(PKG)_SBIN_BINARIES_INCLUDED   := $(call PKG_SELECTED_SUBOPTIONS,$($(PKG)_SBIN_BINARIES))
$(PKG)_SBIN_BINARIES_BUILD_DIR  := $(addprefix $($(PKG)_DIR)/,$($(PKG)_SBIN_BINARIES))
$(PKG)_SBIN_BINARIES_TARGET_DIR := $(addprefix $($(PKG)_DEST_DIR)/usr/sbin/,$($(PKG)_SBIN_BINARIES))

$(PKG)_LIB_BINARIES             := sftp-server $(if $(FREETZ_PACKAGE_OPENSSH_VERSION_ABANDON),,sshd-auth sshd-session)
$(PKG)_LIB_BINARIES_INCLUDED    := $(call PKG_SELECTED_SUBOPTIONS,$($(PKG)_LIB_BINARIES))
$(PKG)_LIB_BINARIES_BUILD_DIR   := $(addprefix $($(PKG)_DIR)/,$($(PKG)_LIB_BINARIES))
$(PKG)_LIB_BINARIES_TARGET_DIR  := $(addprefix $($(PKG)_DEST_DIR)/usr/lib/,$($(PKG)_LIB_BINARIES))

$(PKG)_DEPENDS_ON += wget-host
$(PKG)_DEPENDS_ON += zlib

# even in '--without-openssl'-mode OpenSSL is still a compile-time
# dependency as some types from it are used throughout the OpenSSH code
$(PKG)_CONFIGURE_OPTIONS += $(if $(FREETZ_PACKAGE_OPENSSH_INTERNAL_CRYPTO),--without-openssl)
$(PKG)_DEPENDS_ON += openssl
$(PKG)_REBUILD_SUBOPTS += FREETZ_OPENSSL_SHORT_VERSION
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_OPENSSH_INTERNAL_CRYPTO

$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_OPENSSH_STATIC

$(PKG)_EXCLUDED += $(addprefix usr/bin/,$(filter-out $($(PKG)_BIN_BINARIES_INCLUDED),$($(PKG)_BIN_BINARIES)))
$(PKG)_EXCLUDED += $(addprefix usr/sbin/,$(filter-out $($(PKG)_SBIN_BINARIES_INCLUDED),$($(PKG)_SBIN_BINARIES)))
$(PKG)_EXCLUDED += $(addprefix usr/lib/,$(filter-out $($(PKG)_LIB_BINARIES_INCLUDED),$($(PKG)_LIB_BINARIES)))
$(PKG)_EXCLUDED += $(if $(FREETZ_PACKAGE_OPENSSH_sshd),,etc/default.openssh etc/init.d/rc.openssh usr/lib/cgi-bin/openssh.cgi)
$(PKG)_EXCLUDED += $(if $(FREETZ_PACKAGE_OPENSSH_INTERNAL_CRYPTO),etc/default.openssh/rsa_key.def etc/default.openssh/dsa_key.def)

$(PKG)_CONFIGURE_OPTIONS += --disable-etc-default-login
$(PKG)_CONFIGURE_OPTIONS += --disable-lastlog
$(PKG)_CONFIGURE_OPTIONS += --disable-utmp
$(PKG)_CONFIGURE_OPTIONS += --disable-utmpx
$(PKG)_CONFIGURE_OPTIONS += --disable-wtmp
$(PKG)_CONFIGURE_OPTIONS += --disable-wtmpx
$(PKG)_CONFIGURE_OPTIONS += --without-bsd-auth
$(PKG)_CONFIGURE_OPTIONS += --without-kerberos5
$(PKG)_CONFIGURE_OPTIONS += --without-pie

$(PKG)_EXTRA_CFLAGS  += -ffunction-sections -fdata-sections
$(PKG)_EXTRA_CFLAGS  += $(if $(FREETZ_TARGET_GCC_4_MAX),-std=c99)
$(PKG)_EXTRA_LDFLAGS += -Wl,--gc-sections
$(PKG)_EXTRA_LDFLAGS += $(if $(FREETZ_PACKAGE_OPENSSH_STATIC),-static)


$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BIN_BINARIES_BUILD_DIR) $($(PKG)_SBIN_BINARIES_BUILD_DIR) $($(PKG)_LIB_BINARIES_BUILD_DIR): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(OPENSSH_DIR) \
		EXTRA_CFLAGS="$(OPENSSH_EXTRA_CFLAGS)" \
		EXTRA_LDFLAGS="$(OPENSSH_EXTRA_LDFLAGS)" \
		all

$(foreach binary,$($(PKG)_BIN_BINARIES_BUILD_DIR),$(eval $(call INSTALL_BINARY_STRIP_RULE,$(binary),/usr/bin)))
$(foreach binary,$($(PKG)_SBIN_BINARIES_BUILD_DIR),$(eval $(call INSTALL_BINARY_STRIP_RULE,$(binary),/usr/sbin)))
$(foreach binary,$($(PKG)_LIB_BINARIES_BUILD_DIR),$(eval $(call INSTALL_BINARY_STRIP_RULE,$(binary),/usr/lib)))

$(pkg):

$(pkg)-precompiled: $($(PKG)_BIN_BINARIES_TARGET_DIR) $($(PKG)_SBIN_BINARIES_TARGET_DIR) $($(PKG)_LIB_BINARIES_TARGET_DIR)


$(pkg)-clean:
	-$(SUBMAKE) -C $(OPENSSH_DIR) clean

$(pkg)-uninstall:
	$(RM) $(OPENSSH_BIN_BINARIES_TARGET_DIR) $(OPENSSH_SBIN_BINARIES_TARGET_DIR) $(OPENSSH_LIB_BINARIES_TARGET_DIR)

$(PKG_FINISH)

