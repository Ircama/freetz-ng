$(call PKG_INIT_BIN, 25.10)
$(PKG)_SOURCE:=v$($(PKG)_VERSION).tar.gz
$(PKG)_HASH:=2edaff16dfad9ee372d17d6d01eb2e3d2f8ee8dd4af606b1ee6f045c9b009662
$(PKG)_SITE:=https://github.com/MediaArea/MediaInfo/archive/refs/tags
$(PKG)_DIR:=$(SOURCE_DIR)/MediaInfo-$($(PKG)_VERSION)
### WEBSITE:=https://mediaarea.net/en/MediaInfo
### MANPAGE:=https://mediaarea.net/en/MediaInfo
### CHANGES:=https://github.com/MediaArea/MediaInfo/releases
### CVSREPO:=https://github.com/MediaArea/MediaInfo
### SUPPORT:=Ircama

ZENLIB_VERSION:=0.4.41
MEDIAINFOLIB_VERSION:=25.10

ZENLIB_SOURCE:=ZenLib-v$(ZENLIB_VERSION).tar.gz
ZENLIB_SITE:=https://github.com/MediaArea/ZenLib/archive/refs/tags
ZENLIB_HASH:=45d5173fa0278f5264daa6836ae297aa303984482227d00b35c4f03929494c8f

MEDIAINFOLIB_SOURCE:=MediaInfoLib-v$(MEDIAINFOLIB_VERSION).tar.gz
MEDIAINFOLIB_SITE:=https://github.com/MediaArea/MediaInfoLib/archive/refs/tags
MEDIAINFOLIB_HASH:=e4b2b82f3df8d2c190643d1705ee35c3102674954858d02a2e2b42840f0f07aa

ZENLIB_DIR:=$(SOURCE_DIR)/ZenLib-$(ZENLIB_VERSION)
MEDIAINFOLIB_DIR:=$(SOURCE_DIR)/MediaInfoLib-$(MEDIAINFOLIB_VERSION)

$(PKG)_BINARY:=$($(PKG)_DIR)/Project/GNU/CLI/mediainfo
$(PKG)_BINARY_TARGET:=$($(PKG)_DEST_DIR)/usr/bin/mediainfo

$(PKG)_LIBZEN_BINARY:=$(ZENLIB_DIR)/Project/GNU/Library/.libs/libzen.so.0.0.0
$(PKG)_LIBZEN_STAGING_LIB:=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libzen.so.0.0.0
$(PKG)_LIBZEN_TARGET_LIB:=$($(PKG)_TARGET_LIBDIR)/libzen.so.0.0.0

$(PKG)_LIBMEDIAINFO_BINARY:=$(MEDIAINFOLIB_DIR)/Project/GNU/Library/.libs/libmediainfo.so.0.0.0
$(PKG)_LIBMEDIAINFO_STAGING_LIB:=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libmediainfo.so.0.0.0
$(PKG)_LIBMEDIAINFO_TARGET_LIB:=$($(PKG)_TARGET_LIBDIR)/libmediainfo.so.0.0.0

$(PKG)_CONFIGURE_OPTIONS += --enable-static
$(PKG)_CONFIGURE_OPTIONS += --disable-shared

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)

# Download additional sources
$(DL_DIR)/ZenLib-v$(ZENLIB_VERSION).tar.gz: | $(DL_DIR)
	$(DL_TOOL) -o ZenLib-v$(ZENLIB_VERSION).tar.gz $(DL_DIR) v$(ZENLIB_VERSION).tar.gz $(ZENLIB_SITE) $(ZENLIB_HASH)

$(DL_DIR)/MediaInfoLib-v$(MEDIAINFOLIB_VERSION).tar.gz: | $(DL_DIR)
	$(DL_TOOL) -o MediaInfoLib-v$(MEDIAINFOLIB_VERSION).tar.gz $(DL_DIR) v$(MEDIAINFOLIB_VERSION).tar.gz $(MEDIAINFOLIB_SITE) $(MEDIAINFOLIB_HASH)

# Build ZenLib
$($(PKG)_LIBZEN_BINARY): $(DL_DIR)/ZenLib-v$(ZENLIB_VERSION).tar.gz
	$(call UNPACK_TARBALL,$<,$(SOURCE_DIR))
	(cd $(ZENLIB_DIR)/Project/GNU/Library && \
		./autogen.sh && \
		$(TARGET_CONFIGURE_ENV) \
		./configure \
			--host=$(GNU_TARGET_NAME) \
			--build=$(GNU_HOST_NAME) \
			--prefix=/usr \
			--enable-static \
			--enable-shared && \
		$(SUBMAKE) \
	)

$($(PKG)_LIBZEN_STAGING_LIB): $($(PKG)_LIBZEN_BINARY)
	$(SUBMAKE) -C $(ZENLIB_DIR)/Project/GNU/Library \
		DESTDIR="$(TARGET_TOOLCHAIN_STAGING_DIR)" \
		install
	$(PKG_FIX_LIBTOOL_LA) \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libzen.la

# Build MediaInfoLib
$($(PKG)_LIBMEDIAINFO_BINARY): $(DL_DIR)/MediaInfoLib-v$(MEDIAINFOLIB_VERSION).tar.gz $($(PKG)_LIBZEN_STAGING_LIB)
	$(call UNPACK_TARBALL,$<,$(SOURCE_DIR))
	(cd $(MEDIAINFOLIB_DIR)/Project/GNU/Library && \
		./autogen.sh && \
		CFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		CXXFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		LDFLAGS="-L$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib" \
		PKG_CONFIG_PATH="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig" \
		$(TARGET_CONFIGURE_ENV) \
		./configure \
			--host=$(GNU_TARGET_NAME) \
			--build=$(GNU_HOST_NAME) \
			--prefix=/usr \
			--enable-static \
			--enable-shared && \
		$(SUBMAKE) \
	)

$($(PKG)_LIBMEDIAINFO_STAGING_LIB): $($(PKG)_LIBMEDIAINFO_BINARY)
	$(SUBMAKE) -C $(MEDIAINFOLIB_DIR)/Project/GNU/Library \
		DESTDIR="$(TARGET_TOOLCHAIN_STAGING_DIR)" \
		install
	$(PKG_FIX_LIBTOOL_LA) \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libmediainfo.la

# Build MediaInfo CLI
$(MEDIAINFO_DIR)/.configured: $(MEDIAINFO_DIR)/.unpacked $(MEDIAINFO_LIBMEDIAINFO_STAGING_LIB)
	(cd $(MEDIAINFO_DIR)/Project/GNU/CLI && \
		./autogen.sh && \
		CFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		CXXFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" \
		LDFLAGS="-L$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib" \
		PKG_CONFIG_PATH="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig" \
		$(TARGET_CONFIGURE_ENV) \
		./configure \
			--host=$(GNU_TARGET_NAME) \
			--build=$(GNU_HOST_NAME) \
			--prefix=/usr \
			$(MEDIAINFO_CONFIGURE_OPTIONS) \
	)
	touch $@

$(MEDIAINFO_BINARY): $(MEDIAINFO_DIR)/.configured
	$(SUBMAKE) -C $(MEDIAINFO_DIR)/Project/GNU/CLI

$(MEDIAINFO_BINARY_TARGET): $(MEDIAINFO_BINARY)
	$(INSTALL_BINARY_STRIP)

$($(PKG)_LIBZEN_TARGET_LIB): $($(PKG)_LIBZEN_STAGING_LIB)
	$(INSTALL_LIBRARY_STRIP)

$($(PKG)_LIBMEDIAINFO_TARGET_LIB): $($(PKG)_LIBMEDIAINFO_STAGING_LIB)
	$(INSTALL_LIBRARY_STRIP)

$(pkg):

$(pkg)-precompiled: $($(PKG)_BINARY_TARGET)

ifeq ($(strip $(FREETZ_PACKAGE_MEDIAINFO_STATIC)),y)
$(pkg)-precompiled:
else
$(pkg)-precompiled: $($(PKG)_LIBZEN_TARGET_LIB) $($(PKG)_LIBMEDIAINFO_TARGET_LIB)
endif

$(pkg)-clean:
	-$(SUBMAKE) -C $(ZENLIB_DIR)/Project/GNU/Library clean
	-$(SUBMAKE) -C $(MEDIAINFOLIB_DIR)/Project/GNU/Library clean
	-$(SUBMAKE) -C $($(PKG)_DIR)/Project/GNU/CLI clean
	$(RM) -r \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libzen* \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libmediainfo* \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/ZenLib \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/MediaInfo* \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig/libzen.pc \
		$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig/libmediainfo.pc

$(pkg)-uninstall:
	$(RM) $(MEDIAINFO_BINARY_TARGET) $(MEDIAINFO_LIBZEN_TARGET_LIB) $(MEDIAINFO_LIBMEDIAINFO_TARGET_LIB)

$(PKG_FINISH)