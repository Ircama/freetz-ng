$(call PKG_INIT_BIN, 3.3.0)
$(PKG)_SOURCE:=$(pkg)-$($(PKG)_VERSION)-src.tar.gz
$(PKG)_HASH:=7920f884c2adafc82c8e41c46d6f3d22698785c7b3f56f5677a8d5c866396386
$(PKG)_SITE:=https://www.ncftp.com/downloads/ncftp,https://www.ncftp.com/public_ftp/ncftp/older_versions,https://www.ncftp.com/public_ftp/ncftp
### WEBSITE:=https://www.ncftp.com/ncftp/
### MANPAGE:=https://www.ncftp.com/ncftp/doc/faq.html
### CHANGES:=https://www.ncftp.com/download/
### SUPPORT:=fda77

$(PKG)_BINARIES_ALL := ncftp ncftpget ncftpput ncftpbatch ncftpls
# ncftp is always included
$(PKG)_BINARIES := ncftp $(call PKG_SELECTED_SUBOPTIONS,$($(PKG)_BINARIES_ALL),WITH)
$(PKG)_BINARIES_BUILD_DIR := $($(PKG)_BINARIES:%=$($(PKG)_DIR)/bin/%)
$(PKG)_BINARIES_TARGET_DIR := $($(PKG)_BINARIES:%=$($(PKG)_DEST_DIR)/usr/bin/%)
$(PKG)_EXCLUDED += $(patsubst %,$($(PKG)_DEST_DIR)/usr/bin/%,$(filter-out $($(PKG)_BINARIES),$($(PKG)_BINARIES_ALL)))

$(PKG)_CONFIGURE_ENV += wi_cv_shared_libgcc=yes
$(PKG)_CONFIGURE_ENV += wi_cv_unix_domain_sockets=yes
$(PKG)_CONFIGURE_ENV += wi_cv_look_for_resolv=no
# the values below are the correct ones, they are equal to the guessed ones
$(PKG)_CONFIGURE_ENV += wi_cv_snprintf_terminates=yes
$(PKG)_CONFIGURE_ENV += wi_cv_snprintf_returns_ptr=no
$(PKG)_CONFIGURE_ENV += TARGET_ARCH=$(TARGET_ARCH_ENDIANNESS_DEPENDENT)

$(PKG)_CONFIGURE_OPTIONS += --disable-ccdv
$(PKG)_CONFIGURE_OPTIONS += --without-curses
$(PKG)_CONFIGURE_OPTIONS += --without-ncurses

$(PKG)_CFLAGS := $(TARGET_CFLAGS)
$(PKG)_CFLAGS += -fcommon


ifneq ($(strip $(DL_DIR)/$(NCFTP_SOURCE)), $(strip $(DL_DIR)/$(NCFTP_HOST_SOURCE)))
$(PKG_SOURCE_DOWNLOAD)
endif
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BINARIES_BUILD_DIR): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(NCFTP_DIR) \
		CFLAGS="$(NCFTP_CFLAGS)"

$($(PKG)_BINARIES_TARGET_DIR): $($(PKG)_DEST_DIR)/usr/bin/%: $($(PKG)_DIR)/bin/%
	$(INSTALL_BINARY_STRIP)

$(pkg):

$(pkg)-precompiled: $($(PKG)_BINARIES_TARGET_DIR)


$(pkg)-clean:
	-$(SUBMAKE) -C $(NCFTP_DIR) clean
	$(RM) $(NCFTP_DIR)/.configured

$(pkg)-uninstall:
	$(RM) $(NCFTP_BINARIES_ALL:%=$(NCFTP_DEST_DIR)/usr/bin/%)

$(PKG_FINISH)
