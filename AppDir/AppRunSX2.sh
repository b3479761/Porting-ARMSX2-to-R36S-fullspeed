#!/bin/sh

# Example AppRun for using the hooks of this repository.
# NOTE: It is meant to be used with sharun which uses a top level bin dir

if [ "$APPRUN_DEBUG" = 1 ]; then
        set -x
fi

set -e

APPDIR=$(cd "${0%/*}" && echo "$PWD")
MAIN_BIN=armsx2-qt
ARG0="${ARGV0:-$0}"

unset ARGV0

export APPIMAGE_ARCH=aarch64
export HOSTPATH=$PATH
export PATH=$APPDIR/bin:$PATH
export ARG0 APPDIR PATH

# Allow users to set env variables for specific AppImage
# This feature only works with the uruntime
if [ "$1" = '--appimage-add-env' ]; then
        shift
        for v do
            echo "$v" >> "$APPIMAGE".env
            >&2 echo "Added '$v' to $APPIMAGE.env"
        done
        exit 0
fi

__fedora_cert=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
if [ ! -f /etc/ssl/certs/ca-certificates.crt ] && [ -f "$__fedora_cert" ]; then
        CURL_CA_BUNDLE=${CURL_CA_BUNDLE:-$__fedora_cert}
        REQUESTS_CA_BUNDLE=${REQUESTS_CA_BUNDLE:-$__fedora_cert}
        SSL_CERT_FILE=${SSL_CERT_FILE:-$__fedora_cert}
        export CURL_CA_BUNDLE REQUESTS_CA_BUNDLE SSL_CERT_FILE
fi

if [ -f "$APPDIR"/AppRun.lib ]; then
        . "$APPDIR"/AppRun.lib
        for hook in "$APPDIR"/bin/*.hook; do
            [ -e "$hook" ] || continue
            . "$hook"
        done
fi

export QT_QPA_PLATFORM=wayland
export QT_ENABLE_HIGHDPI_SCALING=1
export QT_SCALE_FACTOR=1.00
export QT_FONT_DPI=72

# Check if ARG0 matches a binary, fallback to $1, then binary in .desktop
if [ -f "$APPDIR"/bin/"${ARG0##*/}" ]; then
        TO_LAUNCH=$APPDIR/bin/${ARG0##*/}
elif [ -f "$APPDIR"/bin/"$1" ]; then
        TO_LAUNCH=$APPDIR/bin/$1
        shift
else
        TO_LAUNCH=$APPDIR/bin/$MAIN_BIN
fi

set -- "$TO_LAUNCH" "$@"

# If LD_DEBUG=libs is set outside the AppImage the output is not helpful
# because it will include the libs of sh, grep, cat, etc from the hooks
# with this var we can set LD_DEBUG=libs for the bundled application only
if [ "$APPIMAGE_DEBUG" = 1 ]; then
        cat /etc/os-release >"$PWD"/"${APPIMAGE##*/}"-debug.log || :
        export LD_DEBUG=libs
        export VK_LOADER_DEBUG=all
export LIBGL_DEBUG=verbose
export EGL_LOG_LEVEL=debug
        export LC_ALL=C
        export SHARUN_PRINTENV=1
        "$@" 2>>"$PWD"/"${APPIMAGE##*/}"-debug.log || :
        >&2 echo "Debug log at: '$PWD/${APPIMAGE##*/}-debug.log'"
else
        exec "$@"
fi
