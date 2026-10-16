################################################################################
#
# libcbor
#
################################################################################

LIBCBOR_VERSION = 0.14.0
LIBCBOR_SITE = $(call github,PJK,libcbor,v$(LIBCBOR_VERSION))
LIBCBOR_LICENSE = MIT
LIBCBOR_LICENSE_FILES = LICENSE.md
LIBCBOR_INSTALL_STAGING = YES
LIBCBOR_CONF_OPTS = -DWITH_TESTS=OFF -DWITH_EXAMPLES=OFF

$(eval $(cmake-package))
