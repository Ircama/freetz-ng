$(call TOOLS_INIT, 5.2.5)
$(PKG)_SOURCE:=xz-$($(PKG)_VERSION).tar.xz
$(PKG)_SOURCE_MD5:=aa1621ec7013a19abab52a8aff04fe5b
$(PKG)_SITE:=http://tukaani.org/xz

$(PKG)_DIR:=$(TOOLS_SOURCE_DIR)/xz-$($(PKG)_VERSION)

$(PKG)_ALONE_DIR:=$($(PKG)_DIR)/src/xz
$(PKG)_LIB_DIR:=$($(PKG)_DIR)/src/liblzma/.libs


$(pkg)-source: $(DL_DIR)/$($(PKG)_SOURCE)
$(DL_DIR)/$($(PKG)_SOURCE): | $(DL_DIR)
	$(DL_TOOL) $(DL_DIR) $(LZMA2_HOST_SOURCE) $(LZMA2_HOST_SITE) $(LZMA2_HOST_SOURCE_MD5)

$(pkg)-unpacked: $($(PKG)_DIR)/.unpacked
$($(PKG)_DIR)/.unpacked: $(DL_DIR)/$($(PKG)_SOURCE) | $(TOOLS_SOURCE_DIR) $(UNPACK_TARBALL_PREREQUISITES)
	mkdir -p $(LZMA2_HOST_DIR)
	$(call UNPACK_TARBALL,$(DL_DIR)/$(LZMA2_HOST_SOURCE),$(TOOLS_SOURCE_DIR))
	$(call APPLY_PATCHES,$(LZMA2_HOST_MAKE_DIR)/patches/$(LZMA2_HOST_VERSION),$(LZMA2_HOST_DIR))
	touch $@

$($(PKG)_DIR)/.configured: $($(PKG)_DIR)/.unpacked
	(cd $(LZMA2_HOST_DIR); $(RM) config.cache; \
		CC="$(TOOLS_CC)" \
		CXX="$(TOOLS_CXX)" \
		CFLAGS="$(TOOLS_CFLAGS)" \
		LDFLAGS="$(TOOLS_LDFLAGS)" \
		./configure \
		--enable-encoders=lzma1,lzma2,delta \
		--enable-decoders=lzma1,lzma2,delta \
		--disable-lzmadec \
		--disable-lzmainfo \
		--disable-lzma-links \
		--disable-scripts \
		--disable-doc \
		--disable-nls \
		--disable-rpath \
		--enable-shared=no \
		--enable-static=yes \
		--without-libiconv-prefix \
		--without-libintl-prefix \
		$(SILENT) \
	);
	touch $@

$($(PKG)_LIB_DIR)/liblzma.a $($(PKG)_ALONE_DIR)/xz: $($(PKG)_DIR)/.configured
	$(TOOLS_SUBMAKE) -C $(LZMA2_HOST_DIR)

$($(PKG)_DIR)/liblzma.a: $($(PKG)_LIB_DIR)/liblzma.a
	$(INSTALL_FILE)

$(TOOLS_DIR)/xz: $($(PKG)_ALONE_DIR)/xz
	$(INSTALL_FILE)

$(pkg)-precompiled: $($(PKG)_DIR)/liblzma.a $(TOOLS_DIR)/xz


$(pkg)-clean:
	-$(MAKE) -C $(LZMA2_HOST_DIR) clean
	$(RM) $(LZMA2_HOST_DIR)/liblzma.a

$(pkg)-dirclean:
	$(RM) -r $(LZMA2_HOST_DIR)

$(pkg)-distclean: $(pkg)-dirclean
	$(RM) $(TOOLS_DIR)/xz

$(TOOLS_FINISH)
