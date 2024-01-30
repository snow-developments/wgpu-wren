#!/usr/bin/env bash
set -e
CWD=`pwd`
if [[ `basename pwd` ]]; then
  cd vendor
  CWD=`pwd`
fi

# Download GLFW sources
function glfw() {
  # TODO: Refactor version into native.lock.yml
  ZIP=glfw-3.3.9.zip
  DEST=`basename ${ZIP} .zip`

  # Short-circuit if it's already downloaded
  if [[ -e "${DEST}/CMakeLists.txt" ]]; then
    echo "Using cached GLFW release: ${DEST}"
    return 0
  fi

  wget -q "https://github.com/glfw/glfw/releases/download/3.3.9/${ZIP}"
  unzip ${ZIP}
  rm ${ZIP}
}

glfw
