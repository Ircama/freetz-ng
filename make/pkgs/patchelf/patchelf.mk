$(call PKG_INIT_BIN, 0.18.0)
$(PKG)_SOURCE:=patchelf-$($(PKG)_VERSION).tar.bz2
$(PKG)_HASH:=1952b2a782ba576279c211ee942e341748fdb44997f704dd53def46cd055470b
$(PKG)_SITE:=https://github.com/NixOS/patchelf/releases/download/$($(PKG)_VERSION)
### WEBSITE:=https://github.com/NixOS/patchelf
### MANPAGE:=https://github.com/NixOS/patchelf/blob/master/README.md
### CHANGES:=https://github.com/NixOS/patchelf/releases
### CVSREPO:=https://github.com/NixOS/patchelf
### SUPPORT:=Ircama

$(PKG)_CATEGORY:=Debug helpers

$(PKG)_DEPENDS_ON += $(STDCXXLIB)

$(PKG)_BINARY_BUILD := $($(PKG)_DIR)/src/patchelf
$(PKG)_BINARY_TARGET := $($(PKG)_DEST_DIR)/usr/bin/patchelf


ifneq ($($(PKG)_SOURCE),$(PATCHELF_HOST_SOURCE))
$(PKG_SOURCE_DOWNLOAD)
endif
$(PKG_UNPACKED)

# Force C++17 support when cross-compiling (autoconf tests fail for cross-compiled binaries)
# Also force basic C++ compiler acceptance since cross-compiled test binaries can't be executed
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ax_cv_cxx_compile_cxx17=yes' > config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ax_cv_cxx_compile_cxx17__std_cpp17=yes' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ax_cv_cxx_compile_cxx17_pstd_cpp17=yes' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ax_cv_cxx_compile_cxx17__h_std_cpp17=yes' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ax_cv_cxx_compile_cxx17__std_cpp1z=yes' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ax_cv_cxx_compile_cxx17_pstd_cpp1z=yes' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ax_cv_cxx_compile_cxx17__h_std_cpp1z=yes' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'HAVE_CXX17=1' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ac_cv_prog_cxx_cxx_works=yes' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ac_cv_prog_cxx_11=yes' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'ac_cv_prog_cxx_stdcxx=cxx17' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += echo 'am_cv_CXX_dependencies_compiler_type=gcc3' >> config.cache;
$(PKG)_CONFIGURE_PRE_CMDS += export ac_cv_prog_cxx_g=yes;
$(PKG)_CONFIGURE_PRE_CMDS += export ax_cv_cxx_compile_cxx17=yes;
$(PKG)_CONFIGURE_PRE_CMDS += export HAVE_CXX17=1;
$(PKG)_CONFIGURE_PRE_CMDS += export ac_cv_prog_cxx_cxx_works=yes;
$(PKG)_CONFIGURE_PRE_CMDS += export ac_cv_prog_cxx_11=yes;
$(PKG)_CONFIGURE_PRE_CMDS += export ac_cv_prog_cxx_stdcxx=cxx17;
$(PKG)_CONFIGURE_PRE_CMDS += export am_cv_CXX_dependencies_compiler_type=gcc3;

$(PKG)_CONFIGURE_OPTIONS += --cache-file=config.cache

$(PKG)_CONFIGURE_ENV += CXX="$(TARGET_CROSS)g++"
# Fix i686 uClibc linking issue with pthread symbols (6591, 6660 devices)
$(PKG)_CONFIGURE_ENV += $(if $(FREETZ_TARGET_ARCH_X86),LDFLAGS="-static-libgcc -static-libstdc++")

$(PKG_CONFIGURED_CONFIGURE)

$($(PKG)_BINARY_BUILD): $($(PKG)_DIR)/.configured
	$(SUBMAKE) -C $(PATCHELF_DIR)

$($(PKG)_BINARY_TARGET): $($(PKG)_BINARY_BUILD)
	$(INSTALL_BINARY_STRIP)

$(pkg):

$(pkg)-precompiled: $($(PKG)_BINARY_TARGET)


$(pkg)-clean:
	-$(SUBMAKE) -C $(PATCHELF_DIR) clean

$(pkg)-uninstall:
	$(RM) $(PATCHELF_BINARY_TARGET)

$(PKG_FINISH)
