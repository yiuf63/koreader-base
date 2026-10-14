list(APPEND PATCH_FILES cmake_tweaks.patch)

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
    # Project options.
    -DLUA_INCLUDE_DIR=${LUAJIT_INC}
    -DLUA_LIBRARIES=${LUAJIT_LIB}
)

list(APPEND BUILD_CMD COMMAND ninja)

if(MONOLIBTIC)
    append_install_commands(INSTALL_CMD rapidjson.a DESTINATION ${STAGING_DIR}/lib)
else()
    # `CMAKE_SHARED_MODULE_SUFFIX`, not `LIB_EXT`: this is a CMake `MODULE`
    # library, and a module does not take the platform's `SHARED` suffix.
    # `Darwin.cmake` sets the module suffix to `.so` deliberately, while
    # `LIB_EXT` is `.dylib` there, so the install step would look for a file the
    # build never produced. The two agree on Windows (`.dll`) and on Linux.
    append_binary_install_command(INSTALL_CMD rapidjson${CMAKE_SHARED_MODULE_SUFFIX} DESTINATION common)
endif()

external_project(
    DOWNLOAD GIT e84973356255bde06a70ce6263a3a0ef5c8f4ad4
    https://github.com/NiLuJe/lua-rapidjson
    PATCH_FILES ${PATCH_FILES}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
