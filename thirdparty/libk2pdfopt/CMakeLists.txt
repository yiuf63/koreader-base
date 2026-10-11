list(APPEND PATCH_FILES
    # NOTE: `trim the fat` (#50) disabled the ANSI parsing code, but the
    #       Win32-only fast path in `avprintf()` was left behind and still
    #       references it, so the file does not compile on Windows (MinGW
    #       predefines `WIN32`). No-op on other platforms.
    win32_no_ansi_parse.patch
    # NOTE: backport of upstream's `c2bc709 drop the need for willuslib/wgui.c`
    #       (koreader-base pin `64aa9cc`); the Win32 GUI backend drags in a
    #       chain of helpers this library does not build, so it fails to link.
    win32_drop_wgui.patch
)

if(NOT MONOLIBTIC)
    set(CMAKE_PATCH_FILE ${CMAKE_BINARY_DIR}/k2pdfopt_exports.cmake)
    target_exports(k2pdfopt FILELIST_VAR CDECLS_FILES WRITE_TO_FILE ${CMAKE_PATCH_FILE} CDECLS koptcontext_cdecl)
    list(APPEND PATCH_CMD COMMAND ${ISED} "\$p" -e "\$s|.*|include(${CMAKE_PATCH_FILE})|" lib/CMakeLists.txt)
endif()

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
    # Project options.
    -DANDROID=${ANDROID}
)

list(APPEND BUILD_CMD COMMAND ninja)

list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} --install .)

if(NOT MONOLIBTIC)
    append_shared_lib_install_commands(INSTALL_CMD k2pdfopt VERSION 2)
endif()

external_project(
    DOWNLOAD GIT 1fcffeb1e61ec43265d23e2ac77d9a901f8c45d2
    https://github.com/koreader/libk2pdfopt.git
    PATCH_FILES ${PATCH_FILES}
    PATCH_COMMAND ${PATCH_CMD}
    CMAKE_ARGS ${CMAKE_ARGS}
    SOURCE_SUBDIR lib
    BUILD_COMMAND ${BUILD_CMD}
    BUILD_DEPENDS ${CDECLS_FILES}
    INSTALL_COMMAND ${INSTALL_CMD}
)
