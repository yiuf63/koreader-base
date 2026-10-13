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
# Only the canonical name is installed. This used to install the producer's own
# spelling beside it as well, because a DLL records its dependencies in the
# import table as literal file names and the loader resolves them verbatim --
# PE has no soname, unlike ELF and Mach-O -- so `libarchive-13.dll` needed a
# `libz.dll` on disk if it had been linked against that name.
#
# That second copy was the whole problem. The two names are hard links in the
# build tree, so it cost nothing there, but a zip cannot store hard links and
# the archive shipped both: 15 libraries duplicated, 137 MB, of which
# libtesseract alone was 107 MB. The duplication is removed at the source now
# instead -- `record_canonical_implib.sh` points each import archive at the
# canonical name before dependents link, and the two projects that link their own
# libraries (libwebp, and tesseract through OUTPUT_NAME) emit the canonical name
# directly -- so nothing references the producer's spelling any more and one file
# per library is enough.
#
# Usage: install_lib.sh <destination> <candidate>...

set -eu

dst="$1"
shift 1

install_lib() {
    src="$1"
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
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
