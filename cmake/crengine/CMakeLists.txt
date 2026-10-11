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

list(APPEND CMAKE_ARGS -DCMAKE_KOVARS=${CMAKE_KOVARS} -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE})

list(APPEND BUILD_CMD COMMAND ninja)

external_project(
    BUILD_ALWAYS
    CMAKE_ARGS ${CMAKE_ARGS}
    PATCH_FILES ${PATCH_FILES}
    BUILD_COMMAND ${BUILD_CMD}
)
