CWD := $(shell pwd)
OS := $(shell uname -s)
ARCH := $(shell uname -m)
# Release configuration, i.e. 'debug' or 'release'
CONFIG ?= debug
LIBS := lib/wren-vector

default: all

lint:
.PHONY: lint

test:
.PHONY: test

clean:
	rm -f examples/headless
	rm -f examples/*.dwarf
	rm -rf lib
.PHONY: clean

all: libs vendor
.PHONY: all

libs:
	@cd lib/wren-vector && wrenc package.wren
.PHONY: libs

SUBMODULES := wren
${SUBMODULES} &:
	git submodule update --init --recursive

WGPU := wgpu-${shell echo ${OS} | tr '[:upper:]' '[:lower:]'}-${ARCH}-${CONFIG}
WGPU_DEST := vendor/${WGPU}
vendor: ${WGPU_DEST}
.PHONY: vendor

ifneq (${OS},Windows)
  WGPU_LIBS := ${WGPU_DEST}/libwgpu_native.a
else
  $(error "Unsupported OS: ${OS)")
endif

${WGPU_DEST}: native.lock.yml
	@CONFIG=${CONFIG} vendor/download.sh
# TODO: Download wgpu-native binaries on Windows

CC ?= gcc
INCLUDES := wren/src/include vendor/${WGPU}
SOURCES := $(shell find src -name "*.h") $(shell find src -name "*.c")
CFLAGS := $(patsubst %,-I%,$(INCLUDES))
bin/libwgpu-wren.o: wren ${SOURCES}
	@mkdir -p bin
	$(CC) src/main.c $(CFLAGS) $(LDFLAGS) -o bin/libwgpu-wren.o

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
