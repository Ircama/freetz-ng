$(call PKG_INIT_BIN, $(if $(FREETZ_AVM_GCC_13),13.4.0,$(if $(FREETZ_AVM_GCC_14),14.3.0,15.2.0)))
$(PKG)_CONDITIONAL:=y
$(PKG)_CATEGORY:=Debug helpers
### SUPPORT:=Ircama

# Package definition for GCC toolchain on target device
# This packages the native GCC compiler from target-utils for installation on target device

# Use dynamic paths from toolchain system
GCC_TOOLCHAIN_SOURCE_DIR:=$(TARGET_UTILS_DIR)
GCC_TOOLCHAIN_BINARY:=$(TARGET_UTILS_DIR)/usr/bin/gcc
GCC_TOOLCHAIN_DEST_DIR:=$(PACKAGES_DIR)/gcc-toolchain-$($(PKG)_VERSION)/root

# Use a special marker directory that tools/external will recognize and unpack
# This ensures gcc-toolchain files are completely isolated and properly externalized
GCC_TOOLCHAIN_ARCHIVE_MARKER:=GCC_TOOLCHAIN_ARCHIVE
$(PKG)_TARGET_BINARY:=$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin/gcc

# Externalize via marker directory (tools/external will handle unpacking)
$(PKG)_EXTERNALIZE_FILES:=

# No source to download - we reuse the existing toolchain
# So we skip PKG_SOURCE_DOWNLOAD, PKG_UNPACKED, PKG_CONFIGURED_NOP

# Build target-utils gcc if FREETZ_TARGET_TOOLCHAIN is enabled (selected by Config.in)
# This ensures gcc_target is built without affecting the main toolchain
ifeq ($(strip $(FREETZ_PACKAGE_GCC_TOOLCHAIN)),y)

$($(PKG)_TARGET_BINARY): $(GCC_TOOLCHAIN_BINARY)
	@echo "Packaging GCC toolchain into archive marker..."
	
	# Create archive marker directory structure
	mkdir -p $(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin
	mkdir -p $(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/lib
	mkdir -p $(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/libexec
	
	# Copy GCC compiler binaries (gcc, g++, cpp)
	@echo "  - Copying GCC binaries..."
	for bin in gcc g++ cpp gcov gcov-tool gcov-dump; do \
		if [ -f "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/bin/$$bin" ]; then \
			cp -a "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/bin/$$bin" \
			      "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin/$$bin"; \
		fi; \
	done
	
	# Create symlinks for C++ (c++ -> g++, cc -> gcc)
	ln -sf gcc "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin/cc"
	[ -f "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin/g++" ] && \
		ln -sf g++ "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin/c++" || true
	
	# Copy binutils if not minimal
ifneq ($(strip $(FREETZ_PACKAGE_GCC_TOOLCHAIN_MINIMAL)),y)
	@echo "  - Copying binutils..."
	for bin in as ld ar ranlib nm objdump objcopy strip strings readelf addr2line; do \
		if [ -f "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/bin/$$bin" ]; then \
			cp -a "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/bin/$$bin" \
			      "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin/$$bin"; \
		fi; \
	done
else
	@echo "  - Copying essential binutils (minimal mode)..."
	for bin in as ld ar ranlib; do \
		if [ -f "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/bin/$$bin" ]; then \
			cp -a "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/bin/$$bin" \
			      "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin/$$bin"; \
		fi; \
	done
endif
	
	# Copy all libraries (GCC, runtime, static, CRT files, etc.)
	@echo "  - Copying all GCC and system libraries..."
	if [ -d "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/lib" ]; then \
		cp -a "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/lib"/* \
		      "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/lib/"; \
	fi
	
	# Copy C runtime startup files (crt*.o) and static libraries from freetz directory
	@echo "  - Copying C runtime startup files and static libraries..."
	mkdir -p "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/lib/freetz"
	if [ -d "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/usr/lib/freetz" ]; then \
		cp -a "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/usr/lib/freetz"/* \
		      "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/lib/freetz/"; \
		cp -a "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/usr/lib/freetz"/crt*.o \
		      "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/lib/" 2>/dev/null || true; \
	fi
	
	# Copy GCC dependency libraries (GMP, MPFR, MPC) required by cc1, cc1plus, lto1
	@echo "  - Copying GCC dependency libraries (gmp, mpfr, mpc)..."
	@if [ -d "$(dir $(GCC_TOOLCHAIN_SOURCE_DIR))lib" ]; then \
		for lib in $(dir $(GCC_TOOLCHAIN_SOURCE_DIR))lib/libgmp.so* \
		           $(dir $(GCC_TOOLCHAIN_SOURCE_DIR))lib/libmpfr.so* \
		           $(dir $(GCC_TOOLCHAIN_SOURCE_DIR))lib/libmpc.so*; do \
			if [ -e "$$lib" ]; then \
				cp -a "$$lib" "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/lib/"; \
				echo "    Copied $$(basename $$lib)"; \
			fi; \
		done; \
	fi
	
	# Copy libexec (compiler internal programs: cc1, cc1plus, collect2, lto1)
	@echo "  - Copying compiler internals..."
	if [ -d "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/libexec/gcc" ]; then \
		cp -a "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/libexec/gcc" \
		      "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/libexec/"; \
	fi
	
	# Generate specs using cross-compiler and patch dynamic linker (always)
	@echo "  - Generating patched specs for target..."
	@VER=$$(basename $$(ls -d $(GCC_TOOLCHAIN_SOURCE_DIR)/usr/lib/gcc/$(REAL_GNU_TARGET_NAME)/*/ | head -1) || echo "13.4.0"); \
	DEST_SPEC="$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/lib/gcc/$(REAL_GNU_TARGET_NAME)/$$VER/specs"; \
	mkdir -p "$$(dirname $$DEST_SPEC)"; \
	$(TARGET_CC) -dumpspecs | \
	  sed -e 's#/lib/ld-uClibc.so.0#/mod/external/usr/lib/freetz/ld-uClibc.so.0 -L/mod/external/usr/lib/freetz -rpath /mod/external/usr/lib/freetz#g' \
	      -e 's#^\*cross_compile:$$#*cross_compile:#' \
	      -e '/^\*cross_compile:/{ n; s/^1$$/0/; }' \
	      -e 's#^\*cpp:$$#*cpp:#' \
	      -e '/^\*cpp:/{ n; s#$$# -I/mod/external/usr/include#; }' \
	  > "$$DEST_SPEC"; \
	echo "    Specs written to $$DEST_SPEC (patched for /usr/lib/freetz and native compile)"
	
	# Fix dynamic linker path for all binaries (only if SEPARATE_AVM_UCLIBC is enabled)
	@echo "  - Fixing dynamic linker paths..."
ifeq ($(strip $(FREETZ_SEPARATE_AVM_UCLIBC)),y)
	# Patch binaries in gcc-toolchain/bin
	if [ -d "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin" ]; then \
		for bin in $(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/bin/*; do \
			[ -f "$$bin" ] || continue; \
			[ -x "$$bin" ] || continue; \
			file "$$bin" | grep -q "ELF.*executable" || continue; \
			echo "    Patching $$bin"; \
			$(PATCHELF) --set-interpreter $(FREETZ_LIBRARY_DIR)/ld-uClibc.so.1 "$$bin" 2>/dev/null || true; \
		done; \
	fi
	# Patch binaries in gcc-toolchain/libexec/gcc (cc1, cc1plus, collect2, lto1, etc.)
	if [ -d "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/libexec/gcc" ]; then \
		find "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/libexec/gcc" -type f -executable | while read bin; do \
			file "$$bin" | grep -q "ELF.*executable" || continue; \
			echo "    Patching $$bin"; \
			$(PATCHELF) --set-interpreter $(FREETZ_LIBRARY_DIR)/ld-uClibc.so.1 "$$bin" 2>/dev/null || true; \
		done; \
	fi
else
	@echo "    Skipped (FREETZ_SEPARATE_AVM_UCLIBC not enabled)"
endif
	
	# Copy headers (only if FREETZ_PACKAGE_GCC_TOOLCHAIN_HEADERS is enabled)
ifeq ($(strip $(FREETZ_PACKAGE_GCC_TOOLCHAIN_HEADERS)),y)
	@echo "  - Copying development headers..."
	mkdir -p "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/include"
	
	# Copy C/C++ standard library headers (recursively to include all subdirectories like sys, arpa, net, etc.)
	# Python headers are always excluded as they are provided by python/python3 packages
	if [ -d "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/include" ]; then \
		for item in "$(GCC_TOOLCHAIN_SOURCE_DIR)/usr/include"/*; do \
			item_name=$$(basename "$$item"); \
			if [ "$$item_name" != "python2.7" ] && [ "$$item_name" != "python3.13" ]; then \
				cp -a "$$item" "$(GCC_TOOLCHAIN_DEST_DIR)/$(GCC_TOOLCHAIN_ARCHIVE_MARKER)/usr/include/"; \
			fi; \
		done; \
	fi
	
	# NOTE: Python development headers are provided by the python/python3 packages
	# and are automatically externalized by those packages to /usr/include/python*.
	# This ensures no conflicts and proper package ownership.
else
	@echo "  - Skipping headers (FREETZ_PACKAGE_GCC_TOOLCHAIN_HEADERS disabled)"
endif
	
	@echo "GCC toolchain packaged into archive marker directory"

$(pkg)-precompiled: $($(PKG)_TARGET_BINARY)

endif

$(PKG_FINISH)