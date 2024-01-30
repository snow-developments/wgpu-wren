CWD := $(shell pwd)
OS := $(shell uname -s)
ARCH := $(shell uname -m)
# Release configuration, i.e. 'debug' or 'release'
CONFIG ?= debug

default: all
all: lib/libperegrine.a
.PHONY: all

lint:
.PHONY: lint

test:
.PHONY: test

clean:
	@rm -rf bin
	@rm -f src/*.o
	# TODO: rm -rf lib/**/wren_modules
.PHONY: clean

#############
# Libraries
#############

# Wren Libraries
vendor/wren-vector/wren_modules:
	@cd vendor/wren-vector && wrenc package.wren install

######################
# Vendored Libraries
######################

vendor: native.lock.yml
	@CONFIG=${CONFIG} vendor/download.sh
# TODO: Download wgpu-native binaries on Windows
.PHONY: vendor

# GLFW
# TODO: Refactor version into native.lock.yml
vendor/glfw-3.3.9/build/src/libglfw3.a: vendor
	@cd vendor/glfw-3.3.9 && cmake -B build .
	@make --no-print-directory -C vendor/glfw-3.3.9/build glfw
glfw: vendor/glfw-3.3.9/build/src/libglfw3.a
.PHONY: glfw

###########
# Targets
###########

# Includes
CFLAGS += $(patsubst %,-I%,$(INCLUDES))
ifeq (${OS},Darwin)
  CFLAGS := $(shell pkg-config --cflags vulkan) ${CFLAGS}
else ifeq (${OS},Windows)
  CFLAGS := $(shell pkg-config --cflags dx12) ${CFLAGS}
else
  CFLAGS := $(shell pkg-config --cflags gl) ${CFLAGS}
endif

SOURCES := $(shell find source -name *.d)
lib/libperegrine.a: ${SOURCES}
	dub build

################
# Applications
################

ifeq (${OS},Darwin)
  bin/examples/triangle: CFLAGS += -DGLFW_INCLUDE_NONE
  bin/examples/triangle: LDFLAGS += -framework Cocoa -framework Metal -framework IOKit
endif
bin/examples/triangle: ${LIB_WREN} lib/libperegrine.a glfw
	@mkdir -p bin/examples
	ldc2 examples/triangle.c lib/libperegrine.a \
		-P-I${HOME}/.dub/packages/wren-d/0.4.2/wren-d/wren/src/include \
		${HOME}/.dub/packages/wren-d/0.4.2/wren-d/wren/lib/libwren.a \
		${HOME}/.dub/packages/wgpu-d/0.3.0/wgpu-d/subprojects/wgpu/libwgpu_native.a \
		vendor/glfw-3.3.9/build/src/libglfw3.a \
		-L"-framework" -L"CoreFoundation" -L"-framework" -L"QuartzCore" -L"-framework" -L"Metal" -L"-framework" -L"Cocoa" -L"-framework" -L"IOKit" \
		--od=bin
# $(CC) src/file.c src/string.c src/examples/triangle.c $(CFLAGS) -pthread \
#   $(LDFLAGS) -Llib -lwgpu-wren \
#   -o $@

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
