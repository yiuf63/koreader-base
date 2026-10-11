#!/bin/sh

# Install a shared library under the name KOReader expects it to have.
#
# Thirdparty projects do not consistently produce the `lib<name>-<version>.dll`
# name (nor the location) that `set_libname` in koreader_thirdparty_common.cmake
# expects on Windows: libtool-based ones do, while CMake-based ones tend to
# install an unversioned `lib<name>.dll` into `bin/`, and some spell the version
# out in full (leptonica ships `libleptonica-1.87.0.dll`, but we ask for
# `libleptonica-6.dll`). Try all the plausible spellings, then fall back to any
# version of the same library, and install the first match under the canonical
# name.
#
# The original name is kept around as well: our canonical names only exist for
# the benefit of `ffi/loadlib.lua`, whereas the DLLs themselves record their
# dependencies under whatever name they were linked against (PE has no soname
# mechanism, unlike ELF/Mach-O), and the Windows loader resolves those from the
# import table verbatim. Shipping both spellings is what makes e.g.
# `libarchive-13.dll` find `libz.dll`.
#
# Usage: install_lib.sh <destination> <candidate>...

set -eu

dst="$1"
shift 1

install_lib() {
    src="$1"
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    # Keep the original spelling as well (cf. the note above), unless it is
    # already what we install as. Use a hard link: both names have to be real
    # files for the loader, but they are the same bytes, and duplicating
    # something like libtesseract (100MB+) twice per build adds up fast.
    alias="$(dirname "$dst")/$(basename "$src")"
    if [ "$alias" != "$dst" ]; then
        rm -f "$alias"
        ln "$dst" "$alias" 2>/dev/null || cp -f "$src" "$alias"
    fi
    exit 0
}

for candidate in "$@"; do
    if [ -e "$candidate" ]; then
        install_lib "$candidate"
    fi
done

# Strip the trailing `-<version>` from the canonical name, and look for any
# version of that library next to the candidates we were given.
# Also try without the `lib` prefix: a few projects (SDL3, for one) name their
# DLL `SDL3.dll`, which is what the Windows loader conventions allow for.
stem=$(basename "$dst")
stem=${stem%.dll}
stem=$(printf '%s' "$stem" | sed 's/-[0-9][0-9.]*$//')
stems="$stem $(printf '%s' "$stem" | sed 's/^lib//')"
for dir in $(dirname "$@" | sort -u); do
    for s in $stems; do
        # Both `libfoo-1.dll` and `libfoo1.dll` are plausible spellings (the
        # former is libtool's, the latter what e.g. tesseract's CMake produces).
        for candidate in "$dir"/"$s"-[0-9]*.dll "$dir"/"$s"[0-9]*.dll "$dir"/"$s".dll; do
            if [ -f "$candidate" ]; then
                install_lib "$candidate"
            fi
        done
    done
done

echo "koreader: no library found for $dst (tried: $*, $stems)" >&2
exit 1
