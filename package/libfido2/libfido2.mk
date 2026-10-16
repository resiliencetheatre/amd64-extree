################################################################################
#
# libfido2
#
################################################################################

LIBFIDO2_VERSION = 1.17.0
LIBFIDO2_SITE = https://developers.yubico.com/libfido2/Releases
LIBFIDO2_LICENSE = BSD-2-Clause
LIBFIDO2_LICENSE_FILES = LICENSE
LIBFIDO2_INSTALL_STAGING = YES
LIBFIDO2_DEPENDENCIES = host-pkgconf libcbor openssl zlib libudev
LIBFIDO2_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Buildroot \
	-DBUILD_TESTS=OFF \
	-DBUILD_EXAMPLES=OFF \
	-DBUILD_MANPAGES=OFF \
	-DBUILD_STATIC_LIBS=OFF \
	-DBUILD_TOOLS=ON \
	-DNFC_LINUX=OFF \
	-DUSE_PCSC=OFF \
	-DUDEV_RULES_DIR=/usr/lib/udev/rules.d

$(eval $(cmake-package))
