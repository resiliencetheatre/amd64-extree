################################################################################
#
# LLVM 23 libclc compatibility
#
################################################################################

# LLVM 23 separates the OpenCL compiler from the native C/C++ compilers.
# Keep native helpers on HOSTCC and use Buildroot's matching Clang for CLC.
# Included after upstream package definitions via external.mk.
LIBCLC_CONF_OPTS += \
	-DCMAKE_CLC_COMPILER=$(HOST_DIR)/bin/clang \
	-DLLVM_DEFAULT_TARGET_TRIPLE=spirv64-unknown-unknown \
	-DLLVM_INCLUDE_TESTS=OFF

HOST_LIBCLC_CONF_OPTS = \
	-DCMAKE_CLC_COMPILER=$(HOST_DIR)/bin/clang \
	-DLLVM_DEFAULT_TARGET_TRIPLE=spirv64-unknown-unknown \
	-DLLVM_DIR=$(HOST_DIR)/lib/cmake/llvm \
	-DLLVM_INCLUDE_TESTS=OFF
