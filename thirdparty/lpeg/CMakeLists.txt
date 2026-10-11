list(APPEND PATCH_FILES luajit.patch)

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
)

list(APPEND BUILD_CMD COMMAND ninja)

if(MONOLIBTIC)
    append_install_commands(INSTALL_CMD lpeg.a DESTINATION ${STAGING_DIR}/lib)
else()
    # NOTE: the module's extension follows the target platform (`.so` /
    #       `.dylib` / `.dll`), so it cannot be hardcoded. It also lives in
    #       `common/` rather than `libs/`, as that is where the frontend looks
    #       for Lua modules (`package.cpath`).
    get_filename_component(LPEG_LIB ${BINARY_DIR}/lpeg${LIB_EXT} ABSOLUTE)
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
