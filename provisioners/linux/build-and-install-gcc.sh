#!/usr/bin/env bash
set -e -o pipefail

USAGE="\
$(basename "${BASH_SOURCE[0]}")
Downloads the specified version of GCC's source code to the current user's
'~/Downloads' directory.

Verifies the source tarball's GPG signature and unpacks it to a temporary
directory.

Builds and installs gcc, g++, and libstdc++

Environment variables:
  GCC_VERSION           The complete version string for the version of GCC to
                        be installed, (i.e. '12.2.0', required)
  INSTALL_IN_USR_LOCAL  Install GCC to /usr/local/ if set to 'true', otherwise,
                        install in ~/gcc-\$GCC_VERSION/ for the current user."


BAD_INPUT=false

if [ -z "$GCC_VERSION" ]; then
  >&2 echo "ERROR: Required environment variable 'GCC_VERSION' not specified."
  BAD_INPUT=true
fi

if $BAD_INPUT; then
  echo "$USAGE"
  exit 1
fi

if [ "${INSTALL_IN_USR_LOCAL,,}" == true ]; then
  GCC_INSTALL_DIR=/usr/local
else
  GCC_INSTALL_DIR=~/gcc-"$GCC_VERSION"
fi

# Download specified GCC version and signature file if they are not already present in ~/Downloads
DOWNLOADS_DIR=~/Downloads
mkdir -p "$DOWNLOADS_DIR"
GCC_SRC_TARBALL_FILENAME="gcc-$GCC_VERSION.tar.xz"
GCC_SRC_TARBALL_SIG_FILENAME="gcc-$GCC_VERSION.tar.xz.sig"

# FIXME: get core count in a amd64 or arm64-friendly-way
CORE_COUNT="$(lscpu | awk '
  /^Core\(s\) per socket:/{cores_per_socket=$4}
  /^Socket\(s\):/{sockets=$2}
  END{print cores_per_socket * sockets}
')"


if ! [ -f "$DOWNLOADS_DIR/$GCC_SRC_TARBALL_FILENAME" ]; then
  curl "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/$GCC_SRC_TARBALL_FILENAME" --output-dir "$DOWNLOADS_DIR" \
      -o "$GCC_SRC_TARBALL_FILENAME"
fi

if ! [ -f "$DOWNLOADS_DIR/$GCC_SRC_TARBALL_SIG_FILENAME" ]; then
  curl "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/$GCC_SRC_TARBALL_SIG_FILENAME" --output-dir "$DOWNLOADS_DIR" \
      -o "$GCC_SRC_TARBALL_SIG_FILENAME"
fi


pushd "$DOWNLOADS_DIR"
gpg --verify "$GCC_SRC_TARBALL_SIG_FILENAME" "$GCC_SRC_TARBALL_FILENAME"
popd

TMPDIR="$(mktemp -d)"
pushd "$TMPDIR"

tar -Jxvf "$DOWNLOADS_DIR/$GCC_SRC_TARBALL_FILENAME"
mkdir build

pushd build
"../gcc-$GCC_VERSION/configure" --prefix="$GCC_INSTALL_DIR" --enable-languages=c,c++

make -j "$CORE_COUNT"

make install
