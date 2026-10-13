#!/bin/sh

# Make a library's import archive record the canonical DLL name.
#
# Why this is needed
# ------------------
# PE has no soname: a DLL's dependencies are recorded in its import table as
# literal file names, fixed when it was linked. Those names come from the import
# archive (`lib<name>.dll.a`) the linker was handed, and that archive names
# whatever DLL its producer built — `libz.dll`, `SDL3.dll`, `libtesseract55.dll`.
#
# KOReader's convention is different: `set_libname` and `ffi/loadlib.lua` ask for
# `lib<name>-<version>.dll`. So every such library was needed under two names at
# once — the canonical one for the frontend, and the producer's own for the import
# tables of everything that links against it — and `install_lib.sh` installed
# both. The build tree hard-links them, but a zip cannot store hard links, so the
# archive carried two full copies: 15 libraries, 137 MB, libtesseract alone 107 MB.
#
# Rewriting the archive's recorded name removes the need for the second file. The
# archive's own file name is left alone, so `pkg-config`'s `-lz` still resolves to
# `libz.dll.a`; only the runtime name it records changes, which is exactly the
# thing that has to agree with what is installed beside the executable.
#
# `gendef`, not `dlltool -z --export-all-symbols`
# -----------------------------------------------
# The export list has to come from the DLL's *export directory*. `dlltool -z
# --export-all-symbols` reads the COFF symbol table instead, and for a MinGW-built
# DLL that holds every global symbol rather than the exported ones. The archive it
# produced therefore advertised imports of `DllMain`, `___chkstk_ms`,
# `__acrt_iob_func` and similar, which the DLL does not export; dependents linked
# without complaint and then failed at load with error 127 ("procedure not
# found"), naming neither module nor symbol. Measured on libz: 558 symbols with
# 360 not in the real archive and 10 internal ones present. `gendef` produced 204
# against the pristine 200, with none internal, and a linked test program both ran
# and recorded the canonical name. `--strip-all` first does not help — it removes
# the symbol table rather than making it correct, leaving no exports at all.
#
# `gendef` ships in `mingw-w64-x86_64-tools`, which the `mingw-w64-x86_64-toolchain`
# group pulls in, so it is present wherever this build runs.
#
# Usage: record_canonical_implib.sh <canonical-dll> [extra-lib-dir]...
#
#   <canonical-dll>    path to the installed DLL, e.g. .../libs/libz-1.dll
#   [extra-lib-dir]... further directories to look for import archives in
#
# The archive stem is derived from the DLL name (`libz-1.dll` -> `z`), so callers
# do not have to pass it. Passing it by hand is easy to get wrong: `LIB_ALT` in
# the caller is `libz.dll`, not `z`, and using it verbatim looked for
# `liblibz.dll.dll.a`.
#
# More than one directory is searched because a library can be linked from two
# places. `libwebp` is the example: its own `libwebp.dll` links the
# `libsharpyuv.dll.a` sitting in *its* build tree, not the copy under `staging/`,
# so rewriting only the staged one left `libwebp.dll` still importing
# `libsharpyuv.dll`. Any archive a dependent might link has to be rewritten, and
# the staged copies are not the only ones.

set -eu

dll="$1"
shift 1
if [ "$#" -gt 0 ]; then
    lib_dirs="$*"
else
    lib_dirs="$(dirname "$(dirname "$dll")")/lib"
fi

[ -f "$dll" ] || exit 0

dst_name=$(basename "$dll")

# A missing gendef would otherwise mean silently shipping the duplication this
# exists to remove, so it is an error rather than a skip.
if ! command -v gendef >/dev/null 2>&1; then
    echo "record_canonical_implib: gendef not found (package mingw-w64-x86_64-tools)" >&2
    exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The export list, read from the DLL we are about to ship: it reflects what is
# actually exported, including anything the project changed.
if ! gendef - "$dll" > "$tmp/exports.def" 2>/dev/null; then
    echo "record_canonical_implib: gendef cannot read $dll; leaving archives alone" >&2
    exit 0
fi
[ -s "$tmp/exports.def" ] || exit 0

# Archive stems derived from the DLL name: `libz-1.dll` -> `z`, and also the
# full stem `z-1` in case the project installed a versioned archive name.
full=$(printf '%s' "$dst_name" | sed 's/\.dll$//')          # libz-1
base=$(printf '%s' "$full" | sed 's/^lib//')                # z-1
stem=$(printf '%s' "$base" | sed 's/-[0-9][0-9.]*$//')      # z

# Every archive with a matching name, in every directory given, is rewritten —
# not just the first. Two copies of the same archive exist when a project links
# its own libraries, and rewriting one but not the other leaves half the tree
# importing the old spelling.
#
# The candidates are collected before any rewriting, and each archive is rewritten
# once. `dlltool` is slow on a large export list -- 12.8 seconds for tesseract's
# 2144 symbols, against 0.09 for `gendef` -- so rebuilding the same archive twice
# is worth avoiding. The first version of this loop nested the directories and the
# stems, so `libwebp-7.dll` and `libwebp.dll` both matched `libwebp.dll.a` and it
# was rebuilt each time; across a full build that cost minutes.
candidates=""
for dir in $lib_dirs; do
    [ -d "$dir" ] || continue
    for s in "$stem" "$base"; do
        for candidate in "$dir/lib$s.dll.a" "$dir/lib$s"-[0-9]*.dll.a; do
            [ -f "$candidate" ] || continue
            candidates="$candidates $candidate"
        done
    done
done

# Deduplicated, so a path reachable through two of the patterns -- or two of the
# directory arguments, which overlap for project build trees -- is rewritten once.
unique=$(printf '%s\n' $candidates | sort -u)

for candidate in $unique; do
    # Rewritten unconditionally, even when the recorded name already looks right.
    # An earlier version skipped those, on the theory that a no-op rebuild should
    # stay a no-op — but that also skipped archives a previous bad rewrite had
    # corrupted, whose recorded name was correct while their imports were not.
    # Since rewriting is deterministic (same exports in, same archive out) there is
    # nothing to gain by skipping, and a whole class of stale damage to lose.
    #
    # The temporary file is inside `$tmp`, which `mktemp -d` made unique per run.
    # A sibling `.new` name would be shared: `make -j4` runs install steps
    # concurrently, and two libraries of one project match the same archive
    # (`libwebp-7.dll` and `libwebp.dll` both match `libwebp.dll.a`), so two
    # processes would write that one path and one of them would be truncated.
    new="$tmp/$(basename "$candidate").new"
    if ! dlltool -d "$tmp/exports.def" -D "$dst_name" -l "$new" 2>/dev/null; then
        echo "record_canonical_implib: dlltool failed for $candidate" >&2
        rm -f "$new"
        exit 1
    fi
    if [ ! -s "$new" ]; then
        echo "record_canonical_implib: empty result for $candidate" >&2
        rm -f "$new"
        exit 1
    fi

    # A rename within the filesystem, so a concurrent reader sees either the old
    # archive or the new one and never a partial write.
    mv -f "$new" "$candidate"

    if strings "$candidate" | grep -qix "$dst_name"; then
        echo "koreader: $(basename "$candidate") -> records $dst_name"
    else
        echo "record_canonical_implib: $candidate still not recording $dst_name" >&2
        exit 1
    fi
done

exit 0
