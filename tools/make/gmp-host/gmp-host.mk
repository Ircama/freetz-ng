$(call TOOLS_INIT, 6.1.2)
$(PKG)_SOURCE:=gmp-$($(PKG)_VERSION).tar.xz
$(PKG)_SOURCE_SHA256:=87b565e89a9a684fe4ebeeddb8399dce2599f9c9049854ca8c0dfbdea0e21912
$(PKG)_SITE:=@GNU/gmp

$(PKG)_DESTDIR:=$(HOST_TOOLS_DIR)
$(PKG)_BINARY:=$($(PKG)_DESTDIR)/lib/libgmp.a


$(pkg)-source: $(DL_DIR)/$($(PKG)_SOURCE)
$(DL_DIR)/$($(PKG)_SOURCE): | $(DL_DIR)
	$(DL_TOOL) $(DL_DIR) $(GMP_HOST_SOURCE) $(GMP_HOST_SITE) $(GMP_HOST_SOURCE_SHA256)

$(pkg)-unpacked: $($(PKG)_DIR)/.unpacked
$($(PKG)_DIR)/.unpacked: $(DL_DIR)/$($(PKG)_SOURCE) | $(TOOLS_SOURCE_DIR) $(UNPACK_TARBALL_PREREQUISITES)
	$(call UNPACK_TARBALL,$(DL_DIR)/$(GMP_HOST_SOURCE),$(TOOLS_SOURCE_DIR))
	$(call APPLY_PATCHES,$(GMP_HOST_MAKE_DIR)/patches,$(GMP_HOST_DIR))
	touch $@

$($(PKG)_DIR)/.configured: $($(PKG)_DIR)/.unpacked
	(cd $(GMP_HOST_DIR); $(RM) config.cache; \
		CC="$(TOOLCHAIN_HOSTCC)" \
		CFLAGS="$(TOOLCHAIN_HOST_CFLAGS)" \
		$(if $(strip $(FREETZ_TOOLCHAIN_32BIT)),ABI=32) \
		./configure \
		--prefix=$(GMP_HOST_DESTDIR) \
		--build=$(GNU_HOST_NAME) \
		--host=$(GNU_HOST_NAME) \
		--disable-shared \
		--enable-static \
		$(DISABLE_NLS) \
		$(SILENT) \
	)
	touch $@

$($(PKG)_BINARY): $($(PKG)_DIR)/.configured | $(HOST_TOOLS_DIR)
	$(TOOLS_SUBMAKE) -C $(GMP_HOST_DIR) install

$(pkg)-precompiled: $($(PKG)_BINARY)


$(pkg)-clean:
	-$(MAKE) -C $(GMP_HOST_DIR) clean

$(pkg)-dirclean:
	$(RM) -r $(GMP_HOST_DIR)

$(pkg)-distclean: $(pkg)-dirclean
	$(RM) $(GMP_HOST_DESTDIR)/lib/libgmp* $(GMP_HOST_DESTDIR)/include/gmp*.h

$(TOOLS_FINISH)
