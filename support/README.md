# Package compatibility adjustments

`libclc.mk` adjusts the existing Buildroot libclc packages through the external
makefile, after upstream package definitions. It neither replaces package
sources nor modifies the upstream checkout. It is specific to the pinned
Buildroot revision and LLVM 23.1.3.

LLVM 23's `libclc/cmake/modules/CMakeDetermineCLCCompiler.cmake` defaults
`CMAKE_CLC_COMPILER` to `CMAKE_C_COMPILER`. Buildroot sets the latter to host
GCC, which cannot compile the OpenCL compiler probe's `--target=spirv64-...`.
Set only the CLC compiler to the existing host-clang dependency, retaining
GCC/G++ for native C/C++ code. Compiler probes remain enabled.

The same source's CMakeLists.txt now uses `LLVM_DEFAULT_TARGET_TRIPLE`, not
`LIBCLC_TARGETS_TO_BUILD`. Select the documented 64-bit SPIR-V target
`spirv64-unknown-unknown`, and locate LLVM using the Buildroot host prefix.
Disable upstream tests, which are not part of this appliance build.

Validation: configured the already-extracted libclc 23.1.3 sources in
`../output-amd64-check/libclc-configure` with the already-built host Clang.
The CLC probe passed, and CMake configuration and generation completed.
Buildroot `printvars` confirmed that both host and target libclc receive the
new CLC compiler and triple. This test compiled only CMake compiler probes;
it did not compile libclc, install anything, or resume the image build.
The user subsequently completed the image build and confirmed the desktop and
browser work; the probe above remains the isolated check performed by the agent.

For the existing failed build in `buildroot/output`, run from the parent:

```sh
make -C buildroot \
  BR2_EXTERNAL="$PWD/amd64-extree" host-libclc-reconfigure
make -C buildroot \
  BR2_EXTERNAL="$PWD/amd64-extree"
```

The first command reconfigures **and builds** host-libclc. It is supplied for
the user to run manually. No full clean or deletion of the LLVM build is
necessary for this configuration fix.
