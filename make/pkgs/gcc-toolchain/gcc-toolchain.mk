$(call PKG_INIT_BIN, $(if $(FREETZ_AVM_GCC_13),13.4.0,$(if $(FREETZ_AVM_GCC_14),14.3.0,15.2.0)))
$(PKG)_CONDITIONAL:=y
$(PKG)_CATEGORY:=Debug helpers

$(PKG)_BINARY:=$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/$(REAL_GNU_TARGET_NAME)-gcc
$(PKG)_TARGET_BINARY:=$($(PKG)_DEST_DIR)/usr/bin/gcc

$(PKG)_EXTERNALIZE_FILES:=usr/bin/* usr/lib/* usr/libexec/* $(if $(FREETZ_PACKAGE_GCC_TOOLCHAIN_HEADERS),usr/include/*)


# Determine the toolchain target triplet
GCC_TOOLCHAIN_TARGET_TRIPLET := $(REAL_GNU_TARGET_NAME)


# No source to download - we reuse the existing toolchain
# So we skip PKG_SOURCE_DOWNLOAD, PKG_UNPACKED, PKG_CONFIGURED_NOP

$($(PKG)_BINARY):

$($(PKG)_TARGET_BINARY): $($(PKG)_BINARY)
	@echo "Packaging GCC toolchain from $(TARGET_TOOLCHAIN_STAGING_DIR)..."
	
	# Create necessary directories
	$(INSTALL_DIR) $($(PKG)_DEST_DIR)/usr/bin
	$(INSTALL_DIR) $($(PKG)_DEST_DIR)/usr/lib
	$(INSTALL_DIR) $($(PKG)_DEST_DIR)/usr/libexec
	
	# Copy GCC compiler binaries (gcc, g++, cpp)
	@echo "  - Copying GCC binaries..."
	for bin in gcc g++ cpp gcov gcov-tool gcov-dump; do \
		if [ -f "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/$(GCC_TOOLCHAIN_TARGET_TRIPLET)-$$bin" ]; then \
			cp -a "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/$(GCC_TOOLCHAIN_TARGET_TRIPLET)-$$bin" \
			      "$($(PKG)_DEST_DIR)/usr/bin/$$bin"; \
		fi; \
	done
	
	# Create symlinks for C++ (c++ -> g++, cc -> gcc)
	ln -sf gcc "$($(PKG)_DEST_DIR)/usr/bin/cc"
	[ -f "$($(PKG)_DEST_DIR)/usr/bin/g++" ] && ln -sf g++ "$($(PKG)_DEST_DIR)/usr/bin/c++" || true
	
	# Copy binutils if not minimal
ifneq ($(strip $(FREETZ_PACKAGE_GCC_TOOLCHAIN_MINIMAL)),y)
	@echo "  - Copying binutils..."
	for bin in as ld ar ranlib nm objdump objcopy strip strings readelf addr2line; do \
		if [ -f "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/$(GCC_TOOLCHAIN_TARGET_TRIPLET)-$$bin" ]; then \
			cp -a "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/$(GCC_TOOLCHAIN_TARGET_TRIPLET)-$$bin" \
			      "$($(PKG)_DEST_DIR)/usr/bin/$$bin"; \
		fi; \
	done
else
	@echo "  - Copying essential binutils (minimal mode)..."
	for bin in as ld ar ranlib; do \
		if [ -f "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/$(GCC_TOOLCHAIN_TARGET_TRIPLET)-$$bin" ]; then \
			cp -a "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/bin/$(GCC_TOOLCHAIN_TARGET_TRIPLET)-$$bin" \
			      "$($(PKG)_DEST_DIR)/usr/bin/$$bin"; \
		fi; \
	done
endif
	
	# Copy GCC libraries (libgcc_s, libstdc++, etc.)
	@echo "  - Copying GCC libraries..."
	if [ -d "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/gcc" ]; then \
		cp -a "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/gcc" \
		      "$($(PKG)_DEST_DIR)/usr/lib/"; \
	fi
	
	# Copy runtime libraries
	for lib in libgcc_s.so* libstdc++.so* libgomp.so* libatomic.so*; do \
		if [ -e "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/$$lib" ]; then \
			cp -a "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/lib/$$lib" \
			      "$($(PKG)_DEST_DIR)/usr/lib/"; \
		fi; \
	done
	
	# Copy libexec (compiler internal programs: cc1, cc1plus, collect2, lto1)
	@echo "  - Copying compiler internals..."
	if [ -d "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/libexec/gcc" ]; then \
		cp -a "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/libexec/gcc" \
		      "$($(PKG)_DEST_DIR)/usr/libexec/"; \
	fi
	
	# Copy headers if requested
ifeq ($(strip $(FREETZ_PACKAGE_GCC_TOOLCHAIN_HEADERS)),y)
	@echo "  - Copying development headers..."
	$(INSTALL_DIR) $($(PKG)_DEST_DIR)/usr/include
	
	# Copy C/C++ standard library headers
	if [ -d "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" ]; then \
		for dir in c++ bits gnu linux asm asm-generic; do \
			if [ -e "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/$$dir" ]; then \
				cp -a "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/$$dir" \
				      "$($(PKG)_DEST_DIR)/usr/include/"; \
			fi; \
		done; \
		find "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include" -maxdepth 1 -type f \
		     -exec cp -a {} "$($(PKG)_DEST_DIR)/usr/include/" \; ; \
	fi
	
	# Copy Python headers if requested
ifeq ($(strip $(FREETZ_PACKAGE_GCC_TOOLCHAIN_PYTHON_HEADERS)),y)
	@echo "  - Copying Python headers..."
	if [ -d "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/python2.7" ]; then \
		cp -a "$(TARGET_TOOLCHAIN_STAGING_DIR)/usr/include/python2.7" \
		      "$($(PKG)_DEST_DIR)/usr/include/"; \
	fi
endif
endif
	
	@echo "GCC toolchain packaged successfully!"

$(pkg):

$(pkg)-precompiled: $($(PKG)_TARGET_BINARY)

$(pkg)-clean:
	$(RM) -r $(GCC_TOOLCHAIN_DIR)

$(pkg)-uninstall:
	$(RM) -r $(GCC_TOOLCHAIN_DEST_DIR)

$(PKG_FINISH)
