CWD := $(shell pwd)
OS := $(shell uname -s)
ARCH := $(shell uname -m)
# Release configuration, i.e. 'debug' or 'release'
CONFIG ?= debug

default: all

lint:
.PHONY: lint

test:
.PHONY: test

clean:
	rm -rf bin
	# TODO: rm -rf lib/**/wren_modules
.PHONY: clean

all: libs vendor
.PHONY: all

SUBMODULES := wren
${SUBMODULES} &:
	git submodule update --init --recursive

#############
# Libraries
#############

# Wren
ifeq (${CONFIG},debug)
  LIBS += wren_d
  LIBWREN := wren/lib/libwren_d.a
  LIBWREN_CONFIG := debug_64bit
else
  LIBS += wren
endif
LIB_DIRS += wren/lib
LIBWREN ?= wren/lib/libwren.a
LIBWREN_CONFIG ?= release_64bit
${LIBWREN}: wren
	@make --no-print-directory -C wren/projects/make wren config=${LIBWREN_CONFIG}

# Wren Libraries
libs:
	@cd vendor/wren-vector && wrenc package.wren install
.PHONY: libs

# WebGPU
WGPU := wgpu-${shell echo ${OS} | tr '[:upper:]' '[:lower:]'}-${ARCH}-${CONFIG}
WGPU_DEST := vendor/${WGPU}
vendor: ${WGPU_DEST}
.PHONY: vendor

ifneq (${OS},Windows)
  # LIBS += ${WGPU_DEST}/libwgpu_native.a
  LIBS += wgpu_native
  LIB_DIRS += ${WGPU_DEST}
else
  $(error "Unsupported OS: ${OS)")
endif

${WGPU_DEST}: native.lock.yml
	@CONFIG=${CONFIG} vendor/download.sh
# TODO: Download wgpu-native binaries on Windows

###########
# Targets
###########

CC ?= gcc
INCLUDES := include wren/src/include vendor/${WGPU}
SOURCES := $(shell find include -name "*.h") $(shell find src -name "*.h")
CFLAGS := $(patsubst %,-I%,$(INCLUDES))
ifeq (${CONFIG},debug)
  CFLAGS += -g
else
  CFLAGS += -O
endif
LDFLAGS := $(patsubst %,-L%,${LIB_DIRS}) -static
LDFLAGS += $(patsubst %,-l%,${LIBS}) -lm

# See https://www.gnu.org/software/libtool/manual/html_node/Creating-object-files.html
src/app.o: src/app.c ${SOURCES}
	$(CC) -c src/app.c $(CFLAGS) -o $@
# See https://www.gnu.org/software/make/manual/html_node/Archives.html
lib/libwgpu-wren.a: libwgpu-wren.a(src/app.o)
	@mkdir -p bin
	$(AR) $(ARFLAGS) $@ $?

################
# Applications
################

bin/examples/triangle: libs ${LIBWREN}
	@mkdir -p bin/examples
	$(CC) src/examples/triangle.c $(CFLAGS) $(LDFLAGS) -o $@

# macOS troubleshooting:
# https://stackoverflow.com/a/17704255/1363247
# https://developer.apple.com/forums/thread/656303
# https://www.oreilly.com/library/view/modding-mac-os/0596007094/ch04s05.html

example-headless: vendor shard.lock
	crystal build examples/headless.cr -o examples/headless
ifeq (${OS},Darwin)
	@echo "Fixing up libwgpu_native dylib path…"
	@install_name_tool -change /Users/runner/work/wgpu-native/wgpu-native/target/debug/deps/libwgpu_native.dylib @executable_path/../../Frameworks/libwgpu_native.dylib examples/headless
	@otool -L examples/headless | grep wgpu
	@rm -rf "examples/headless.app"
	@scripts/appify.sh examples/headless
	@mkdir -p "headless.app/Frameworks"
	@cp bin/libs/libwgpu_native.dylib "headless.app/Frameworks"
	@cp examples/Info.plist "headless.app/Contents"
	@mv -f "headless.app" examples
	@./examples/headless.app/Contents/MacOS/headless
else
	env LD_LIBRARY_PATH=${CWD}/bin/libs examples/headless
endif
.PHONY: example-headless

example-triangle: vendor shard.lock
	crystal build examples/triangle.cr -o examples/triangle
ifeq (${OS},Darwin)
	@echo "Fixing up libwgpu_native dylib path…"
	@install_name_tool -change /Users/runner/work/wgpu-native/wgpu-native/target/debug/deps/libwgpu_native.dylib @executable_path/../../Frameworks/libwgpu_native.dylib examples/triangle
	@otool -L examples/triangle | grep wgpu
	@rm -rf "examples/triangle.app"
	@scripts/appify.sh examples/triangle
	@mkdir -p "triangle.app/Frameworks"
	@cp bin/libs/libwgpu_native.dylib "triangle.app/Frameworks"
	@cp examples/Info.plist "triangle.app/Contents"
	@mv -f "triangle.app" examples
	@./examples/triangle.app/Contents/MacOS/triangle
else
	env LD_LIBRARY_PATH=${CWD}/bin/libs examples/triangle
endif
.PHONY: example-triangle
