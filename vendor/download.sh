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
ZIP="wgpu-${OS}-${ARCH}-${CONFIG}.zip"
DEST=`echo ${ZIP} | cut --delimiter=. --fields 1`

# Short-circut if binaries are already downloaded
if [[ -e "${DEST}/commit-sha" ]]; then
  echo "Using cached wgpu-native release: ${DEST}"
  exit 0
fi

# Download wgpu-native binaries
VERSION=`tail ../native.lock.yml -n1 | cut --delimiter=':' --fields=2 | tr -d '[:space:]'`
URL="https://github.com/gfx-rs/wgpu-native/releases/download/v${VERSION}/${ZIP}.zip"

echo Donloading wgpu-native from: ${URL}
wget -q ${URL}
unzip ${ZIP} -d ${DEST}
