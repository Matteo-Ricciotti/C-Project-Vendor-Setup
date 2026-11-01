# myprogram

C23 project template: CMake + Ninja, Clang as the main compiler, GCC as a second check (no MSVC).
Layout: `src/` (sources), `include/` (headers), `third_party/` (vendored libraries).

## Requirements

```
sudo apt install clang clangd clang-tidy clang-format gcc cmake ninja-build gdb valgrind
```

Minimum versions: CMake 3.21, Clang 18, GCC 14 (first releases accepting `-std=c23`).
Quick check, expected `202311L`:

```
echo | clang -std=c23 -dM -E -x c - | grep __STDC_VERSION__
```

## Daily use

```
make run                  # Clang, Debug, ASan+UBSan, in build-clang/
make run CC_NAME=gcc      # same with GCC, in build-gcc/
make run ARGS="foo bar"   # pass arguments
make release              # Release, no sanitizers, hardened + LTO, in build-release/
make check                # before committing: format check + -Werror build with both compilers
make format | tidy | clean | distclean | help
```

One build directory per compiler: CMake can't switch compiler inside an existing one.
New `.c` files under `src/` are picked up automatically. Renaming the program means changing
`project()`/`add_executable()` in `CMakeLists.txt` and `PROG` in the `Makefile`.

Plain CMake works too (`CMakePresets.json` mirrors the Makefile defaults: `clang`, `gcc`, `release`):

```
cmake --preset clang && cmake --build --preset clang
```

clangd reads `build-clang/compile_commands.json` (set in `.clangd`), so build with Clang at least
once. After adding a file, build again so clangd picks up its flags.

## Sanitizers

`SANITIZE=ON` (default in the Makefile, `OFF` in plain CMake) enables ASan + UBSan.
UBSan aborts on the first error.
It's cached per build directory; `make SANITIZE=OFF` changes it.
UBSan stack traces: `UBSAN_OPTIONS=print_stacktrace=1 ./build-clang/myprogram`.

## Release

Release builds define `NDEBUG`, so `assert` is compiled out. They also get `_FORTIFY_SOURCE=3`,
`-fstack-protector-strong`, full RELRO (Linux) and LTO when the toolchain supports it.

## Extra checks

Each one needs its own build directory.

```
# GCC static analyzer
cmake -S . -B build-analyzer -G Ninja -DCMAKE_C_COMPILER=gcc -DCMAKE_C_FLAGS=-fanalyzer
cmake --build build-analyzer

# MemorySanitizer: Clang only, not combinable with ASan. Uninstrumented libraries give false positives.
cmake -S . -B build-msan -G Ninja -DCMAKE_C_COMPILER=clang -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_C_FLAGS="-fsanitize=memory -fno-omit-frame-pointer" -DCMAKE_EXE_LINKER_FLAGS=-fsanitize=memory
cmake --build build-msan && ./build-msan/myprogram

# Valgrind: needs a build without sanitizers
make build BUILD=build-valgrind SANITIZE=OFF
valgrind --leak-check=full --error-exitcode=1 ./build-valgrind/myprogram
```

Debugging: `gdb ./build-gcc/myprogram` or `lldb ./build-clang/myprogram`.

## Vendoring a library in third_party/

Copied sources, no submodules.

1. Verify the archive against the upstream checksum: `sha256sum lib-1.2.3.tar.gz`.
2. Copy only the needed files plus `LICENSE` into `third_party/<lib>/`, without `.git`.
3. Record version, URL, checksum, license and local patches in `third_party/VENDORED.md`.
4. Commit it alone: `git commit -m "vendor: add <lib> 1.2.3"`.
5. Uncomment `add_subdirectory(third_party)` and `target_link_libraries(...)` in
   `CMakeLists.txt`, then rebuild.
