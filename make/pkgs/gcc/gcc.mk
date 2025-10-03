$(call PKG_INIT_BIN, $(call qstrip,$(FREETZ_TARGET_GCC_VERSION)))
$(PKG)_CATEGORY:=Debug helpers

# Use the same GCC version as the toolchain
$(PKG)_VERSION:=$(FREETZ_TARGET_GCC_VERSION)
$(PKG)_SOURCE:=gcc-$($(PKG)_VERSION).tar.xz
$(PKG)_HASH:=skip  # Will be validated by toolchain download
$(PKG)_SITE:=@GNU/gcc/gcc-$($(PKG)_VERSION)

# This package builds a native compiler (runs on target, compiles for target)
$(PKG)_DEPENDS_ON += gnu-make

# Binaries
$(PKG)_BINARIES := gcc
$(PKG)_BINARIES += $(if $(FREETZ_PACKAGE_GCC_CPP),g++ c++)
$(PKG)_BINARIES += $(if $(FREETZ_PACKAGE_GCC_FORTRAN),gfortran)
$(PKG)_BINARIES += cpp gcov gcov-tool

# Binutils binaries
$(PKG)_BINUTILS_BINARIES := ld as ar ranlib nm objdump objcopy strip size strings addr2line readelf

# Target directories
$(PKG)_DEST_DIR_PREFIX:=$($(PKG)_DEST_DIR)/usr
$(PKG)_DEST_BIN:=$($(PKG)_DEST_DIR_PREFIX)/bin
$(PKG)_DEST_LIB:=$($(PKG)_DEST_DIR_PREFIX)/lib
$(PKG)_DEST_INCLUDE:=$($(PKG)_DEST_DIR_PREFIX)/include

# Configure options for native compiler
$(PKG)_CONFIGURE_OPTIONS += --prefix=/usr
$(PKG)_CONFIGURE_OPTIONS += --build=$(GNU_HOST_NAME)
$(PKG)_CONFIGURE_OPTIONS += --host=$(REAL_GNU_TARGET_NAME)
$(PKG)_CONFIGURE_OPTIONS += --target=$(REAL_GNU_TARGET_NAME)
$(PKG)_CONFIGURE_OPTIONS += --enable-languages=c$(if $(FREETZ_PACKAGE_GCC_CPP),$(COMMA)c++)$(if $(FREETZ_PACKAGE_GCC_FORTRAN),$(COMMA)fortran)
$(PKG)_CONFIGURE_OPTIONS += --enable-shared
$(PKG)_CONFIGURE_OPTIONS += --enable-threads=posix
$(PKG)_CONFIGURE_OPTIONS += --disable-nls
$(PKG)_CONFIGURE_OPTIONS += --disable-multilib
$(PKG)_CONFIGURE_OPTIONS += --disable-libsanitizer
$(PKG)_CONFIGURE_OPTIONS += --disable-libquadmath
$(PKG)_CONFIGURE_OPTIONS += --with-system-zlib
$(PKG)_CONFIGURE_OPTIONS += $(if $(FREETZ_PACKAGE_GCC_STRIP_BINARIES),--enable-strip,)

# Use existing toolchain settings
$(PKG)_CONFIGURE_OPTIONS += --with-arch=$(FREETZ_GCC_ARCH)
$(PKG)_CONFIGURE_OPTIONS += --with-tune=$(FREETZ_GCC_CPU)
$(PKG)_CONFIGURE_OPTIONS += $(if $(FREETZ_SOFTFLOAT),--with-float=soft,--with-float=hard)

$(PKG)_CONFIGURE_ENV += AR_FOR_TARGET="$(TARGET_AR)"
$(PKG)_CONFIGURE_ENV += AS_FOR_TARGET="$(TARGET_AS)" 
$(PKG)_CONFIGURE_ENV += LD_FOR_TARGET="$(TARGET_LD)"
$(PKG)_CONFIGURE_ENV += NM_FOR_TARGET="$(TARGET_NM)"
$(PKG)_CONFIGURE_ENV += OBJDUMP_FOR_TARGET="$(TARGET_CROSS)objdump"
$(PKG)_CONFIGURE_ENV += RANLIB_FOR_TARGET="$(TARGET_RANLIB)"

$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_DIR)/.compiled: $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(GCC_DIR) all-gcc all-target-libgcc
	$(if $(FREETZ_PACKAGE_GCC_CPP),$(SUBMAKE) -C $(GCC_DIR) all-target-libstdc++-v3)
	touch $@

$($(PKG)_DIR)/.installed: $($(PKG)_DIR)/.compiled
	# Install GCC
	$(SUBMAKE) -C $(GCC_DIR) DESTDIR=$(GCC_DEST_DIR) install-gcc install-target-libgcc
	$(if $(FREETZ_PACKAGE_GCC_CPP),$(SUBMAKE) -C $(GCC_DIR) DESTDIR=$(GCC_DEST_DIR) install-target-libstdc++-v3)
	
	# Install binutils from toolchain
	for bin in $(GCC_BINUTILS_BINARIES); do \
		$(INSTALL_BINARY_STRIP) $(TARGET_TOOLCHAIN_DIR)/bin/$(REAL_GNU_TARGET_NAME)-$${bin} \
			$(GCC_DEST_BIN)/$${bin}; \
	done
	
	# Install Python headers if requested
	$(if $(FREETZ_PACKAGE_GCC_PYTHON_HEADERS), \
		mkdir -p $(GCC_DEST_INCLUDE)/python$(PYTHON_MAJOR_VERSION) && \
		cp -a $(PYTHON_STAGING_INC_DIR)/* $(GCC_DEST_INCLUDE)/python$(PYTHON_MAJOR_VERSION)/ \
	)
	
	# Strip binaries if requested
	$(if $(FREETZ_PACKAGE_GCC_STRIP_BINARIES), \
		find $(GCC_DEST_BIN) -type f -executable -exec $(TARGET_STRIP) {} \; 2>/dev/null || true \
	)
	
	# Create convenience symlinks
	ln -sf gcc $(GCC_DEST_BIN)/cc
	$(if $(FREETZ_PACKAGE_GCC_CPP),ln -sf g++ $(GCC_DEST_BIN)/c++)
	
	# Remove unnecessary files to save space
	rm -rf $(GCC_DEST_DIR_PREFIX)/share/man
	rm -rf $(GCC_DEST_DIR_PREFIX)/share/info
	rm -rf $(GCC_DEST_DIR_PREFIX)/share/doc
	rm -rf $(GCC_DEST_LIB)/*.la
	rm -rf $(GCC_DEST_LIB)/*.a
	
	touch $@

$(pkg): $($(PKG)_DIR)/.installed

$(pkg)-precompiled: $($(PKG)_DIR)/.installed
	@echo ""
	@echo "========================================================================"
	@echo "GCC Native Compiler Toolchain Installation Complete"
	@echo "========================================================================"
	@echo ""
	@echo "IMPORTANT: This package MUST be externalized to USB storage!"
	@echo ""
	@echo "Package size: ~$(shell du -sh $(GCC_DEST_DIR) 2>/dev/null | cut -f1 || echo '???')"
	@echo ""
	@echo "To externalize:"
	@echo "  1. Flash your modified firmware"
	@echo "  2. Move files from /tmp/flash/gcc/ to USB storage:"
	@echo "     cp -a /tmp/flash/gcc /var/media/ftp/uStor01/freetz-external/"
	@echo "  3. Configure external processing in Freetz web interface"
	@echo ""
	@echo "Test installation:"
	@echo "  gcc --version"
	@echo "  echo 'int main(){return 0;}' | gcc -xc - -o test && ./test && echo OK"
	@echo ""
	@echo "Build Python wheel example:"
	@echo "  pip install --no-binary :all: cffi"
	@echo ""
	@echo "========================================================================"
	@echo ""

$(pkg)-clean:
	-$(SUBMAKE) -C $(GCC_DIR) clean
	$(RM) $(GCC_DIR)/.compiled

$(pkg)-uninstall:
	$(RM) -r $(GCC_DEST_DIR_PREFIX)

$(pkg)-dirclean:
	$(RM) -r $(GCC_DIR)

$(PKG_FINISH)
