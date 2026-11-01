# Thin wrapper around CMake + Ninja. Recipe lines must start with a TAB.
#
# Examples:
# make run                    # configure + build + run (Clang, Debug, ASan+UBSan, in build-clang/)
# make run CC_NAME=gcc        # same with GCC (build-gcc/)
# make run ARGS="foo bar"     # pass arguments to the program
# make release                # Release without sanitizers, hardened (build-release/)
# make check                  # format check + build with Clang and GCC, warnings as errors
# make format                 # clang-format -i on src/ and include/
# make tidy                   # clang-tidy on src/ and include/
# make clean                  # remove object files
# make distclean              # delete all build-* directories
# make help                   # list targets and variables

# PROG must match add_executable() in CMakeLists.txt.
PROG     := myprogram
CC_NAME  ?= clang
TYPE     ?= Debug
SANITIZE ?= ON
WERROR   ?= OFF
BUILD    ?= build-$(CC_NAME)
ARGS     ?=

# wildcard: git drops empty dirs, so include/ may not exist after a clone.
SRC_DIRS := $(wildcard src include)

.PHONY: all configure build run release format format-check tidy check clean distclean help

all: build

# Reconfigure on every call (cheap once cached) so `make SANITIZE=OFF` or
# `make TYPE=Release` apply to an existing build dir.
configure:
	cmake -S . -B $(BUILD) -G Ninja -DCMAKE_C_COMPILER=$(CC_NAME) -DCMAKE_BUILD_TYPE=$(TYPE) \
		-DSANITIZE=$(SANITIZE) -DWERROR=$(WERROR)

build: configure
	cmake --build $(BUILD)

# No leading ./ so an absolute BUILD works too. Separator keeps program output
# apart from build logs; @ hides the command so the output starts right after it.
run: build
	@echo "----------------------------------------"
	@$(BUILD)/$(PROG) $(ARGS)

release:
	$(MAKE) run TYPE=Release SANITIZE=OFF BUILD=build-release

# Our code only: third_party/ keeps upstream formatting.
format:
	find $(SRC_DIRS) \( -name '*.c' -o -name '*.h' \) -print0 | xargs -0 -r clang-format -i

format-check:
	find $(SRC_DIRS) \( -name '*.c' -o -name '*.h' \) -print0 | xargs -0 -r clang-format --dry-run --Werror

# Headers are checked through the .c files that include them (HeaderFilterRegex).
tidy: configure
	find src -name '*.c' -print0 | xargs -0 -r clang-tidy -p $(BUILD)

# Pre-commit: format check + -Werror build with both compilers.
# WERROR is reset to OFF by the next plain `make`, at the cost of one rebuild.
check: format-check
	$(MAKE) build CC_NAME=clang WERROR=ON
	$(MAKE) build CC_NAME=gcc WERROR=ON

clean:
	@if [ -d $(BUILD) ]; then cmake --build $(BUILD) --target clean; fi

distclean:
	rm -rf $(wildcard build-*)

help:
	@echo "make [build|run|release|format|format-check|tidy|check|clean|distclean]"
	@echo "variables: CC_NAME=clang|gcc  TYPE=Debug|Release  SANITIZE=ON|OFF  WERROR=ON|OFF  BUILD=<dir>  ARGS=\"...\""
