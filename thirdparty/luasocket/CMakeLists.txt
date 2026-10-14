list(APPEND PATCH_FILES
    # Rename modules:
    # `mime.core` → `mime.mcore`
    # `socket.core` → `socket.score`
    namespace.patch
    # Compatibility with luajit.
    luajit-compat.patch
    # To avoid duplicated code in luasec.
    export-api-for-luasec.patch
)
if(NOT ANDROID)
    # Make sure socket fds are CLOEXEC on *nix.
    list(APPEND PATCH_FILES enforce-cloexec.patch)
endif()

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
)

list(APPEND BUILD_CMD COMMAND ninja)

append_install_commands(
    INSTALL_CMD
    ${SOURCE_DIR}/src/ltn12.lua
    ${SOURCE_DIR}/src/mime.lua
    ${SOURCE_DIR}/src/socket.lua
    DESTINATION common
)
append_install_commands(
    INSTALL_CMD
    ${SOURCE_DIR}/src/ftp.lua
    ${SOURCE_DIR}/src/headers.lua
    ${SOURCE_DIR}/src/http.lua
    ${SOURCE_DIR}/src/smtp.lua
    ${SOURCE_DIR}/src/tp.lua
    ${SOURCE_DIR}/src/url.lua
    DESTINATION common/socket
)
append_install_commands(INSTALL_CMD DESTINATION ${STAGING_DIR}/include/luasocket
    ${SOURCE_DIR}/src/buffer.h
    ${SOURCE_DIR}/src/compat.h
    ${SOURCE_DIR}/src/io.h
    ${SOURCE_DIR}/src/luasocket.h
    ${SOURCE_DIR}/src/socket.h
    ${SOURCE_DIR}/src/timeout.h
    ${SOURCE_DIR}/src/usocket.h
    # NOTE: `socket.h` includes `wsocket.h` instead on Windows, and luasec
    #       includes `socket.h`, so it needs to be there too.
    ${SOURCE_DIR}/src/wsocket.h
)
append_install_commands(INSTALL_CMD libluasocket.a DESTINATION ${STAGING_DIR}/lib)
if(MONOLIBTIC)
    append_install_commands(INSTALL_CMD mcore.a score.a DESTINATION ${STAGING_DIR}/lib)
else()
    # `CMAKE_SHARED_MODULE_SUFFIX`, not `LIB_EXT`.
    #
    # These are CMake `MODULE` libraries -- Lua C extensions, dlopen'd rather
    # than linked against -- and a module does not use the platform's shared
    # library suffix. Darwin.cmake sets it to `.so` on purpose
    # (`Modules/Platform/Darwin.cmake: set(CMAKE_SHARED_MODULE_SUFFIX ".so")`),
    # so macOS produces `score.so`; `LIB_EXT` is `.dylib` there (it is the
    # `SHARED` suffix), and asking for `score.dylib` fails in the install step
    # with `dsymutil: cannot parse the debug map ... No such file or directory`.
    #
    # On Windows the two agree (`.dll`), which is why this went unnoticed.
    append_binary_install_command(INSTALL_CMD score${CMAKE_SHARED_MODULE_SUFFIX} DESTINATION common/socket)
    append_binary_install_command(INSTALL_CMD mcore${CMAKE_SHARED_MODULE_SUFFIX} DESTINATION common/mime)
endif()

external_project(
    DOWNLOAD GIT e3ca4a767a68d127df548d82669aba3689bd84f4
    https://github.com/lunarmodules/luasocket
    PATCH_OVERLAY overlay
    PATCH_FILES ${PATCH_FILES}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
