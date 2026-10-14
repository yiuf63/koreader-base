list(APPEND PATCH_FILES luajit.patch)

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
)

list(APPEND BUILD_CMD COMMAND ninja)

if(MONOLIBTIC)
    append_install_commands(INSTALL_CMD lpeg.a DESTINATION ${STAGING_DIR}/lib)
else()
    # `CMAKE_SHARED_MODULE_SUFFIX`, not `LIB_EXT`: this is a CMake `MODULE`
    # library, and a module does not take the platform's `SHARED` suffix.
    # `Darwin.cmake` sets the module suffix to `.so` deliberately, while
    # `LIB_EXT` is `.dylib` there, so the install step would look for a file the
    # build never produced. The two agree on Windows (`.dll`) and on Linux.
    #
    # It also lives in `common/` rather than `libs/`, as that is where the
    # frontend looks for Lua modules (`package.cpath`).
    get_filename_component(LPEG_LIB ${BINARY_DIR}/lpeg${CMAKE_SHARED_MODULE_SUFFIX} ABSOLUTE)
    append_binary_install_command(INSTALL_CMD ${LPEG_LIB} DESTINATION common)
endif()
append_install_commands(INSTALL_CMD ${SOURCE_DIR}/re.lua DESTINATION common)

external_project(
    DOWNLOAD URL c9914cc6036d4afa2f49e5c659a214a5
    https://github.com/roberto-ieru/LPeg/archive/refs/tags/v1.1.0.tar.gz
    PATCH_OVERLAY overlay
    PATCH_FILES ${PATCH_FILES}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
