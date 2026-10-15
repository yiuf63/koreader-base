list(APPEND PATCH_FILES
    # NOTE: MinGW predefines `_WIN32`, which makes crengine take several
    #       Windows-only code paths that were never exercised (and do not build)
    #       with anything but MSVC:
    #       - `LVColorDrawBuf::GetScanLine` flips the scanline order for its own
    #         GDI DIB sections, but an externally supplied buffer (KOReader's
    #         top-down blitbuffers) must not be flipped — otherwise the whole
    #         page is rendered upside down.
    #       - `posix_memalign` does not exist in the MinGW CRT.
    #       - the `LPCWSTR`/UTF-16 conversions used to hand paths to the Win32
    #         API are missing entirely.
    #       No-op on other platforms.
    ${THIRDPARTY_DIR}/kpvcrlib/win32_crengine.patch
)

# For some reason we need to include this again…
include(${CMAKE_KOVARS})

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=FALSE
    # Project options.
    # Disable all auto features…
    -DAUTO=FALSE
    # …and force enable needed only.
    -DANTIWORD=TRUE
    -DCHMLIB=TRUE
    -DFREETYPE=TRUE
    -DFRIBIDI=TRUE
    -DGIF=TRUE
    -DHARFBUZZ=TRUE
    -DLIBJPEG=TRUE
    -DLIBPNG=TRUE
    -DLIBUNIBREAK=TRUE
    -DLIBWEBP=TRUE
    -DLUNASVG=TRUE
    -DMATHML=TRUE
    -DMD4C=TRUE
    -DSRELL=TRUE
    -DUTF8PROC=TRUE
    -DZLIB=TRUE
    -DZSTD=TRUE
    # Enable custom memory manager.
    -DOWN_MEM_MAN=TRUE
    # Disable some stuff on legacy platforms.
    -DDISABLE_CLOEXEC=$<BOOL:${LEGACY}>
    -DDISABLE_LFS=$<BOOL:${LEGACY}>
)

# crengine resolves its dependencies with `pkg_check_modules(... IMPORTED_TARGET)`,
# which passes the `.pc` files' include directories through
# `INTERFACE_INCLUDE_DIRECTORIES`. CMake refuses *relative* paths there, and that
# is what it sees on Windows: the CMake running this is the MSYS one, which
# reports `CMAKE_HOST_UNIX=1` and therefore reads `D:/x` as relative, while every
# pkg-config available here is a native binary that normalises paths to exactly
# that drive-letter form. The result is
#
#     Target "PkgConfig::FREETYPE" contains relative path in its
#     INTERFACE_INCLUDE_DIRECTORIES
#
# `utils/win32-pkg-config.sh` rewrites those paths back to the MSYS spelling,
# which CMake reads as absolute. Pointing `PKG_CONFIG_EXECUTABLE` at it is
# needed because `find_package(PkgConfig)` otherwise picks `/usr/bin/pkg-config.exe`
# off `PATH` before `PKG_CONFIG` is consulted. No-op on other platforms, which
# have neither problem.
if(WIN32)
    list(APPEND CMAKE_ARGS "-DPKG_CONFIG_EXECUTABLE=${BASE_DIR}/utils/win32-pkg-config.sh")
endif()

list(APPEND BUILD_CMD COMMAND ninja)

external_project(
    BUILD_ALWAYS
    CMAKE_ARGS ${CMAKE_ARGS}
    PATCH_FILES ${PATCH_FILES}
    BUILD_COMMAND ${BUILD_CMD}
)
