list(APPEND PATCH_FILES
    cmake_tweaks.patch
    no_debug_fonts.patch
    trim_the_fat.patch
    simd_kill_switch.patch
)

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    # Project options.
    -DANDROID=${ANDROID}
    -DBUILD_TRAINING_TOOLS=FALSE
    -DDISABLE_ARCHIVE=TRUE
    -DDISABLE_CURL=TRUE
    -DDISABLE_TIFF=TRUE
    -DENABLE_CCACHE=FALSE
    -DENABLE_NINJA_POOL=FALSE
    -DENABLE_PRECOMPILED_HEADERS=FALSE
    -DENABLE_SIMD=${WANT_SIMD}
    -DGRAPHICS_DISABLED=TRUE
    -DINSTALL_CONFIGS=FALSE
    # NOTE: like leptonica, tesseract defaults SW_BUILD to ON on Windows, which
    #       makes it try to use the "Software Network" package manager
    #       (`find_package(SW)`), so force it off there.
    -DSW_BUILD=FALSE
    )
if(WIN32)
    list(APPEND CMAKE_ARGS
        # NOTE: leptonica is a shared library there, so tesseract has to be one
        #       too: as a static archive it would be pulled in *before*
        #       leptonica on the link line, leaving every `pix*` symbol
        #       unresolved (`--as-needed` drops the later copy).
        -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
    )
endif()

list(APPEND BUILD_CMD COMMAND ninja)

list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} --install .)

if(WIN32 AND NOT MONOLIBTIC)
    # NOTE: as a shared library, tesseract becomes a runtime dependency of
    #       libk2pdfopt, so its DLL has to be staged like the others.
    append_shared_lib_install_commands(INSTALL_CMD tesseract VERSION 55)
endif()

external_project(
    DOWNLOAD URL 561b6b104238fffa1d00362ac72ea397
    https://github.com/tesseract-ocr/tesseract/archive/refs/tags/5.5.3.tar.gz
    PATCH_FILES ${PATCH_FILES}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
