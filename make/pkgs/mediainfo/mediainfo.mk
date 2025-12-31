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

ZENLIB_DIR:=$(shell if [ -d "$(SOURCE_DIR)/ZenLib-$(ZENLIB_VERSION)/ZenLib-$(ZENLIB_VERSION)" ]; then echo "$(SOURCE_DIR)/ZenLib-$(ZENLIB_VERSION)/ZenLib-$(ZENLIB_VERSION)"; else echo "$(SOURCE_DIR)/ZenLib-$(ZENLIB_VERSION)"; fi)
MEDIAINFOLIB_DIR:=$(shell if [ -d "$(SOURCE_DIR)/MediaInfoLib-$(MEDIAINFOLIB_VERSION)/MediaInfoLib-$(MEDIAINFOLIB_VERSION)" ]; then echo "$(SOURCE_DIR)/MediaInfoLib-$(MEDIAINFOLIB_VERSION)/MediaInfoLib-$(MEDIAINFOLIB_VERSION)"; else echo "$(SOURCE_DIR)/MediaInfoLib-$(MEDIAINFOLIB_VERSION)"; fi)

$(PKG)_BINARY := $($(PKG)_DIR)/Project/GNU/CLI/mediainfo
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/mediainfo

$(PKG)_LIBZEN_BINARY:=$(ZENLIB_DIR)/Project/GNU/Library/src/libzen.la
$(PKG)_LIBZEN_STAGING_LIB:=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libzen.so.0.0.0
$(PKG)_LIBZEN_TARGET_LIB:=$($(PKG)_TARGET_LIBDIR)/libzen.so.0.0.0

$(PKG)_LIBMEDIAINFO_BINARY:=$(MEDIAINFOLIB_DIR)/Project/GNU/Library/src/libmediainfo.la
$(PKG)_LIBMEDIAINFO_STAGING_LIB:=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libmediainfo.so.0.0.0
$(PKG)_LIBMEDIAINFO_TARGET_LIB:=$($(PKG)_TARGET_LIBDIR)/libmediainfo.so.0.0.0

$(PKG)_CONFIGURE_OPTIONS += --enable-static
$(PKG)_CONFIGURE_OPTIONS += --disable-shared

$(PKG_SOURCE_DOWNLOAD)

$(DL_DIR)/ZenLib-v$(ZENLIB_VERSION).tar.gz: | $(DL_DIR)
	$(DL_TOOL) -o ZenLib-v$(ZENLIB_VERSION).tar.gz $(DL_DIR) v$(ZENLIB_VERSION).tar.gz $(ZENLIB_SITE) $(ZENLIB_HASH)

$(DL_DIR)/MediaInfoLib-v$(MEDIAINFOLIB_VERSION).tar.gz: | $(DL_DIR)
	$(DL_TOOL) -o MediaInfoLib-v$(MEDIAINFOLIB_VERSION).tar.gz $(DL_DIR) v$(MEDIAINFOLIB_VERSION).tar.gz $(MEDIAINFOLIB_SITE) $(MEDIAINFOLIB_HASH)

$(PKG_UNPACKED)

$(ZENLIB_DIR)/.unpacked: $(DL_DIR)/ZenLib-v$(ZENLIB_VERSION).tar.gz
	mkdir -p $(ZENLIB_DIR)
	$(call UNPACK_TARBALL,$<,$(ZENLIB_DIR))
	touch $@

$(MEDIAINFOLIB_DIR)/.unpacked: $(DL_DIR)/MediaInfoLib-v$(MEDIAINFOLIB_VERSION).tar.gz
	mkdir -p $(MEDIAINFOLIB_DIR)
	$(call UNPACK_TARBALL,$<,$(MEDIAINFOLIB_DIR))
	touch $@

$(ZENLIB_DIR)/.configured: $(ZENLIB_DIR)/.unpacked
	@zen_cfg="$$(find $(ZENLIB_DIR) -maxdepth 4 -type f -name configure -print -quit)"; \
	if [ -n "$$zen_cfg" ]; then \
		zen_dir="$$(dirname $$zen_cfg)"; \
	else \
		zen_ag="$$(find $(ZENLIB_DIR) -maxdepth 5 -type f -name autogen.sh -print -quit)"; \
		if [ -n "$$zen_ag" ]; then zen_dir="$$(dirname $$zen_ag)"; else zen_dir="$(ZENLIB_DIR)"; fi; \
	fi; \
	( cd "$$zen_dir"; if [ ! -f ./configure -a -f ./autogen.sh ]; then ./autogen.sh || true; fi; if [ ! -f ./configure ]; then autoreconf -fi || true; fi; $(TARGET_CONFIGURE_ENV) \
		./configure \
		--host=$(GNU_TARGET_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=/usr \
		--enable-static \
		--enable-shared \
	)
	touch $@

$(MEDIAINFOLIB_DIR)/.configured: $(MEDIAINFOLIB_DIR)/.unpacked $(ZENLIB_DIR)/.configured $($(PKG)_LIBZEN_STAGING_LIB)
	@milib_cfg="$$(find $(MEDIAINFOLIB_DIR) -maxdepth 5 -type f -name configure -print -quit)"; \
	if [ -n "$$milib_cfg" ]; then \
		milib_dir="$$(dirname $$milib_cfg)"; \
	else \
		milib_ag="$$(find $(MEDIAINFOLIB_DIR) -maxdepth 6 -type f -name autogen.sh -print -quit)"; \
		if [ -n "$$milib_ag" ]; then milib_dir="$$(dirname $$milib_ag)"; else milib_dir="$(MEDIAINFOLIB_DIR)"; fi; \
	fi; \
	( cd "$$milib_dir"; if [ ! -f ./configure -a -f ./autogen.sh ]; then ./autogen.sh || true; fi; if [ ! -f ./configure ]; then autoreconf -fi || true; fi; CFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" LDFLAGS="-L$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib" PKG_CONFIG_PATH="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig" $(TARGET_CONFIGURE_ENV) \
		./configure \
		--host=$(GNU_TARGET_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=/usr \
		--enable-static \
		--enable-shared \
	)
	touch $@

$($(PKG)_DIR)/.configured: $($(PKG)_DIR)/.unpacked $(MEDIAINFOLIB_DIR)/.configured $($(PKG)_LIBMEDIAINFO_STAGING_LIB)
	@mi_cfg="$$(find $($(PKG)_DIR) -maxdepth 6 -type f -name configure -print -quit)"; \
	if [ -n "$$mi_cfg" ]; then \
		mi_dir="$$(dirname $$mi_cfg)"; \
	else \
		mi_ag="$$(find $($(PKG)_DIR) -maxdepth 8 -type f -name autogen.sh -print -quit)"; \
		if [ -n "$$mi_ag" ]; then mi_dir="$$(dirname $$mi_ag)"; else mi_dir="$($(PKG)_DIR)"; fi; \
	fi; \
	( cd "$$mi_dir"; if [ -f ./autogen.sh ] && ([ ! -f ./configure ] || [ ! -f ./config.guess ] || [ ! -f ./config.sub ] || [ ! -f ./install-sh ] || [ ! -f ./ltmain.sh ]); then ./autogen.sh || true; fi; if [ ! -f ./config.guess ] || [ ! -f ./config.sub ] || [ ! -f ./install-sh ] || [ ! -f ./ltmain.sh ]; then autoreconf -fi || true; fi; if [ ! -f ./configure ]; then autoreconf -fi || true; fi; CFLAGS="-I$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" LDFLAGS="-L$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib" PKG_CONFIG_PATH="$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig" $(TARGET_CONFIGURE_ENV) \
		./configure \
		--host=$(GNU_TARGET_NAME) \
		--build=$(GNU_HOST_NAME) \
		--prefix=/usr \
		--enable-static \
		--disable-shared \
	; sed -i 's|../../../Project/GNU/Library/src/libmediainfo.la|-lmediainfo|' Makefile \
	)
	touch $@

$($(PKG)_LIBZEN_BINARY): $(ZENLIB_DIR)/.configured
	@libdir="$$(find $(ZENLIB_DIR) -maxdepth 8 -type f -path '*/Project/GNU/Library/Makefile' -print -quit)"; \
	if [ -n "$$libdir" ]; then \
		libdir="$$(dirname $$libdir)"; \
	else \
		libdir="$(ZENLIB_DIR)/Project/GNU/Library"; \
	fi; \
	$(SUBMAKE) -C "$$libdir"

$($(PKG)_LIBZEN_STAGING_LIB): $($(PKG)_LIBZEN_BINARY)
	mkdir -p $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib
	mkdir -p $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include
	mkdir -p $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig
	@libdir="$$(find $(ZENLIB_DIR) -maxdepth 8 -type f -name libzen.la -print -quit)"; \
	if [ -n "$$libdir" ]; then \
		libdir="$$(dirname $$libdir)"; \
	else \
		libdir="$(ZENLIB_DIR)/Project/GNU/Library"; \
	fi; \
	cp -a "$$libdir"/.libs/libzen.{a,so*} $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/ 2>/dev/null || true; \
	cp -a "$$libdir"/libzen.la $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/ 2>/dev/null || true
	$(PKG_FIX_LIBTOOL_LA) $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libzen.la
	# install ZenLib headers under usr/include/ZenLib so includes like "ZenLib/Conf.h" work
	mkdir -p $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/ZenLib
	cp -a $(ZENLIB_DIR)/Source/ZenLib $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/ 2>/dev/null || true
	@pcfile="$$(find $(ZENLIB_DIR) -maxdepth 8 -type f -name libzen.pc -print -quit)"; \
	if [ -n "$$pcfile" ]; then \
		cp -a "$$pcfile" $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig/ 2>/dev/null || true; \
	fi

$($(PKG)_LIBMEDIAINFO_BINARY): $(MEDIAINFOLIB_DIR)/.configured
	@libdir="$$(find $(MEDIAINFOLIB_DIR) -maxdepth 8 -type f -path '*/Project/GNU/Library/Makefile' -print -quit)"; \
	if [ -n "$$libdir" ]; then \
		libdir="$$(dirname $$libdir)"; \
	else \
		libdir="$(MEDIAINFOLIB_DIR)/Project/GNU/Library"; \
	fi; \
	$(SUBMAKE) -C "$$libdir"

$($(PKG)_LIBMEDIAINFO_STAGING_LIB): $($(PKG)_LIBMEDIAINFO_BINARY)
	mkdir -p $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib
	mkdir -p $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include
	mkdir -p $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig
	@mlibdir="$$(find $(MEDIAINFOLIB_DIR) -maxdepth 8 -type f -name libmediainfo.la -print -quit)"; \
	if [ -n "$$mlibdir" ]; then \
		mlibdir="$$(dirname $$mlibdir)"; \
	else \
		mlibdir="$(MEDIAINFOLIB_DIR)/Project/GNU/Library"; \
	fi; \
	cp -a "$$mlibdir"/.libs/libmediainfo.{a,so*} $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/ 2>/dev/null || true; \
	cp -a "$$mlibdir"/libmediainfo.la $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/ 2>/dev/null || true
	$(PKG_FIX_LIBTOOL_LA) $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/libmediainfo.la
	# install MediaInfo headers (copy whole directories to preserve structure)
	mkdir -p $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include
	cp -a $(MEDIAINFOLIB_DIR)/Source/MediaInfo $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/ 2>/dev/null || true
	cp -a $(MEDIAINFOLIB_DIR)/Source/MediaInfoDLL $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/ 2>/dev/null || true
	cp -a "$$mlibdir"/libmediainfo.pc $(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/pkgconfig/ 2>/dev/null || true

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured $($(PKG)_LIBMEDIAINFO_BINARY)
	@clid="$$(find $($(PKG)_DIR) -maxdepth 10 -type f -path '*/Project/GNU/CLI/Makefile' -print -quit)"; \
	if [ -n "$$clid" ]; then \
		clid="$$(dirname $$clid)"; \
	else \
		clid="$($(PKG)_DIR)/Project/GNU/CLI"; \
	fi; \
	$(SUBMAKE) -C "$$clid"

$($(PKG)_BINARY_TARGET): $($(PKG)_BINARY)
	$(INSTALL_BINARY_STRIP)

$($(PKG)_LIBZEN_TARGET_LIB): $($(PKG)_LIBZEN_BINARY)
	$(INSTALL_LIBRARY_STRIP)

$($(PKG)_LIBMEDIAINFO_TARGET_LIB): $($(PKG)_LIBMEDIAINFO_BINARY)
	$(INSTALL_LIBRARY_STRIP)

$(pkg):

$(pkg)-precompiled: $($(PKG)_BINARY_TARGET) $($(PKG)_LIBZEN_TARGET_LIB) $($(PKG)_LIBMEDIAINFO_TARGET_LIB)

$(pkg)-clean:
	$(RM) $($(PKG)_BINARY_TARGET) $($(PKG)_LIBZEN_TARGET_LIB) $($(PKG)_LIBMEDIAINFO_TARGET_LIB)

$(pkg)-uninstall:
	$(RM) $($(PKG)_BINARY_TARGET) $($(PKG)_LIBZEN_TARGET_LIB) $($(PKG)_LIBMEDIAINFO_TARGET_LIB)

$(PKG_FINISH)