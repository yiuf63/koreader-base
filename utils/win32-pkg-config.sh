#!/bin/sh
# pkg-config shim for MSYS builds of the Windows target.
#
# MSYS ships CMake, which reports CMAKE_HOST_UNIX=1 and therefore reads
# `D:/x` as a *relative* path. Both pkg-config binaries available here are
# native Windows programs, and pkgconf normalises every path it prints to the
# drive-letter form, so `--cflags` comes back as
#
#     -ID:/Code/.../staging/include/freetype2
#
# crengine (since its `pkg_check_modules(... IMPORTED_TARGET)` rewrite) feeds
# that straight into INTERFACE_INCLUDE_DIRECTORIES, where CMake rejects it:
#
#     Target "PkgConfig::FREETYPE" contains relative path in its
#     INTERFACE_INCLUDE_DIRECTORIES
#
# Rewriting drive-letter paths back to the MSYS spelling is enough: CMake reads
# `/d/...` as absolute, and the paths are passed to native tools, which accept
# the forward-slash form.
exec /usr/bin/pkg-config.exe "$@" | sed -E "s#(^|[ \t])(-I|-L)?([A-Za-z]):/#\1\2/\L\3/#g"
