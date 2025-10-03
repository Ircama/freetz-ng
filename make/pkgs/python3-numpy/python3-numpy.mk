$(call PKG_INIT_BIN, 2.1.3)
$(PKG)_SOURCE:=numpy-py3-$($(PKG)_VERSION).tar.gz
$(PKG)_SOURCE_DOWNLOAD_NAME:=numpy-$($(PKG)_VERSION).tar.gz
$(PKG)_SITE:=https://files.pythonhosted.org/packages/source/n/numpy
$(PKG)_HASH:=aa08e04e08aaf974d4458def539dece0d28146d866a39da5639596f4921fd761
### WEBSITE:=https://numpy.org/
### MANPAGE:=https://numpy.org/doc/stable/
### CHANGES:=https://numpy.org/doc/stable/release.html
### CVSREPO:=https://github.com/numpy/numpy

$(PKG)_DEPENDS_ON += python3
$(PKG)_DEPENDS_ON += python3-setuptools-host


$(PKG_SOURCE_DOWNLOAD)
$(PKG_UNPACKED)
$(PKG_CONFIGURED_NOP)

$($(PKG)_DIR)/.compiled: $($(PKG)_DIR)/.configured
	$(call Build/Py3Mod/PKG, PYTHON3_NUMPY, , )
	@touch $@

$(pkg):

$(pkg)-precompiled: $($(PKG)_DIR)/.compiled


$(pkg)-clean:
	$(RM) $(PYTHON3_NUMPY_DIR)/{.configured,.compiled}
	$(RM) -r $(PYTHON3_NUMPY_DIR)/build

$(pkg)-uninstall:
	$(RM) -r \
		$(PYTHON3_NUMPY_DEST_DIR)$(PYTHON3_SITE_PKG_DIR)/numpy \
		$(PYTHON3_NUMPY_DEST_DIR)$(PYTHON3_SITE_PKG_DIR)/numpy-*.dist-info

$(PKG_FINISH)
