#ifndef MINICONV_CONFIG_H
#define MINICONV_CONFIG_H

#include <stddef.h>
#include <stdint.h>

#if defined(__BYTE_ORDER__) && defined(__ORDER_BIG_ENDIAN__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#  define __BIG_ENDIAN__
#endif

#define MINICONV_BE_ICONV
#define MINICONV_INLINE  static inline
#define MINICONV_PUBLIC  __attribute__((visibility("default")))

/* Our `iconv-proto-compat.patch` uses C99's `restrict` in the prototypes, but
   this header is also included from C++ (e.g. djvulibre's GUnicode.cpp when
   the host has no iconv of its own), where `restrict` is not a keyword. */
#if defined(__cplusplus) && !defined(restrict)
#  define restrict __restrict
#endif

typedef uint16_t miniconv_uint16_t;
typedef uint32_t miniconv_uint32_t;

#endif

// vim: ft=c
