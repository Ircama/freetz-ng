$(call PKG_INIT_BIN, 0.16.6)
$(PKG)_SOURCE:=$(pkg)-$($(PKG)_VERSION).tar.gz
$(PKG)_HASH:=94e8408a20332cedea45a4b5f09c69f0f0c54581e1b02e1d7f61f46fee3c41f2
$(PKG)_SITE:=https://github.com/rakshasa/rtorrent/releases/download/v$($(PKG)_VERSION)
### WEBSITE:=https://github.com/rakshasa/rtorrent
### MANPAGE:=https://github.com/rakshasa/rtorrent/wiki
### CHANGES:=https://github.com/rakshasa/rtorrent/releases
### CVSREPO:=https://github.com/rakshasa/rtorrent
### SUPPORT:=Ircama

# libTorrent by rakshasa
# (distinct from libtorrent-rasterbar used by qBittorrent/Deluge)
LIBTORRENT_RAKSHASA_VERSION:=0.16.6
LIBTORRENT_SOURCE:=v$(LIBTORRENT_RAKSHASA_VERSION).tar.gz
LIBTORRENT_HASH:=720ff411ef0627a928141cad7f60b171a2fc44fb8700b0914e0072eab1a7be1b
LIBTORRENT_SITE:=https://github.com/rakshasa/libtorrent/archive/refs/tags
LIBTORRENT_DIR:=$(SOURCE_DIR)/libtorrent-$(LIBTORRENT_RAKSHASA_VERSION)

# xmlrpc-c (dependency)
XMLRPC_VERSION:=1.64.03
XMLRPC_SOURCE:=xmlrpc-$(XMLRPC_VERSION).tgz
XMLRPC_HASH:=74729d364edbedbe42e782822da1e076f3f45c65c4278a3cfba5f2342d7cedbe
XMLRPC_SITE:=https://downloads.sourceforge.net/project/xmlrpc-c/Xmlrpc-c%20Super%20Stable/$(XMLRPC_VERSION)
XMLRPC_DIR:=$(SOURCE_DIR)/xmlrpc-$(XMLRPC_VERSION)

# ruTorrent
RUTORRENT_VERSION:=5.2.10
RUTORRENT_SOURCE:=v$(RUTORRENT_VERSION).tar.gz
RUTORRENT_HASH:=a3e57be03f965abcf2ed17125b61ee2bd55a1223fe9226fa1978f3002a93427d
RUTORRENT_SITE:=https://github.com/Novik/ruTorrent/archive/refs/tags
RUTORRENT_DIR:=$(SOURCE_DIR)/ruTorrent-$(RUTORRENT_VERSION)

$(PKG)_BINARY:=$($(PKG)_DIR)/src/rtorrent
$(PKG)_BINARY_TARGET:=$($(PKG)_DEST_DIR)/usr/bin/rtorrent

LIBTORRENT_BINARY:=$(LIBTORRENT_DIR)/src/.libs/libtorrent.so
LIBTORRENT_STAGING_LIB:=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libtorrent.so
LIBTORRENT_TARGET_LIB:=$($(PKG)_TARGET_LIBDIR)/libtorrent.so

# xmlrpc-c has multiple libraries
XMLRPC_LIBS_SHORT := xmlrpc xmlrpc_server xmlrpc_server_abyss xmlrpc_server_cgi xmlrpc_client xmlrpc_abyss xmlrpc_util xmlrpc_xmlparse xmlrpc_xmltok
XMLRPC_BINARY:=$(XMLRPC_DIR)/src/libxmlrpc.so
XMLRPC_STAGING_LIBS:=$(XMLRPC_LIBS_SHORT:%=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/lib%.so)
XMLRPC_TARGET_LIBS:=$(XMLRPC_LIBS_SHORT:%=$($(PKG)_TARGET_LIBDIR)/lib%.so)

$(PKG)_RUTORRENT_WEBDIR:=$($(PKG)_DEST_DIR)/usr/mww/rutorrent

$(PKG)_DEPENDS_ON += curl openssl zlib ncurses expat

$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_RTORRENT_STATIC
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_RTORRENT_WITH_IPV6
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_RTORRENT_WITH_XMLRPC
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_RTORRENT_DAEMON
$(PKG)_REBUILD_SUBOPTS += FREETZ_PACKAGE_RTORRENT_WEBUI

$(PKG)_CONFIGURE_OPTIONS += --host=$(GNU_TARGET_NAME)
$(PKG)_CONFIGURE_OPTIONS += --build=$(GNU_HOST_NAME)
$(PKG)_CONFIGURE_OPTIONS += --prefix=/usr
$(PKG)_CONFIGURE_OPTIONS += --with-ncurses
$(PKG)_CONFIGURE_OPTIONS += --enable-static=$(if $(FREETZ_PACKAGE_RTORRENT_STATIC),yes,no)
$(PKG)_CONFIGURE_OPTIONS += --enable-shared=$(if $(FREETZ_PACKAGE_RTORRENT_STATIC),no,yes)
$(PKG)_CONFIGURE_OPTIONS += $(if $(FREETZ_PACKAGE_RTORRENT_WITH_IPV6),--enable-ipv6,--disable-ipv6)

LIBTORRENT_CONFIGURE_OPTIONS := --host=$(GNU_TARGET_NAME)
LIBTORRENT_CONFIGURE_OPTIONS += --build=$(GNU_HOST_NAME)
LIBTORRENT_CONFIGURE_OPTIONS += --prefix=/usr
LIBTORRENT_CONFIGURE_OPTIONS += --enable-static=$(if $(FREETZ_PACKAGE_RTORRENT_STATIC),yes,no)
LIBTORRENT_CONFIGURE_OPTIONS += --enable-shared=$(if $(FREETZ_PACKAGE_RTORRENT_STATIC),no,yes)
LIBTORRENT_CONFIGURE_OPTIONS += --disable-instrumentation
LIBTORRENT_CONFIGURE_OPTIONS += --enable-aligned

XMLRPC_CONFIGURE_OPTIONS := --host=$(GNU_TARGET_NAME)
XMLRPC_CONFIGURE_OPTIONS += --build=$(GNU_HOST_NAME)
XMLRPC_CONFIGURE_OPTIONS += --prefix=/usr
XMLRPC_CONFIGURE_OPTIONS += --disable-libxml2-backend
XMLRPC_CONFIGURE_OPTIONS += --disable-wininet-client
XMLRPC_CONFIGURE_OPTIONS += --disable-cplusplus

# Intermediate variables to avoid double expansion in shell commands
RTORRENT_PKG_DIR := $($(PKG)_DIR)
RTORRENT_PKG_CONFIGURE_OPTIONS := $($(PKG)_CONFIGURE_OPTIONS)
RTORRENT_PKG_RUTORRENT_WEBDIR := $($(PKG)_RUTORRENT_WEBDIR)
RTORRENT_PKG_MAKE_DIR := $($(PKG)_MAKE_DIR)
RTORRENT_PKG_DEST_DIR := $($(PKG)_DEST_DIR)

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)

# Download additional sources
$(DL_DIR)/v$(LIBTORRENT_RAKSHASA_VERSION).tar.gz: | $(DL_DIR)
	$(DL_TOOL) -o v$(LIBTORRENT_RAKSHASA_VERSION).tar.gz $(DL_DIR) v$(LIBTORRENT_RAKSHASA_VERSION).tar.gz $(LIBTORRENT_SITE) $(LIBTORRENT_HASH)

$(DL_DIR)/xmlrpc-$(XMLRPC_VERSION).tgz: | $(DL_DIR)
	$(DL_TOOL) $(DL_DIR) $(XMLRPC_SOURCE) $(XMLRPC_SITE) $(XMLRPC_HASH)

ifeq ($(strip $(FREETZ_PACKAGE_RTORRENT_WEBUI)),y)
$(DL_DIR)/v$(RUTORRENT_VERSION).tar.gz: | $(DL_DIR)
	$(DL_TOOL) -o v$(RUTORRENT_VERSION).tar.gz $(DL_DIR) v$(RUTORRENT_VERSION).tar.gz $(RUTORRENT_SITE) $(RUTORRENT_HASH)
endif

# Build xmlrpc-c
ifeq ($(strip $(FREETZ_PACKAGE_RTORRENT_WITH_XMLRPC)),y)
$(XMLRPC_BINARY): $(DL_DIR)/xmlrpc-$(XMLRPC_VERSION).tgz
	$(call UNPACK_TARBALL,$<,$(SOURCE_DIR))
	# Build gennmtab for host (used during cross-compilation of xmlrpc-c)
	@echo ">>> Building host gennmtab in $(XMLRPC_DIR)"
	(cd $(XMLRPC_DIR) && \
		./configure \
			--prefix=/usr \
			--disable-libxml2-backend \
			--disable-wininet-client \
			--disable-curl-client \
			--disable-cplusplus && \
		$(MAKE) -C lib/expat/gennmtab gennmtab && \
		mkdir -p tools && \
		cp lib/expat/gennmtab/gennmtab tools/gennmtab-host \
	)
	# Cross-compile with host gennmtab
	@echo ">>> Building xmlrpc-c in $(XMLRPC_DIR)"
	(cd $(XMLRPC_DIR) && \
		$(TARGET_CONFIGURE_ENV) \
		AR="$(TARGET_AR)" \
		RANLIB="$(TARGET_RANLIB)" \
		./configure \
			$(XMLRPC_CONFIGURE_OPTIONS) && \
		find . -name Makefile -exec sed -i "s|../gennmtab/gennmtab|$$PWD/tools/gennmtab-host|g" {} \; && \
		$(MAKE) -j1 \
	)

$(XMLRPC_STAGING_LIBS): $(XMLRPC_BINARY)
	$(SUBMAKE) -C $(XMLRPC_DIR) \
		DESTDIR="$(TARGET_TOOLCHAIN_STAGING_DIR)" \
		install
	# Fix xmlrpc-c-config to use sysroot paths
	sed -i \
		-e 's|HEADERINST_DIR="/usr/include"|HEADERINST_DIR="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include"|' \
		-e 's|LIBINST_DIR="/usr/lib"|LIBINST_DIR="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib"|' \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/xmlrpc-c-config

$(XMLRPC_TARGET_LIBS): $($(PKG)_TARGET_LIBDIR)/lib%.so: $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/lib%.so
	$(INSTALL_LIBRARY_STRIP)
endif

# Build libtorrent
$(LIBTORRENT_BINARY): $(DL_DIR)/v$(LIBTORRENT_RAKSHASA_VERSION).tar.gz
	$(call UNPACK_TARBALL,$<,$(SOURCE_DIR))
	@echo ">>> Building libtorrent in $(LIBTORRENT_DIR)"
	(cd $(LIBTORRENT_DIR) && \
		autoreconf -if && \
		$(TARGET_CONFIGURE_ENV) \
		AR="$(TARGET_AR)" \
		RANLIB="$(TARGET_RANLIB)" \
		CPPFLAGS="-DOPENSSL_API_COMPAT=0x10100000L -I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		LDFLAGS="-L$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib" \
		./configure \
			$(LIBTORRENT_CONFIGURE_OPTIONS) && \
		$(MAKE) \
	)

$(LIBTORRENT_STAGING_LIB): $(LIBTORRENT_BINARY)
	$(SUBMAKE) -C $(LIBTORRENT_DIR) \
		DESTDIR="$(TARGET_TOOLCHAIN_STAGING_DIR)" \
		install
	$(PKG_FIX_LIBTOOL_LA) \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libtorrent.la

$(LIBTORRENT_TARGET_LIB): $(LIBTORRENT_STAGING_LIB)
	$(INSTALL_LIBRARY_STRIP)

# Build rTorrent
ifeq ($(strip $(FREETZ_PACKAGE_RTORRENT_DAEMON)),y)
$($(PKG)_DIR)/.configured: $($(PKG)_DIR)/.unpacked $(LIBTORRENT_STAGING_LIB) $(if $(FREETZ_PACKAGE_RTORRENT_WITH_XMLRPC),$(XMLRPC_STAGING_LIBS))
	@echo ">>> Building rTorrent in $(RTORRENT_PKG_DIR)"
	(cd $(RTORRENT_PKG_DIR) && \
		autoreconf -if && \
		$(TARGET_CONFIGURE_ENV) \
		AR="$(TARGET_AR)" \
		RANLIB="$(TARGET_RANLIB)" \
		CPPFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		CFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		CXXFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		LDFLAGS="-L$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib" \
		PKG_CONFIG_PATH="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig" \
		XMLRPC_C_CONFIG="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/xmlrpc-c-config" \
		./configure \
			$(RTORRENT_PKG_CONFIGURE_OPTIONS) \
	)
	touch $@

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(RTORRENT_PKG_DIR)

$($(PKG)_BINARY_TARGET): $($(PKG)_BINARY)
	$(INSTALL_BINARY_STRIP)
endif

# Install ruTorrent
ifeq ($(strip $(FREETZ_PACKAGE_RTORRENT_WEBUI)),y)
$($(PKG)_RUTORRENT_WEBDIR)/.installed: $(DL_DIR)/v$(RUTORRENT_VERSION).tar.gz
	$(call UNPACK_TARBALL,$(DL_DIR)/v$(RUTORRENT_VERSION).tar.gz,$(SOURCE_DIR))
	mkdir -p $(RTORRENT_PKG_RUTORRENT_WEBDIR)
	# Copy all ruTorrent files including ALL plugins
	cp -a $(RUTORRENT_DIR)/* $(RTORRENT_PKG_RUTORRENT_WEBDIR)/
	# Override settings.php with rTorrent 0.16+ compatible version (removes obsolete to_kb test)
	cp $(RTORRENT_PKG_MAKE_DIR)/files/rutorrent/settings.php $(RTORRENT_PKG_RUTORRENT_WEBDIR)/php/settings.php
	# Remove unnecessary files
	$(RM) -rf $(RTORRENT_PKG_RUTORRENT_WEBDIR)/.git*
	$(RM) -rf $(RTORRENT_PKG_RUTORRENT_WEBDIR)/.github
	$(RM) -f $(RTORRENT_PKG_RUTORRENT_WEBDIR)/.gitignore
	$(RM) -f $(RTORRENT_PKG_RUTORRENT_WEBDIR)/.gitattributes
	# Note: All plugins are enabled by default. Users can disable problematic ones from Settings → Plugins
	# Add include of freetz_config.php to config.php for dynamic SCGI socket configuration
	# Insert after the opening <?php tag and initial comment block
	sed -i '/^<\?php$$/a// Freetz-NG dynamic SCGI configuration\nrequire_once(__DIR__ . "/freetz_config.php");\n' \
		$(RTORRENT_PKG_RUTORRENT_WEBDIR)/conf/config.php
	# Verify plugins directory exists
	@if [ ! -d "$(RTORRENT_PKG_RUTORRENT_WEBDIR)/plugins" ]; then \
		echo "ERROR: ruTorrent plugins directory not found!"; \
		exit 1; \
	fi
	touch $@
endif

$(pkg):

$(pkg)-precompiled: \
	$(if $(FREETZ_PACKAGE_RTORRENT_DAEMON),$($(PKG)_BINARY_TARGET)) \
	$(if $(FREETZ_PACKAGE_RTORRENT_WEBUI),$($(PKG)_RUTORRENT_WEBDIR)/.installed) \
	$(if $(FREETZ_PACKAGE_RTORRENT_STATIC),,$(LIBTORRENT_TARGET_LIB)) \
	$(if $(FREETZ_PACKAGE_RTORRENT_WITH_XMLRPC),$(if $(FREETZ_PACKAGE_RTORRENT_STATIC),,$(XMLRPC_TARGET_LIBS))) \
	$(if $(FREETZ_PACKAGE_RTORRENT_DAEMON),$($(PKG)_DEST_DIR)/root/.rtorrent.rc)

# Install rtorrent configuration template with dynamic storage path
ifeq ($(strip $(FREETZ_PACKAGE_RTORRENT_DAEMON)),y)
$($(PKG)_DEST_DIR)/root/.rtorrent.rc: $($(PKG)_MAKE_DIR)/files/root/.rtorrent.rc
	$(INSTALL_FILE)
	# Replace @MOD_STOR_PREFIX@ with configured storage prefix (default: uStor)
	sed -i 's/@MOD_STOR_PREFIX@/$(or $(FREETZ_MOD_STOR_PREFIX),uStor)/g' \
		$(RTORRENT_PKG_DEST_DIR)/root/.rtorrent.rc
endif

$(pkg)-clean:
	-$(SUBMAKE) -C $(LIBTORRENT_DIR) clean
	-$(SUBMAKE) -C $(XMLRPC_DIR) clean
	-$(SUBMAKE) -C $(RTORRENT_PKG_DIR) clean
	$(RM) -rf \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libtorrent* \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libxmlrpc* \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/torrent \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig/libtorrent.pc \
		$(RUTORRENT_DIR)

$(pkg)-uninstall:
	$(RM) $($(PKG)_BINARY_TARGET)
	$(RM) -r $($(PKG)_RUTORRENT_WEBDIR)
	$(RM) $(LIBTORRENT_TARGET_LIB) $(XMLRPC_TARGET_LIB)

$(PKG_FINISH)
