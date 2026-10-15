list(APPEND PATCH_FILES
    # NOTE: `wsys.c` reaches `win_has_own_window()` / `win_full_exe_name()`
    #       through its `HAVE_WIN32_API` paths, which MinGW enables by defining
    #       `WIN32`, but `willuslib/win.c` is not in the build. No-op on other
    #       platforms, where those paths are not compiled.
    win32_build_win_c.patch
    # NOTE: `trim the fat` (#50) disabled the ANSI parsing machinery, but left
    #       the `#ifdef WIN32` fast path in `avprintf()` calling into it, so the
    #       file does not compile on Windows (MinGW predefines `WIN32`):
    #           willuslib/ansi.c:330:25: error: 'ansi_buffer' undeclared
    #       Upstream's update to pin `64aa9cc` did not touch this. No-op
    #       elsewhere, where the path is not compiled.
    win32_no_ansi_parse.patch
    # NOTE: upstream's `4c11f61 disable some unused code` wrapped two runs in
    #       `#if 0` that Windows actually needs, because MinGW defines `WIN32`
    #       and `willus.h` turns that into `HAVE_WIN32_API`:
    #         * `wsys_win32_api()`, called by `wfile.c`;
    #         * the six `wfile_*` date helpers, called by `win.c`.
    #       The link fails on `undefined reference to` each of them. No-op
    #       elsewhere, where nothing calls them.
    win32_undisable_needed_code.patch
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
    -DLEPTONICA_PATCH=FALSE
)

list(APPEND BUILD_CMD COMMAND ninja)

list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} --install .)

if(NOT MONOLIBTIC)
    append_shared_lib_install_commands(INSTALL_CMD k2pdfopt VERSION 2)
endif()

external_project(
    DOWNLOAD GIT 64aa9ccfcd55921c596458cb8a7197339d5f32c3
    https://github.com/koreader/libk2pdfopt.git
    PATCH_FILES ${PATCH_FILES}
    PATCH_COMMAND ${PATCH_CMD}
    CMAKE_ARGS ${CMAKE_ARGS}
    SOURCE_SUBDIR lib
    BUILD_COMMAND ${BUILD_CMD}
    BUILD_DEPENDS ${CDECLS_FILES}
    INSTALL_COMMAND ${INSTALL_CMD}
)
