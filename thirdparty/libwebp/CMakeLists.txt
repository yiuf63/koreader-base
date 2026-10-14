list(APPEND PATCH_FILES cmake_tweaks.patch)

list(APPEND CMAKE_ARGS
    -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
    -DBUILD_SHARED_LIBS=$<NOT:$<BOOL:${MONOLIBTIC}>>
    # Project options.
    # Note: we could build libwebpdecoder.so only, which would be smaller and fine
    # decoding single frame webp images. But it fails on animated webp images, not
    # even rendering the first frame.  We need the regular libraries (`libwebp.so`
    # and `libwebpdemux.so`) to handle them (but we can left out the encoder,
    # `libwebpmux.so`).
    -DWEBP_BUILD_ANIM_UTILS=FALSE
    -DWEBP_BUILD_CWEBP=FALSE
    -DWEBP_BUILD_DWEBP=FALSE
    -DWEBP_BUILD_EXTRAS=FALSE
    -DWEBP_BUILD_GIF2WEBP=FALSE
    -DWEBP_BUILD_IMG2WEBP=FALSE
    -DWEBP_BUILD_LIBWEBPMUX=FALSE
    -DWEBP_BUILD_VWEBP=FALSE
    -DWEBP_BUILD_WEBPINFO=FALSE
    -DWEBP_BUILD_WEBPMUX=FALSE
    -DWEBP_ENABLE_SIMD=$<BOOL:${WANT_SIMD}>
)

list(APPEND BUILD_CMD COMMAND ninja)

list(APPEND INSTALL_CMD COMMAND ${CMAKE_COMMAND} --install .)

if(WIN32)
    # Put the libtool version into the DLL file names, so the project produces the
    # `lib<name>-<version>.dll` spelling KOReader installs and asks for, instead of
    # an unversioned `libwebp.dll`.
    #
    # This project needs it more than most. Its libraries depend on each other —
    # `libwebp` and `libwebpdemux` link `libsharpyuv` — and a library's own link
    # step regenerates the import archive naming whatever its producer emitted.
    # So the archive rewriting done at install time (see
    # `record_canonical_implib.sh`) is undone the moment the project relinks, and
    # the two names keep coming back. Having the project emit the canonical name
    # removes the mismatch at the source, which is the only place it can be
    # removed for an intra-project dependency.
    #
    # `CMAKE_SHARED_LIBRARY_NAME_WITH_VERSION` is what CMake uses to decide
    # whether the version belongs in the file name. It is on by default for
    # Cygwin and off elsewhere (`Modules/Platform/CYGWIN.cmake`), because ELF and
    # Mach-O carry a soname while PE does not: on those platforms the file name is
    # free, on Windows it *is* the identity a dependent resolves.
    #
    # Windows-only, and for this project only. On ELF and Mach-O the name the
    # dependent resolves comes from the soname, so the file name is free to be
    # whatever the install rules want -- and turning this on there changes what
    # `-lwebp` produces, which is not ours to change. Set on the command line
    # rather than in the shared toolchain for the same reason: globally it would
    # also suffix names that already carry a version, so tesseract -- whose DLL is
    # `libtesseract55.dll` with SOVERSION `5.5` -- would become
    # `libtesseract-55-5.5.dll`. Here the SOVERSION values are exactly the versions
    # KOReader asks for: 7 for webp, 2 for webpdemux, 0 for sharpyuv.
    list(APPEND CMAKE_ARGS -DCMAKE_SHARED_LIBRARY_NAME_WITH_VERSION=1)
endif()

if(NOT MONOLIBTIC)
    append_shared_lib_install_commands(INSTALL_CMD sharpyuv VERSION 0)
    append_shared_lib_install_commands(INSTALL_CMD webpdemux VERSION 2)
    append_shared_lib_install_commands(INSTALL_CMD webp VERSION 7)
endif()

external_project(
    DOWNLOAD URL cceb6447180f961473b181c9ef38b630
    https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz
    PATCH_FILES ${PATCH_FILES}
    CMAKE_ARGS ${CMAKE_ARGS}
    BUILD_COMMAND ${BUILD_CMD}
    INSTALL_COMMAND ${INSTALL_CMD}
)
