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
    # Taken from the build tree, not from `staging/`.
    #
    # This project has no `cmake --install` step, so nothing ever copies its
    # module into `staging/lib`, and `append_shared_lib_install_commands`
    # assumes exactly that -- it passes `${STAGING_DIR}/lib/${LIB}` on to
    # `append_binary_install_command`, which on macOS runs `dsymutil` on it
    # before copying. The file is not there yet, so that fails:
    #     dsymutil: cannot parse the debug map for '.../staging/lib/libkoreader-lfs.so'
    # Upstream avoided it by naming `libkoreader-lfs.so` directly, a path
    # relative to the install step's working directory, which is the build tree.
    #
    # `CMAKE_SHARED_MODULE_SUFFIX`, not `LIB_EXT`: this is a CMake `MODULE`
    # library (a Lua C extension, dlopen'd rather than linked against), and a
    # module does not take the platform's `SHARED` suffix. `Darwin.cmake` sets
    # the module suffix to `.so` deliberately, so macOS builds
    # `libkoreader-lfs.so` while `LIB_EXT` there is `.dylib`. The two agree on
    # Windows and Linux, which is why only macOS showed either problem.
    append_binary_install_command(INSTALL_CMD
        ${BINARY_DIR}/libkoreader-lfs${CMAKE_SHARED_MODULE_SUFFIX}
        DESTINATION ${OUTPUT_DIR}/libs)
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
