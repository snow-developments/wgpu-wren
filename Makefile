CWD := $(shell pwd)
OS := $(shell uname -s)
ARCH := $(shell uname -m)
# Release configuration, i.e. 'debug' or 'release'
CONFIG ?= debug

default: all
all: lib/libwgpu-wren.a
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

SUBMODULES := wren
${SUBMODULES} &:
	git submodule update --init --recursive

#############
# Libraries
#############

# Wren
ifeq (${CONFIG},debug)
  LIBS += wren_d
  LIB_WREN := wren/lib/libwren_d.a
  LIB_WREN_CONFIG := debug_64bit
else
  LIBS += wren
endif
LIB_DIRS += wren/lib
LIB_WREN ?= wren/lib/libwren.a
LIB_WREN_CONFIG ?= release_64bit
${LIB_WREN}: wren
	@make --no-print-directory -C wren/projects/make wren config=${LIB_WREN_CONFIG}

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

# WebGPU
ifeq (${OS},Darwin)
  WGPU := wgpu-macos-${ARCH}-${CONFIG}
else
  WGPU := wgpu-${shell echo ${OS} | tr '[:upper:]' '[:lower:]'}-${ARCH}-${CONFIG}
endif
WGPU_DEST := vendor/${WGPU}
ifneq (${OS},Windows)
  LIBS += wgpu_native
  LIB_DIRS += ${WGPU_DEST}
else
  $(error "Unsupported OS: ${OS)")
endif
${WGPU_DEST}/libwgpu_native.a: vendor
wgpu: vendor ${WGPU_DEST}/libwgpu_native.a
.PHONY: wgpu

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

CC ?= gcc
INCLUDES := include wren/src/include vendor/${WGPU} vendor/glfw-3.3.9/include
SOURCES := $(shell find include -name "*.h") $(shell find src -name "*.h")

# C flags
CFLAGS += -DOS_${OS}
ifeq (${OS},Darwin)
  CFLAGS += -DOS_MacOS
else ifneq (${OS},Windows)
  CFLAGS += -DOS_Unix
endif
# Includes
CFLAGS += $(patsubst %,-I%,$(INCLUDES))
ifeq (${OS},Darwin)
  CFLAGS := $(shell pkg-config --cflags vulkan) ${CFLAGS}
else ifeq (${OS},Windows)
  CFLAGS := $(shell pkg-config --cflags dx12) ${CFLAGS}
else
  CFLAGS := $(shell pkg-config --cflags gl) ${CFLAGS}
endif
# Debug symbols and optimization
ifeq (${CONFIG},debug)
  CFLAGS += -g
else
  CFLAGS += -O
endif

# Linker flags
LDFLAGS := $(patsubst %,-L%,${LIB_DIRS})
LDFLAGS += $(patsubst %,-l%,${LIBS})
ifeq (${OS},Linux)
  $(info Linking with OpenGL and X11)
  LDFLAGS += $(shell pkg-config --static --libs gl)
  LDFLAGS += $(shell pkg-config --static --libs x11)
  -lrt -ldl
endif
LDFLAGS += -lm

# See https://www.gnu.org/software/libtool/manual/html_node/Creating-object-files.html
src/app.o: wgpu src/app.c ${SOURCES}
	$(CC) -c src/app.c $(CFLAGS) -o $@
# See https://www.gnu.org/software/make/manual/html_node/Archives.html
libwgpu-wren.a: libwgpu-wren.a(src/app.o)
	@$(AR) $(ARFLAGS) $@ $?
	ranlib libwgpu-wren.a
lib:
	@mkdir -p lib
lib/libwgpu-wren.a: lib libwgpu-wren.a
	@mv libwgpu-wren.a lib/.

################
# Applications
################

bin/examples/triangle: LDFLAGS += -Lvendor/glfw-3.3.9/build/src -lglfw3
ifeq (${OS},Darwin)
  bin/examples/triangle: CFLAGS += -DGLFW_INCLUDE_NONE
  bin/examples/triangle: LDFLAGS += -framework Cocoa -framework OpenGL -framework IOKit
endif
bin/examples/triangle: ${LIB_WREN} lib/libwgpu-wren.a glfw
	@mkdir -p bin/examples
	$(CC) src/file.c src/string.c src/examples/triangle.c $(CFLAGS) -pthread \
	  $(LDFLAGS) \
	  -o $@

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
