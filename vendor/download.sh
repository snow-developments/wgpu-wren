#!/usr/bin/env bash
CWD=`pwd`
if [[ `basename pwd` ]]; then
  cd vendor
fi
# Lowercase OS
OS=`uname -s  | tr '[:upper:]' '[:lower:]'`
ARCH=`uname -m`
# Release configuration, i.e. 'debug' or 'release'
if [[ -z $CONFIG ]]; then
  CONFIG=debug
fi

# Download wgpu-native binaries
function wgpu() {
  ZIP="wgpu-${OS}-${ARCH}-${CONFIG}.zip"
  DEST=`echo ${ZIP} | cut --delimiter=. --fields 1`
  VERSION=`tail ../native.lock.yml -n1 | cut --delimiter=':' --fields=2 | tr -d '[:space:]'`
  URL="https://github.com/gfx-rs/wgpu-native/releases/download/v${VERSION}/${ZIP}.zip"

  # Short-circut if it's already downloaded
  if [[ -e "${DEST}/commit-sha" ]]; then
    echo "Using cached wgpu-native release: ${DEST}"
    return 0
  fi

  echo Downloading wgpu-native from: ${URL}
  wget -q ${URL}
  unzip ${ZIP} -d ${DEST}
  rm ${ZIP}
}

# Download glfw sources
function glfw() {
  ZIP=glfw-3.3.9.zip
  DEST=`basename ${ZIP} .zip`

  # Short-circut if it's already downloaded
  if [[ -e "${DEST}/CMakeLists.txt" ]]; then
    echo "Using cached GLFW release: ${DEST}"
    return 0
  fi

  wget -q "https://github.com/glfw/glfw/releases/download/3.3.9/glfw-3.3.9.zip"
  unzip ${ZIP}
  rm ${ZIP}
}

wgpu && glfw
