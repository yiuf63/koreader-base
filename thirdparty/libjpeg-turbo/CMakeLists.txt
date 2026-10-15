list(APPEND PATCH_FILES
    no_cmake_rpath_shenanigans.patch
    no_12_or_16_bits_precision.patch
    no_simdcoverage_exe.patch
    no_other_image_formats_except_bmp.patch
)

if(WIN32)
    # NOTE: `win/jpeg8.def` is only ever used by Windows linkers, and it still
    # exports the 12-bit symbols that no_12_or_16_bits_precision.patch removes,
    # which makes the DLL link fail ("cannot export j12foo: symbol not defined").
    list(APPEND PATCH_CMD COMMAND ${ISED} "/^[ \t]*j12/d$<SEMICOLON>/^[ \t]*jpeg12_/d$<SEMICOLON>/^[ \t]*j16/d$<SEMICOLON>/^[ \t]*jpeg16_/d" win/jpeg8.def)
endif()

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    # Project options.
    -DENABLE_SHARED=$<NOT:$<BOOL:${MONOLIBTIC}>>
    -DENABLE_STATIC=$<BOOL:${MONOLIBTIC}>
    -DWITH_JPEG8=ON
    -DWITH_TESTS=OFF
    -DWITH_TOOLS=OFF
    # Make sure we disable ASM if we don't support SIMD.
    -DREQUIRE_SIMD=$<BOOL:${WANT_SIMD}>
    -DWITH_SIMD=$<BOOL:${WANT_SIMD}>
    # Reproducible builds: use release date.
    -DBUILD=20240508
)

list(APPEND BUILD_CMD COMMAND ninja)

list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} --install .)

if(NOT MONOLIBTIC)
    append_shared_lib_install_commands(INSTALL_CMD jpeg VERSION 8)
    append_shared_lib_install_commands(INSTALL_CMD turbojpeg VERSION 0.5.0)
endif()

external_project(
    DOWNLOAD URL a80f9f1c735b57d3cdd66daed1ba6bb4
    https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0.tar.gz
    PATCH_FILES ${PATCH_FILES}
    PATCH_COMMAND ${PATCH_CMD}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
