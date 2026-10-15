list(APPEND PATCH_FILES
    cmake_tweaks.patch
    no_messing_with_debug_flags.patch
)
# Make sure we use the old fmemopen symbol on ARM Linux when building against
# glibc >= 2.22 (c.f. base#421 & #2188).
#
# NOTE: Technically, provided we're targeting ARM, we could probably apply the patch unilaterally,
# and not only when glibc >= 2.22, but since we now have the code to make the check, keep it,
# that ensures a vanilla build with sane TCs ;).
if(NOT ANDROID AND NOT APPLE AND NOT WIN32 AND NOT EMULATE_READER)
    enable_language(C)
    include(CheckCSourceCompiles)
    check_c_source_compiles([==[
        #include <limits.h>
        #if __GNUC_PREREQ (2, 22)
            __asm__(".symver fmemopen,fmemopen@GLIBC_2.4");
        #else
            #error glibc < 2.22
        #endif
        char fmemopen(void);
        int main(void) {
            return fmemopen();
        }
        ]==] HAS_FMEMOPEN_2_4)
    if(HAS_FMEMOPEN_2_4)
        list(APPEND PATCH_FILES fmemopen-arm-compat-symbol.patch)
    endif()
endif()

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
    # Project options.
    -DBUILD_PROG=FALSE
    -DSTRICT_CONF=TRUE
    # NOTE: leptonica defaults SW_BUILD to ON on Windows, which makes it try to
    #       use the "Software Network" package manager (`find_package(SW)`), so
    #       force it off there, like it is everywhere else.
    -DSW_BUILD=FALSE
    # Yes please.
    -DENABLE_PNG=TRUE
    -DENABLE_ZLIB=TRUE
    # No thank you.
    -DENABLE_GIF=FALSE
    -DENABLE_JPEG=FALSE
    -DENABLE_OPENJPEG=FALSE
    -DENABLE_TIFF=FALSE
    -DENABLE_WEBP=FALSE
)

list(APPEND BUILD_CMD COMMAND ninja)

list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} --install .)

if(WIN32)
    # NOTE: on Windows, leptonica names its pkg-config file after the build type
    #       (`lept_Release.pc`), while consumers (and our own builds) look it up
    #       as `lept`, so provide that name too.
    list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${STAGING_DIR}/lib/pkgconfig/lept_Release.pc
        ${STAGING_DIR}/lib/pkgconfig/lept.pc)
endif()

if(NOT MONOLIBTIC)
    append_shared_lib_install_commands(INSTALL_CMD leptonica VERSION 6)
endif()

external_project(
    # NOTE: Needs to match the version used by whatever version of libk2pdfopt we're currently using...
    #       Probably applies to mupdf & tesseract, too...
    DOWNLOAD URL 1f66c425c270e9793982289e1ff9634a
    https://github.com/DanBloomberg/leptonica/archive/refs/tags/1.87.0.tar.gz
    PATCH_FILES ${PATCH_FILES}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
