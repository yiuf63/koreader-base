list(APPEND PATCH_FILES
    # Ensure only the right symbols are exported.
    lfs-visibility.patch
    # Avoid precision loss on 32-bit arches (LFS is always built w/ LARGEFILE
    # support, but lua_Integer is always a ptrdiff_t, which is not wide enough).
    lfs-pushnumber-for-wide-types.patch
)

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
)

list(APPEND BUILD_CMD COMMAND ninja)

if(MONOLIBTIC)
    append_install_commands(INSTALL_CMD libkoreader-lfs.a DESTINATION ${STAGING_DIR}/lib)
else()
    # `EXT ${CMAKE_SHARED_MODULE_SUFFIX}`, not the default `LIB_EXT`: this is a
    # CMake `MODULE` library (a Lua C extension, dlopen'd rather than linked
    # against), and a module does not take the platform's `SHARED` suffix.
    # `Darwin.cmake` sets the module suffix to `.so` deliberately, so macOS
    # builds `libkoreader-lfs.so` while `LIB_EXT` there is `.dylib`, and the
    # install step would look for a file that does not exist:
    #     dsymutil: cannot parse the debug map for 'libkoreader-lfs.dylib'
    #
    # The two agree on Windows and Linux, which is why only macOS shows it.
    append_shared_lib_install_commands(INSTALL_CMD koreader-lfs EXT ${CMAKE_SHARED_MODULE_SUFFIX})
endif()

external_project(
    DOWNLOAD GIT v1_9_0
    https://github.com/lunarmodules/luafilesystem
    PATCH_OVERLAY overlay
    PATCH_FILES ${PATCH_FILES}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
