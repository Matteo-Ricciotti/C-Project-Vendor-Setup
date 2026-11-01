# 3.21: first version that accepts C_STANDARD 23.
cmake_minimum_required(VERSION 3.21)

# LANGUAGES C: skip the C++ compiler check.
project(myprogram LANGUAGES C)

# Empty build type means no -O and no -g: default to Debug.
# Skipped for multi-config generators, which pick the config at build time.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

# compile_commands.json for clangd and clang-tidy.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(SANITIZE "Enable AddressSanitizer + UndefinedBehaviorSanitizer" OFF)
option(WERROR "Treat warnings as errors" OFF)

# All .c files under src/. CONFIGURE_DEPENDS re-globs on every build,
# so added or removed files don't need a manual reconfigure.
file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS src/*.c)

add_executable(myprogram ${SOURCES})

target_include_directories(myprogram PRIVATE include)

# Per target, not global: third_party code keeps its own standard.
set_target_properties(myprogram PROPERTIES
  C_STANDARD 23
  C_STANDARD_REQUIRED ON   # fail instead of silently falling back to an older standard
  C_EXTENSIONS OFF)        # -std=c23, not -std=gnu23

# Warnings on our code only; third_party is not affected. GCC/Clang flags, no MSVC.
target_compile_options(myprogram PRIVATE
  -Wall -Wextra -Wpedantic
  -Wshadow
  -Wconversion                 # implicit narrowing / sign changes
  -Wmissing-prototypes         # catches non-static functions missing from a header
  -Wformat=2)                  # non-literal format strings, printf/scanf misuse

if(WERROR)
  target_compile_options(myprogram PRIVATE -Werror)
endif()

if(SANITIZE)
  # Frame pointers give readable stack traces; no-recover makes UBSan abort
  # on the first error instead of logging and continuing.
  target_compile_options(myprogram PRIVATE
    -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all)
  # Needed at link time too, to pull in the sanitizer runtime.
  target_link_options(myprogram PRIVATE -fsanitize=address,undefined)
endif()

# Release hardening. _FORTIFY_SOURCE needs optimization, hence Release only;
# -U first because some distro compilers already define it.
target_compile_options(myprogram PRIVATE
  $<$<CONFIG:Release>:-U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -fstack-protector-strong>)
if(NOT APPLE)
  # ELF only: read-only GOT after startup. Apple's linker rejects -z.
  target_link_options(myprogram PRIVATE $<$<CONFIG:Release>:-Wl,-z,relro,-z,now>)
endif()

# LTO in Release when the toolchain supports it (Clang needs the LLVM gold plugin or lld).
include(CheckIPOSupported)
check_ipo_supported(RESULT IPO_OK OUTPUT IPO_MSG LANGUAGES C)
if(IPO_OK)
  set_property(TARGET myprogram PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
else()
  message(STATUS "LTO disabled: ${IPO_MSG}")
endif()

# --- External libraries (uncomment once third_party/ has content) ---
# add_subdirectory(third_party)
# target_link_libraries(myprogram PRIVATE mylib)   # target name defined in third_party
