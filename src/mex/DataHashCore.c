/* Optional hashing core, adapted from the authored round schedules in src.
 * Algorithms: RFC 1319 (MD2), RFC 1321 (MD5), and FIPS 180-4 (SHA).
 * https://www.rfc-editor.org/rfc/rfc1319
 * https://www.rfc-editor.org/rfc/rfc1321
 * https://doi.org/10.6028/NIST.FIPS.180-4
 * No external hashing library is used.
 * Copyright (c) 2026, Stefano Pradella. See ../../license.txt.
 *
 * digest = DataHashCore(bytes, method)
 * context = DataHashCore(bytes, method, contextOrEmpty, uint8(0))
 * digest = DataHashCore(bytes, method, contextOrEmpty, uint8(1))
 * Selectors: SHA-1=1, MD2=2, SHA-256=3, SHA-384=4, MD5=5, SHA-512=6.
 *
 * All arguments/results are real, full uint8 vectors; controls are scalars.
 * Digests are rows of 16/16/20/32/48/64 bytes for MD2/MD5/SHA-1/256/384/512.
 * Contexts contain no native pointers or compiler padding: an 8-byte header,
 * state, little-endian byte count, and one tail block (unused bytes zeroed).
 * State words are little-endian; MD2 stores 16 state and 16 checksum bytes.
 * SHA-384/512 store a 128-bit byte count, low uint64 first; other counts
 * are uint64. Context sizes: MD2=64, MD5=96, SHA-1=100, SHA-256=112,
 * SHA-384/512=216. The existing version-1 MD5 layout is unchanged.
 * Contexts are copied on update and may be branched without mutation.
 */

#include "mex.h"
#include <stdint.h>
#include <string.h>

/* Keep SHA instructions inside targeted functions so the MEX remains
 * loadable on x86-64 processors without them and on other architectures. */
#if defined(__x86_64__) && defined(__GNUC__)
#include <immintrin.h>
#if !defined(DATAHASH_FORCE_SOFTWARE_SHA1)
#define DATAHASH_SHA1_INTRINSICS 1
#endif
#if !defined(DATAHASH_FORCE_SOFTWARE_SHA256)
#define DATAHASH_SHA256_INTRINSICS 1
#endif
#if !defined(DATAHASH_FORCE_SOFTWARE_SHA512)
#define DATAHASH_SHA512_AVX2 1
#endif
#endif

enum {
    METHOD_SHA1 = 1,
    METHOD_MD2 = 2,
    METHOD_SHA256 = 3,
    METHOD_SHA384 = 4,
    METHOD_MD5 = 5,
    METHOD_SHA512 = 6
};

typedef union {
    uint8_t bytes[32];
    uint32_t words32[8];
    uint64_t words64[8];
} HashState;

typedef struct {
    HashState state;
    uint64_t length;
    uint64_t lengthHigh;
    uint8_t tail[128];
    uint8_t method;
    size_t blockLength;
    size_t stateLength;
    size_t digestLength;
    size_t lengthBytes;
} HashContext;

static const uint8_t contextHeader[8] = {'D', 'H', 'C', 1, 0, 0, 0, 0};

static uint32_t load32(const uint8_t *bytes)
{
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) |
        ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static void store32(uint8_t *bytes, uint32_t value)
{
    unsigned int byteIndex;
    for (byteIndex = 0; byteIndex < 4; ++byteIndex) {
        bytes[byteIndex] = (uint8_t)(value >> (8 * byteIndex));
    }
}

static uint64_t load64(const uint8_t *bytes)
{
    return (uint64_t)load32(bytes) | ((uint64_t)load32(bytes + 4) << 32);
}

static void store64(uint8_t *bytes, uint64_t value)
{
    store32(bytes, (uint32_t)value);
    store32(bytes + 4, (uint32_t)(value >> 32));
}

static uint32_t load32BigEndian(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) |
        ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static uint64_t load64BigEndian(const uint8_t *bytes)
{
    return ((uint64_t)load32BigEndian(bytes) << 32) |
        (uint64_t)load32BigEndian(bytes + 4);
}

static void store32BigEndian(uint8_t *bytes, uint32_t value)
{
    unsigned int byteIndex;
    for (byteIndex = 0; byteIndex < 4; ++byteIndex) {
        bytes[byteIndex] = (uint8_t)(value >> (24 - 8 * byteIndex));
    }
}

static void store64BigEndian(uint8_t *bytes, uint64_t value)
{
    store32BigEndian(bytes, (uint32_t)(value >> 32));
    store32BigEndian(bytes + 4, (uint32_t)value);
}

/* All rotation counts below are fixed and strictly between 0 and the width. */
static uint32_t rotateLeft32(uint32_t value, unsigned int shift)
{
    return (value << shift) | (value >> (32 - shift));
}

static uint32_t rotateRight32(uint32_t value, unsigned int shift)
{
    return (value >> shift) | (value << (32 - shift));
}

static uint64_t rotateRight64(uint64_t value, unsigned int shift)
{
    return (value >> shift) | (value << (64 - shift));
}

/* Unsigned arithmetic wraps modulo 2^32. Loads are alignment/endian safe.
 * As in the native core, fixed steps expose rotations/constants to the
 * compiler; only one 64-byte block is decoded into working storage.
 */
#define F(b, c, d) ((d) ^ ((b) & ((c) ^ (d))))
#define G(b, c, d) ((c) ^ ((d) & ((b) ^ (c))))
#define H(b, c, d) ((b) ^ (c) ^ (d))
#define I(b, c, d) ((c) ^ ((b) | ~(d)))
#define STEP(fn, a, b, c, d, word, shift, constant) do { \
    uint32_t value = (a) + fn(b, c, d) + words[word] + UINT32_C(constant); \
    (a) = (b) + ((value << (shift)) | (value >> (32 - (shift)))); \
} while (0)

static void md5Compress(uint32_t state[4], const uint8_t *block)
{
    uint32_t words[16];
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    unsigned int wordIndex;
    for (wordIndex = 0; wordIndex < 16; ++wordIndex) {
        words[wordIndex] = load32(block + 4 * wordIndex);
    }

    STEP(F, a, b, c, d,  0,  7, 3614090360);
    STEP(F, d, a, b, c,  1, 12, 3905402710);
    STEP(F, c, d, a, b,  2, 17,  606105819);
    STEP(F, b, c, d, a,  3, 22, 3250441966);
    STEP(F, a, b, c, d,  4,  7, 4118548399);
    STEP(F, d, a, b, c,  5, 12, 1200080426);
    STEP(F, c, d, a, b,  6, 17, 2821735955);
    STEP(F, b, c, d, a,  7, 22, 4249261313);
    STEP(F, a, b, c, d,  8,  7, 1770035416);
    STEP(F, d, a, b, c,  9, 12, 2336552879);
    STEP(F, c, d, a, b, 10, 17, 4294925233);
    STEP(F, b, c, d, a, 11, 22, 2304563134);
    STEP(F, a, b, c, d, 12,  7, 1804603682);
    STEP(F, d, a, b, c, 13, 12, 4254626195);
    STEP(F, c, d, a, b, 14, 17, 2792965006);
    STEP(F, b, c, d, a, 15, 22, 1236535329);

    STEP(G, a, b, c, d,  1,  5, 4129170786);
    STEP(G, d, a, b, c,  6,  9, 3225465664);
    STEP(G, c, d, a, b, 11, 14,  643717713);
    STEP(G, b, c, d, a,  0, 20, 3921069994);
    STEP(G, a, b, c, d,  5,  5, 3593408605);
    STEP(G, d, a, b, c, 10,  9,   38016083);
    STEP(G, c, d, a, b, 15, 14, 3634488961);
    STEP(G, b, c, d, a,  4, 20, 3889429448);
    STEP(G, a, b, c, d,  9,  5,  568446438);
    STEP(G, d, a, b, c, 14,  9, 3275163606);
    STEP(G, c, d, a, b,  3, 14, 4107603335);
    STEP(G, b, c, d, a,  8, 20, 1163531501);
    STEP(G, a, b, c, d, 13,  5, 2850285829);
    STEP(G, d, a, b, c,  2,  9, 4243563512);
    STEP(G, c, d, a, b,  7, 14, 1735328473);
    STEP(G, b, c, d, a, 12, 20, 2368359562);

    STEP(H, a, b, c, d,  5,  4, 4294588738);
    STEP(H, d, a, b, c,  8, 11, 2272392833);
    STEP(H, c, d, a, b, 11, 16, 1839030562);
    STEP(H, b, c, d, a, 14, 23, 4259657740);
    STEP(H, a, b, c, d,  1,  4, 2763975236);
    STEP(H, d, a, b, c,  4, 11, 1272893353);
    STEP(H, c, d, a, b,  7, 16, 4139469664);
    STEP(H, b, c, d, a, 10, 23, 3200236656);
    STEP(H, a, b, c, d, 13,  4,  681279174);
    STEP(H, d, a, b, c,  0, 11, 3936430074);
    STEP(H, c, d, a, b,  3, 16, 3572445317);
    STEP(H, b, c, d, a,  6, 23,   76029189);
    STEP(H, a, b, c, d,  9,  4, 3654602809);
    STEP(H, d, a, b, c, 12, 11, 3873151461);
    STEP(H, c, d, a, b, 15, 16,  530742520);
    STEP(H, b, c, d, a,  2, 23, 3299628645);

    STEP(I, a, b, c, d,  0,  6, 4096336452);
    STEP(I, d, a, b, c,  7, 10, 1126891415);
    STEP(I, c, d, a, b, 14, 15, 2878612391);
    STEP(I, b, c, d, a,  5, 21, 4237533241);
    STEP(I, a, b, c, d, 12,  6, 1700485571);
    STEP(I, d, a, b, c,  3, 10, 2399980690);
    STEP(I, c, d, a, b, 10, 15, 4293915773);
    STEP(I, b, c, d, a,  1, 21, 2240044497);
    STEP(I, a, b, c, d,  8,  6, 1873313359);
    STEP(I, d, a, b, c, 15, 10, 4264355552);
    STEP(I, c, d, a, b,  6, 15, 2734768916);
    STEP(I, b, c, d, a, 13, 21, 1309151649);
    STEP(I, a, b, c, d,  4,  6, 4149444226);
    STEP(I, d, a, b, c, 11, 10, 3174756917);
    STEP(I, c, d, a, b,  2, 15,  718787259);
    STEP(I, b, c, d, a,  9, 21, 3951481745);

    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
}

#undef STEP
#undef F
#undef G
#undef H
#undef I

/* RFC 1319's substitution permutation, also used by src/md2. */
static const uint8_t md2Substitution[256] = {
    41, 46, 67, 201, 162, 216, 124, 1, 61, 54, 84, 161, 236, 240, 6, 19,
    98, 167, 5, 243, 192, 199, 115, 140, 152, 147, 43, 217, 188, 76, 130, 202,
    30, 155, 87, 60, 253, 212, 224, 22, 103, 66, 111, 24, 138, 23, 229, 18,
    190, 78, 196, 214, 218, 158, 222, 73, 160, 251, 245, 142, 187, 47, 238, 122,
    169, 104, 121, 145, 21, 178, 7, 63, 148, 194, 16, 137, 11, 34, 95, 33,
    128, 127, 93, 154, 90, 144, 50, 39, 53, 62, 204, 231, 191, 247, 151, 3,
    255, 25, 48, 179, 72, 165, 181, 209, 215, 94, 146, 42, 172, 86, 170, 198,
    79, 184, 56, 210, 150, 164, 125, 182, 118, 252, 107, 226, 156, 116, 4, 241,
    69, 157, 112, 89, 100, 113, 135, 32, 134, 91, 207, 101, 230, 45, 168, 2,
    27, 96, 37, 173, 174, 176, 185, 246, 28, 70, 97, 105, 52, 64, 126, 15,
    85, 71, 163, 35, 221, 81, 175, 58, 195, 92, 249, 206, 186, 197, 234, 38,
    44, 83, 13, 110, 133, 40, 132, 9, 211, 223, 205, 244, 65, 129, 77, 82,
    106, 220, 55, 200, 108, 193, 171, 250, 36, 225, 123, 8, 12, 189, 177, 74,
    120, 136, 149, 139, 227, 99, 232, 109, 233, 203, 213, 254, 59, 0, 29, 57,
    242, 239, 183, 14, 102, 88, 208, 228, 166, 119, 114, 248, 235, 117, 75, 10,
    49, 68, 80, 180, 143, 237, 31, 26, 219, 153, 141, 51, 159, 17, 131, 20,
};

static void md2Compress(uint8_t state[32], const uint8_t *block)
{
    uint8_t working[48];
    uint8_t temporary = 0;
    uint8_t lastChecksum = state[31];
    unsigned int byteIndex, roundIndex;
    memcpy(working, state, 16);
    for (byteIndex = 0; byteIndex < 16; ++byteIndex) {
        working[16 + byteIndex] = block[byteIndex];
        working[32 + byteIndex] = (uint8_t)(state[byteIndex] ^ block[byteIndex]);
    }
    for (roundIndex = 0; roundIndex < 18; ++roundIndex) {
        for (byteIndex = 0; byteIndex < 48; ++byteIndex) {
            temporary = (uint8_t)(working[byteIndex] ^ md2Substitution[temporary]);
            working[byteIndex] = temporary;
        }
        temporary = (uint8_t)(temporary + roundIndex);
    }
    memcpy(state, working, 16);
    for (byteIndex = 0; byteIndex < 16; ++byteIndex) {
        state[16 + byteIndex] ^= md2Substitution[block[byteIndex] ^ lastChecksum];
        lastChecksum = state[16 + byteIndex];
    }
}

static void sha1Compress(uint32_t state[5], const uint8_t *block)
{
    uint32_t words[80];
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3], e = state[4];
    uint32_t temporary;
    unsigned int roundIndex;
    for (roundIndex = 0; roundIndex < 16; ++roundIndex) {
        words[roundIndex] = load32BigEndian(block + 4 * roundIndex);
    }
    for (roundIndex = 16; roundIndex < 80; ++roundIndex) {
        words[roundIndex] = rotateLeft32(words[roundIndex - 3] ^
            words[roundIndex - 8] ^ words[roundIndex - 14] ^ words[roundIndex - 16], 1);
    }
    for (roundIndex = 0; roundIndex < 20; ++roundIndex) {
        temporary = rotateLeft32(a, 5) + (d ^ (b & (c ^ d))) + e +
            UINT32_C(0x5a827999) + words[roundIndex];
        e = d;
        d = c;
        c = rotateLeft32(b, 30);
        b = a;
        a = temporary;
    }
    for (; roundIndex < 40; ++roundIndex) {
        temporary = rotateLeft32(a, 5) + (b ^ c ^ d) + e +
            UINT32_C(0x6ed9eba1) + words[roundIndex];
        e = d;
        d = c;
        c = rotateLeft32(b, 30);
        b = a;
        a = temporary;
    }
    for (; roundIndex < 60; ++roundIndex) {
        temporary = rotateLeft32(a, 5) + ((b & c) ^ (d & (b ^ c))) + e +
            UINT32_C(0x8f1bbcdc) + words[roundIndex];
        e = d;
        d = c;
        c = rotateLeft32(b, 30);
        b = a;
        a = temporary;
    }
    for (; roundIndex < 80; ++roundIndex) {
        temporary = rotateLeft32(a, 5) + (b ^ c ^ d) + e +
            UINT32_C(0xca62c1d6) + words[roundIndex];
        e = d;
        d = c;
        c = rotateLeft32(b, 30);
        b = a;
        a = temporary;
    }
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
}

#if defined(DATAHASH_SHA1_INTRINSICS)
/* SHA1RNDS4 consumes A/B/C/D and four big-endian schedule words in reverse
 * lane order. SHA1NEXTE supplies E from the A value four rounds earlier.
 * The message schedule uses the same scalar expansion as the fallback.
 * Instruction behavior follows Intel's SHA Extensions reference:
 * https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sha-extensions.html */
__attribute__((target("sha")))
static void sha1CompressSha(uint32_t state[5], const uint8_t *block)
{
    uint32_t words[80];
    unsigned int roundIndex, groupIndex;
    __m128i abcd, savedAbcd, savedE, previousAbcd, message, withE;
    for (roundIndex = 0; roundIndex < 16; ++roundIndex) {
        words[roundIndex] = load32BigEndian(block + 4 * roundIndex);
    }
    for (roundIndex = 16; roundIndex < 80; ++roundIndex) {
        words[roundIndex] = rotateLeft32(words[roundIndex - 3] ^
            words[roundIndex - 8] ^ words[roundIndex - 14] ^ words[roundIndex - 16], 1);
    }

    abcd = _mm_shuffle_epi32(_mm_loadu_si128((const __m128i *)state), 0x1b);
    savedAbcd = abcd;
    savedE = _mm_slli_si128(_mm_cvtsi32_si128((int)state[4]), 12);
    message = _mm_shuffle_epi32(_mm_loadu_si128((const __m128i *)words), 0x1b);
    withE = _mm_add_epi32(savedE, message);
    previousAbcd = abcd;
    abcd = _mm_sha1rnds4_epu32(abcd, withE, 0);
    for (groupIndex = 1; groupIndex < 5; ++groupIndex) {
        message = _mm_shuffle_epi32(
            _mm_loadu_si128((const __m128i *)(words + 4 * groupIndex)), 0x1b);
        withE = _mm_sha1nexte_epu32(previousAbcd, message);
        previousAbcd = abcd;
        abcd = _mm_sha1rnds4_epu32(abcd, withE, 0);
    }
    for (; groupIndex < 10; ++groupIndex) {
        message = _mm_shuffle_epi32(
            _mm_loadu_si128((const __m128i *)(words + 4 * groupIndex)), 0x1b);
        withE = _mm_sha1nexte_epu32(previousAbcd, message);
        previousAbcd = abcd;
        abcd = _mm_sha1rnds4_epu32(abcd, withE, 1);
    }
    for (; groupIndex < 15; ++groupIndex) {
        message = _mm_shuffle_epi32(
            _mm_loadu_si128((const __m128i *)(words + 4 * groupIndex)), 0x1b);
        withE = _mm_sha1nexte_epu32(previousAbcd, message);
        previousAbcd = abcd;
        abcd = _mm_sha1rnds4_epu32(abcd, withE, 2);
    }
    for (; groupIndex < 20; ++groupIndex) {
        message = _mm_shuffle_epi32(
            _mm_loadu_si128((const __m128i *)(words + 4 * groupIndex)), 0x1b);
        withE = _mm_sha1nexte_epu32(previousAbcd, message);
        previousAbcd = abcd;
        abcd = _mm_sha1rnds4_epu32(abcd, withE, 3);
    }

    withE = _mm_sha1nexte_epu32(previousAbcd, savedE);
    abcd = _mm_add_epi32(abcd, savedAbcd);
    _mm_storeu_si128((__m128i *)state, _mm_shuffle_epi32(abcd, 0x1b));
    state[4] = (uint32_t)_mm_cvtsi128_si32(_mm_srli_si128(withE, 12));
}
#endif

/* FIPS 180-4 round constants; fixed-width literals avoid host integer sizes. */
static const uint32_t sha256Constants[64] = {
    UINT32_C(0x428a2f98), UINT32_C(0x71374491), UINT32_C(0xb5c0fbcf), UINT32_C(0xe9b5dba5),
    UINT32_C(0x3956c25b), UINT32_C(0x59f111f1), UINT32_C(0x923f82a4), UINT32_C(0xab1c5ed5),
    UINT32_C(0xd807aa98), UINT32_C(0x12835b01), UINT32_C(0x243185be), UINT32_C(0x550c7dc3),
    UINT32_C(0x72be5d74), UINT32_C(0x80deb1fe), UINT32_C(0x9bdc06a7), UINT32_C(0xc19bf174),
    UINT32_C(0xe49b69c1), UINT32_C(0xefbe4786), UINT32_C(0x0fc19dc6), UINT32_C(0x240ca1cc),
    UINT32_C(0x2de92c6f), UINT32_C(0x4a7484aa), UINT32_C(0x5cb0a9dc), UINT32_C(0x76f988da),
    UINT32_C(0x983e5152), UINT32_C(0xa831c66d), UINT32_C(0xb00327c8), UINT32_C(0xbf597fc7),
    UINT32_C(0xc6e00bf3), UINT32_C(0xd5a79147), UINT32_C(0x06ca6351), UINT32_C(0x14292967),
    UINT32_C(0x27b70a85), UINT32_C(0x2e1b2138), UINT32_C(0x4d2c6dfc), UINT32_C(0x53380d13),
    UINT32_C(0x650a7354), UINT32_C(0x766a0abb), UINT32_C(0x81c2c92e), UINT32_C(0x92722c85),
    UINT32_C(0xa2bfe8a1), UINT32_C(0xa81a664b), UINT32_C(0xc24b8b70), UINT32_C(0xc76c51a3),
    UINT32_C(0xd192e819), UINT32_C(0xd6990624), UINT32_C(0xf40e3585), UINT32_C(0x106aa070),
    UINT32_C(0x19a4c116), UINT32_C(0x1e376c08), UINT32_C(0x2748774c), UINT32_C(0x34b0bcb5),
    UINT32_C(0x391c0cb3), UINT32_C(0x4ed8aa4a), UINT32_C(0x5b9cca4f), UINT32_C(0x682e6ff3),
    UINT32_C(0x748f82ee), UINT32_C(0x78a5636f), UINT32_C(0x84c87814), UINT32_C(0x8cc70208),
    UINT32_C(0x90befffa), UINT32_C(0xa4506ceb), UINT32_C(0xbef9a3f7), UINT32_C(0xc67178f2),
};

static const uint64_t sha512Constants[80] = {
    UINT64_C(0x428a2f98d728ae22), UINT64_C(0x7137449123ef65cd),
    UINT64_C(0xb5c0fbcfec4d3b2f), UINT64_C(0xe9b5dba58189dbbc),
    UINT64_C(0x3956c25bf348b538), UINT64_C(0x59f111f1b605d019),
    UINT64_C(0x923f82a4af194f9b), UINT64_C(0xab1c5ed5da6d8118),
    UINT64_C(0xd807aa98a3030242), UINT64_C(0x12835b0145706fbe),
    UINT64_C(0x243185be4ee4b28c), UINT64_C(0x550c7dc3d5ffb4e2),
    UINT64_C(0x72be5d74f27b896f), UINT64_C(0x80deb1fe3b1696b1),
    UINT64_C(0x9bdc06a725c71235), UINT64_C(0xc19bf174cf692694),
    UINT64_C(0xe49b69c19ef14ad2), UINT64_C(0xefbe4786384f25e3),
    UINT64_C(0x0fc19dc68b8cd5b5), UINT64_C(0x240ca1cc77ac9c65),
    UINT64_C(0x2de92c6f592b0275), UINT64_C(0x4a7484aa6ea6e483),
    UINT64_C(0x5cb0a9dcbd41fbd4), UINT64_C(0x76f988da831153b5),
    UINT64_C(0x983e5152ee66dfab), UINT64_C(0xa831c66d2db43210),
    UINT64_C(0xb00327c898fb213f), UINT64_C(0xbf597fc7beef0ee4),
    UINT64_C(0xc6e00bf33da88fc2), UINT64_C(0xd5a79147930aa725),
    UINT64_C(0x06ca6351e003826f), UINT64_C(0x142929670a0e6e70),
    UINT64_C(0x27b70a8546d22ffc), UINT64_C(0x2e1b21385c26c926),
    UINT64_C(0x4d2c6dfc5ac42aed), UINT64_C(0x53380d139d95b3df),
    UINT64_C(0x650a73548baf63de), UINT64_C(0x766a0abb3c77b2a8),
    UINT64_C(0x81c2c92e47edaee6), UINT64_C(0x92722c851482353b),
    UINT64_C(0xa2bfe8a14cf10364), UINT64_C(0xa81a664bbc423001),
    UINT64_C(0xc24b8b70d0f89791), UINT64_C(0xc76c51a30654be30),
    UINT64_C(0xd192e819d6ef5218), UINT64_C(0xd69906245565a910),
    UINT64_C(0xf40e35855771202a), UINT64_C(0x106aa07032bbd1b8),
    UINT64_C(0x19a4c116b8d2d0c8), UINT64_C(0x1e376c085141ab53),
    UINT64_C(0x2748774cdf8eeb99), UINT64_C(0x34b0bcb5e19b48a8),
    UINT64_C(0x391c0cb3c5c95a63), UINT64_C(0x4ed8aa4ae3418acb),
    UINT64_C(0x5b9cca4f7763e373), UINT64_C(0x682e6ff3d6b2b8a3),
    UINT64_C(0x748f82ee5defb2fc), UINT64_C(0x78a5636f43172f60),
    UINT64_C(0x84c87814a1f0ab72), UINT64_C(0x8cc702081a6439ec),
    UINT64_C(0x90befffa23631e28), UINT64_C(0xa4506cebde82bde9),
    UINT64_C(0xbef9a3f7b2c67915), UINT64_C(0xc67178f2e372532b),
    UINT64_C(0xca273eceea26619c), UINT64_C(0xd186b8c721c0c207),
    UINT64_C(0xeada7dd6cde0eb1e), UINT64_C(0xf57d4f7fee6ed178),
    UINT64_C(0x06f067aa72176fba), UINT64_C(0x0a637dc5a2c898a6),
    UINT64_C(0x113f9804bef90dae), UINT64_C(0x1b710b35131c471b),
    UINT64_C(0x28db77f523047d84), UINT64_C(0x32caab7b40c72493),
    UINT64_C(0x3c9ebe0a15c9bebc), UINT64_C(0x431d67c49c100d4c),
    UINT64_C(0x4cc5d4becb3e42b6), UINT64_C(0x597f299cfc657e2a),
    UINT64_C(0x5fcb6fab3ad6faec), UINT64_C(0x6c44198c4a475817),
};

static void sha256Compress(uint32_t state[8], const uint8_t *block)
{
    uint32_t words[64];
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t e = state[4], f = state[5], g = state[6], h = state[7];
    uint32_t sigma0, sigma1, temporary1, temporary2;
    unsigned int roundIndex;
    for (roundIndex = 0; roundIndex < 16; ++roundIndex) {
        words[roundIndex] = load32BigEndian(block + 4 * roundIndex);
    }
    for (roundIndex = 16; roundIndex < 64; ++roundIndex) {
        sigma0 = rotateRight32(words[roundIndex - 15], 7) ^
            rotateRight32(words[roundIndex - 15], 18) ^ (words[roundIndex - 15] >> 3);
        sigma1 = rotateRight32(words[roundIndex - 2], 17) ^
            rotateRight32(words[roundIndex - 2], 19) ^ (words[roundIndex - 2] >> 10);
        words[roundIndex] = words[roundIndex - 16] + sigma0 +
            words[roundIndex - 7] + sigma1;
    }
    for (roundIndex = 0; roundIndex < 64; ++roundIndex) {
        sigma1 = rotateRight32(e, 6) ^ rotateRight32(e, 11) ^ rotateRight32(e, 25);
        temporary1 = h + sigma1 + (g ^ (e & (f ^ g))) +
            sha256Constants[roundIndex] + words[roundIndex];
        sigma0 = rotateRight32(a, 2) ^ rotateRight32(a, 13) ^ rotateRight32(a, 22);
        temporary2 = sigma0 + ((a & b) ^ (c & (a ^ b)));
        h = g;
        g = f;
        f = e;
        e = d + temporary1;
        d = c;
        c = b;
        b = a;
        a = temporary1 + temporary2;
    }
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
}

#if defined(DATAHASH_SHA256_INTRINSICS)
/* SHA256RNDS2 consumes A/B/E/F and C/D/G/H in separate vectors, with four
 * schedule-plus-constant words supplied as two successive round pairs.
 * The state layout follows Intel's SHA Extensions reference:
 * https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sha-extensions.html */
__attribute__((target("sha")))
static void sha256CompressSha(uint32_t state[8], const uint8_t *block)
{
    uint32_t words[64];
    uint32_t abef[4], cdgh[4];
    uint32_t sigma0, sigma1;
    unsigned int roundIndex;
    __m128i state0, state1, saved0, saved1, message;
    for (roundIndex = 0; roundIndex < 16; ++roundIndex) {
        words[roundIndex] = load32BigEndian(block + 4 * roundIndex);
    }
    for (roundIndex = 16; roundIndex < 64; ++roundIndex) {
        sigma0 = rotateRight32(words[roundIndex - 15], 7) ^
            rotateRight32(words[roundIndex - 15], 18) ^ (words[roundIndex - 15] >> 3);
        sigma1 = rotateRight32(words[roundIndex - 2], 17) ^
            rotateRight32(words[roundIndex - 2], 19) ^ (words[roundIndex - 2] >> 10);
        words[roundIndex] = words[roundIndex - 16] + sigma0 +
            words[roundIndex - 7] + sigma1;
    }

    state0 = _mm_set_epi32((int)state[0], (int)state[1], (int)state[4], (int)state[5]);
    state1 = _mm_set_epi32((int)state[2], (int)state[3], (int)state[6], (int)state[7]);
    saved0 = state0;
    saved1 = state1;
    for (roundIndex = 0; roundIndex < 64; roundIndex += 4) {
        message = _mm_add_epi32(
            _mm_loadu_si128((const __m128i *)(words + roundIndex)),
            _mm_loadu_si128((const __m128i *)(sha256Constants + roundIndex)));
        state1 = _mm_sha256rnds2_epu32(state1, state0, message);
        message = _mm_shuffle_epi32(message, 0x0e);
        state0 = _mm_sha256rnds2_epu32(state0, state1, message);
    }
    state0 = _mm_add_epi32(state0, saved0);
    state1 = _mm_add_epi32(state1, saved1);
    _mm_storeu_si128((__m128i *)abef, state0);
    _mm_storeu_si128((__m128i *)cdgh, state1);
    state[0] = abef[3];
    state[1] = abef[2];
    state[2] = cdgh[3];
    state[3] = cdgh[2];
    state[4] = abef[1];
    state[5] = abef[0];
    state[6] = cdgh[1];
    state[7] = cdgh[0];
}
#endif

static void sha512Compress(uint64_t state[8], const uint8_t *block)
{
    uint64_t words[80];
    uint64_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint64_t e = state[4], f = state[5], g = state[6], h = state[7];
    uint64_t sigma0, sigma1, temporary1, temporary2;
    unsigned int roundIndex;
    for (roundIndex = 0; roundIndex < 16; ++roundIndex) {
        words[roundIndex] = load64BigEndian(block + 8 * roundIndex);
    }
    for (roundIndex = 16; roundIndex < 80; ++roundIndex) {
        sigma0 = rotateRight64(words[roundIndex - 15], 1) ^
            rotateRight64(words[roundIndex - 15], 8) ^ (words[roundIndex - 15] >> 7);
        sigma1 = rotateRight64(words[roundIndex - 2], 19) ^
            rotateRight64(words[roundIndex - 2], 61) ^ (words[roundIndex - 2] >> 6);
        words[roundIndex] = words[roundIndex - 16] + sigma0 +
            words[roundIndex - 7] + sigma1;
    }
    for (roundIndex = 0; roundIndex < 80; ++roundIndex) {
        sigma1 = rotateRight64(e, 14) ^ rotateRight64(e, 18) ^ rotateRight64(e, 41);
        temporary1 = h + sigma1 + (g ^ (e & (f ^ g))) +
            sha512Constants[roundIndex] + words[roundIndex];
        sigma0 = rotateRight64(a, 28) ^ rotateRight64(a, 34) ^ rotateRight64(a, 39);
        temporary2 = sigma0 + ((a & b) ^ (c & (a ^ b)));
        h = g;
        g = f;
        f = e;
        e = d + temporary1;
        d = c;
        c = b;
        b = a;
        a = temporary1 + temporary2;
    }
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
}

#if defined(DATAHASH_SHA512_AVX2)
/* Expand four independent block schedules in AVX2 lanes. Their compression
 * rounds still run in input order because each block depends on the prior state. */
__attribute__((target("avx2")))
static void sha512CompressBlocksAvx2(uint64_t state[8], const uint8_t *bytes,
    size_t blockCount)
{
    uint64_t words[80][4];
    size_t blockIndex;
    unsigned int roundIndex, laneIndex;

    for (blockIndex = 0; blockIndex + 4 <= blockCount; blockIndex += 4) {
        for (roundIndex = 0; roundIndex < 16; ++roundIndex) {
            for (laneIndex = 0; laneIndex < 4; ++laneIndex) {
                words[roundIndex][laneIndex] = load64BigEndian(
                    bytes + 128 * (blockIndex + laneIndex) + 8 * roundIndex);
            }
        }
        for (roundIndex = 16; roundIndex < 80; ++roundIndex) {
            __m256i x = _mm256_loadu_si256((const __m256i *)words[roundIndex - 15]);
            __m256i y = _mm256_loadu_si256((const __m256i *)words[roundIndex - 2]);
            __m256i sigma0 = _mm256_xor_si256(
                _mm256_xor_si256(
                    _mm256_or_si256(_mm256_srli_epi64(x, 1), _mm256_slli_epi64(x, 63)),
                    _mm256_or_si256(_mm256_srli_epi64(x, 8), _mm256_slli_epi64(x, 56))),
                _mm256_srli_epi64(x, 7));
            __m256i sigma1 = _mm256_xor_si256(
                _mm256_xor_si256(
                    _mm256_or_si256(_mm256_srli_epi64(y, 19), _mm256_slli_epi64(y, 45)),
                    _mm256_or_si256(_mm256_srli_epi64(y, 61), _mm256_slli_epi64(y, 3))),
                _mm256_srli_epi64(y, 6));
            __m256i sum = _mm256_add_epi64(
                _mm256_add_epi64(
                    _mm256_loadu_si256((const __m256i *)words[roundIndex - 16]), sigma0),
                _mm256_add_epi64(
                    _mm256_loadu_si256((const __m256i *)words[roundIndex - 7]), sigma1));
            _mm256_storeu_si256((__m256i *)words[roundIndex], sum);
        }
        for (laneIndex = 0; laneIndex < 4; ++laneIndex) {
            uint64_t a = state[0], b = state[1], c = state[2], d = state[3];
            uint64_t e = state[4], f = state[5], g = state[6], h = state[7];
            for (roundIndex = 0; roundIndex < 80; ++roundIndex) {
                uint64_t sigma1 = rotateRight64(e, 14) ^ rotateRight64(e, 18) ^
                    rotateRight64(e, 41);
                uint64_t temporary1 = h + sigma1 + (g ^ (e & (f ^ g))) +
                    sha512Constants[roundIndex] + words[roundIndex][laneIndex];
                uint64_t sigma0 = rotateRight64(a, 28) ^ rotateRight64(a, 34) ^
                    rotateRight64(a, 39);
                uint64_t temporary2 = sigma0 + ((a & b) ^ (c & (a ^ b)));
                h = g;
                g = f;
                f = e;
                e = d + temporary1;
                d = c;
                c = b;
                b = a;
                a = temporary1 + temporary2;
            }
            state[0] += a;
            state[1] += b;
            state[2] += c;
            state[3] += d;
            state[4] += e;
            state[5] += f;
            state[6] += g;
            state[7] += h;
        }
    }
    for (; blockIndex < blockCount; ++blockIndex) {
        sha512Compress(state, bytes + 128 * blockIndex);
    }
}
#endif

static void initializeContext(HashContext *context, uint8_t method)
{
    static const uint32_t sha1Initial[5] = {
        UINT32_C(0x67452301), UINT32_C(0xefcdab89), UINT32_C(0x98badcfe),
        UINT32_C(0x10325476), UINT32_C(0xc3d2e1f0)
    };
    static const uint32_t sha256Initial[8] = {
        UINT32_C(0x6a09e667), UINT32_C(0xbb67ae85), UINT32_C(0x3c6ef372),
        UINT32_C(0xa54ff53a), UINT32_C(0x510e527f), UINT32_C(0x9b05688c),
        UINT32_C(0x1f83d9ab), UINT32_C(0x5be0cd19)
    };
    static const uint64_t sha384Initial[8] = {
        UINT64_C(0xcbbb9d5dc1059ed8), UINT64_C(0x629a292a367cd507),
        UINT64_C(0x9159015a3070dd17), UINT64_C(0x152fecd8f70e5939),
        UINT64_C(0x67332667ffc00b31), UINT64_C(0x8eb44a8768581511),
        UINT64_C(0xdb0c2e0d64f98fa7), UINT64_C(0x47b5481dbefa4fa4)
    };
    static const uint64_t sha512Initial[8] = {
        UINT64_C(0x6a09e667f3bcc908), UINT64_C(0xbb67ae8584caa73b),
        UINT64_C(0x3c6ef372fe94f82b), UINT64_C(0xa54ff53a5f1d36f1),
        UINT64_C(0x510e527fade682d1), UINT64_C(0x9b05688c2b3e6c1f),
        UINT64_C(0x1f83d9abfb41bd6b), UINT64_C(0x5be0cd19137e2179)
    };
    memset(context, 0, sizeof(*context));
    context->method = method;
    context->blockLength = 64;
    context->lengthBytes = 8;
    switch (method) {
        case METHOD_MD2:
            context->blockLength = 16;
            context->stateLength = 32;
            context->digestLength = 16;
            break;
        case METHOD_MD5:
            context->stateLength = 16;
            context->digestLength = 16;
            memcpy(context->state.words32, sha1Initial, 16);
            break;
        case METHOD_SHA1:
            context->stateLength = 20;
            context->digestLength = 20;
            memcpy(context->state.words32, sha1Initial, sizeof(sha1Initial));
            break;
        case METHOD_SHA256:
            context->stateLength = 32;
            context->digestLength = 32;
            memcpy(context->state.words32, sha256Initial, sizeof(sha256Initial));
            break;
        case METHOD_SHA384:
        case METHOD_SHA512:
            context->blockLength = 128;
            context->stateLength = 64;
            context->digestLength = method == METHOD_SHA384 ? 48 : 64;
            context->lengthBytes = 16;
            memcpy(context->state.words64,
                method == METHOD_SHA384 ? sha384Initial : sha512Initial,
                sizeof(sha512Initial));
            break;
    }
}

/* Select once per group of blocks, keeping dispatch out of the block loop. */
static void compressBlocks(HashContext *context, const uint8_t *bytes, size_t blockCount)
{
    size_t blockIndex;
    switch (context->method) {
        case METHOD_MD2:
            for (blockIndex = 0; blockIndex < blockCount; ++blockIndex) {
                md2Compress(context->state.bytes, bytes + 16 * blockIndex);
            }
            break;
        case METHOD_MD5:
            for (blockIndex = 0; blockIndex < blockCount; ++blockIndex) {
                md5Compress(context->state.words32, bytes + 64 * blockIndex);
            }
            break;
        case METHOD_SHA1:
#if defined(DATAHASH_SHA1_INTRINSICS)
            if (__builtin_cpu_supports("sha")) {
                for (blockIndex = 0; blockIndex < blockCount; ++blockIndex) {
                    sha1CompressSha(context->state.words32, bytes + 64 * blockIndex);
                }
                break;
            }
#endif
            for (blockIndex = 0; blockIndex < blockCount; ++blockIndex) {
                sha1Compress(context->state.words32, bytes + 64 * blockIndex);
            }
            break;
        case METHOD_SHA256:
#if defined(DATAHASH_SHA256_INTRINSICS)
            if (__builtin_cpu_supports("sha")) {
                for (blockIndex = 0; blockIndex < blockCount; ++blockIndex) {
                    sha256CompressSha(context->state.words32, bytes + 64 * blockIndex);
                }
                break;
            }
#endif
            for (blockIndex = 0; blockIndex < blockCount; ++blockIndex) {
                sha256Compress(context->state.words32, bytes + 64 * blockIndex);
            }
            break;
        case METHOD_SHA384:
        case METHOD_SHA512:
#if defined(DATAHASH_SHA512_AVX2)
            if (__builtin_cpu_supports("avx2") && blockCount >= 4) {
                sha512CompressBlocksAvx2(context->state.words64, bytes, blockCount);
                break;
            }
#endif
            for (blockIndex = 0; blockIndex < blockCount; ++blockIndex) {
                sha512Compress(context->state.words64, bytes + 128 * blockIndex);
            }
            break;
    }
}

static void hashUpdate(HashContext *context, const uint8_t *bytes, size_t length)
{
    size_t tailLength = (size_t)(context->length & (context->blockLength - 1));
    size_t copyLength, fullLength;
    uint64_t previousLength = context->length;
    context->length += (uint64_t)length;
    if (context->length < previousLength) {
        ++context->lengthHigh;
    }
    if (length == 0) {
        return;
    }
    if (tailLength != 0) {
        copyLength = context->blockLength - tailLength;
        if (copyLength > length) {
            copyLength = length;
        }
        memcpy(context->tail + tailLength, bytes, copyLength);
        bytes += copyLength;
        length -= copyLength;
        if (tailLength + copyLength < context->blockLength) {
            return;
        }
        compressBlocks(context, context->tail, 1);
    }
    fullLength = length - length % context->blockLength;
    if (fullLength != 0) {
        compressBlocks(context, bytes, fullLength / context->blockLength);
        bytes += fullLength;
        length -= fullLength;
    }
    if (length != 0) {
        memcpy(context->tail, bytes, length);
    }
}

static void hashFinalize(HashContext *context, uint8_t *digest)
{
    uint8_t padding[256] = {0};
    size_t tailLength = (size_t)(context->length & (context->blockLength - 1));
    size_t finalLength, wordIndex;
    memcpy(padding, context->tail, tailLength);
    if (context->method == METHOD_MD2) {
        memset(padding + tailLength, (int)(16 - tailLength), 16 - tailLength);
        md2Compress(context->state.bytes, padding);
        /* Snapshot the checksum after padding, before processing its block. */
        memcpy(padding, context->state.bytes + 16, 16);
        md2Compress(context->state.bytes, padding);
        memcpy(digest, context->state.bytes, 16);
        return;
    }
    finalLength = tailLength < context->blockLength - context->lengthBytes ?
        context->blockLength : 2 * context->blockLength;
    padding[tailLength] = 128;
    if (context->method == METHOD_MD5) {
        store64(padding + finalLength - 8, context->length << 3);
    } else {
        store64BigEndian(padding + finalLength - 8, context->length << 3);
        if (context->lengthBytes == 16) {
            store64BigEndian(padding + finalLength - 16,
                (context->lengthHigh << 3) | (context->length >> 61));
        }
    }
    compressBlocks(context, padding, finalLength / context->blockLength);
    if (context->lengthBytes == 16) {
        for (wordIndex = 0; wordIndex < context->digestLength / 8; ++wordIndex) {
            store64BigEndian(digest + 8 * wordIndex, context->state.words64[wordIndex]);
        }
    } else {
        for (wordIndex = 0; wordIndex < context->digestLength / 4; ++wordIndex) {
            if (context->method == METHOD_MD5) {
                store32(digest + 4 * wordIndex, context->state.words32[wordIndex]);
            } else {
                store32BigEndian(digest + 4 * wordIndex, context->state.words32[wordIndex]);
            }
        }
    }
}

static int isByteVector(const mxArray *value)
{
    return mxIsUint8(value) && !mxIsComplex(value) && !mxIsSparse(value) &&
        mxGetNumberOfDimensions(value) == 2 &&
        (mxGetM(value) == 1 || mxGetN(value) == 1 ||
         mxGetNumberOfElements(value) == 0);
}

static size_t contextLength(const HashContext *context)
{
    return 8 + context->stateLength + context->lengthBytes + context->blockLength;
}

static void readContext(HashContext *context, const mxArray *value)
{
    const uint8_t *bytes;
    uint8_t expectedHeader[8];
    size_t wordIndex, lengthOffset;
    if (!isByteVector(value)) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidContext", "Context must be a uint8 vector.");
    }
    if (mxGetNumberOfElements(value) == 0) {
        return;
    }
    if (mxGetNumberOfElements(value) != contextLength(context)) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidContext",
            "Context size does not match the selected method.");
    }
    bytes = mxGetUint8s(value);
    memcpy(expectedHeader, contextHeader, 8);
    expectedHeader[4] = context->method;
    if (memcmp(bytes, expectedHeader, 8) != 0) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidContext", "Incompatible context version or method.");
    }
    if (context->method == METHOD_MD2) {
        memcpy(context->state.bytes, bytes + 8, context->stateLength);
    } else if (context->lengthBytes == 16) {
        for (wordIndex = 0; wordIndex < context->stateLength / 8; ++wordIndex) {
            context->state.words64[wordIndex] = load64(bytes + 8 + 8 * wordIndex);
        }
    } else {
        for (wordIndex = 0; wordIndex < context->stateLength / 4; ++wordIndex) {
            context->state.words32[wordIndex] = load32(bytes + 8 + 4 * wordIndex);
        }
    }
    lengthOffset = 8 + context->stateLength;
    context->length = load64(bytes + lengthOffset);
    if (context->lengthBytes == 16) {
        context->lengthHigh = load64(bytes + lengthOffset + 8);
    }
    memcpy(context->tail, bytes + lengthOffset + context->lengthBytes, context->blockLength);
}

static void writeContext(const HashContext *context, uint8_t *bytes)
{
    size_t wordIndex, lengthOffset;
    memcpy(bytes, contextHeader, 8);
    bytes[4] = context->method;
    if (context->method == METHOD_MD2) {
        memcpy(bytes + 8, context->state.bytes, context->stateLength);
    } else if (context->lengthBytes == 16) {
        for (wordIndex = 0; wordIndex < context->stateLength / 8; ++wordIndex) {
            store64(bytes + 8 + 8 * wordIndex, context->state.words64[wordIndex]);
        }
    } else {
        for (wordIndex = 0; wordIndex < context->stateLength / 4; ++wordIndex) {
            store32(bytes + 8 + 4 * wordIndex, context->state.words32[wordIndex]);
        }
    }
    lengthOffset = 8 + context->stateLength;
    store64(bytes + lengthOffset, context->length);
    if (context->lengthBytes == 16) {
        store64(bytes + lengthOffset + 8, context->lengthHigh);
    }
    /* MXCREATENUMERICMATRIX zeroes unused tail bytes in the output. */
    memcpy(bytes + lengthOffset + context->lengthBytes, context->tail,
        (size_t)(context->length & (context->blockLength - 1)));
}

void mexFunction(int outputCount, mxArray *outputs[], int inputCount,
                 const mxArray *inputs[])
{
    HashContext context;
    uint8_t *result;
    uint8_t method;
    int finalize = 1;
    if (inputCount != 2 && inputCount != 4) {
        mexErrMsgIdAndTxt("DataHashCore:ArgumentCount", "Expected two or four inputs.");
    }
    if (outputCount != 1) {
        mexErrMsgIdAndTxt("DataHashCore:OutputCount", "Expected one output.");
    }
    if (!isByteVector(inputs[0])) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidBytes", "Bytes must be a real, full uint8 vector.");
    }
    if (!isByteVector(inputs[1]) || mxGetNumberOfElements(inputs[1]) != 1 ||
        mxGetUint8s(inputs[1])[0] < METHOD_SHA1 ||
        mxGetUint8s(inputs[1])[0] > METHOD_SHA512) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidMethod",
            "Method must be uint8: SHA-1=1, MD2=2, SHA-256=3, SHA-384=4, MD5=5, SHA-512=6.");
    }
    method = mxGetUint8s(inputs[1])[0];
    initializeContext(&context, method);
    if (inputCount == 4) {
        if (!isByteVector(inputs[3]) || mxGetNumberOfElements(inputs[3]) != 1 ||
            mxGetUint8s(inputs[3])[0] > 1) {
            mexErrMsgIdAndTxt("DataHashCore:InvalidOperation", "Finalize must be uint8(0) or uint8(1).");
        }
        finalize = mxGetUint8s(inputs[3])[0];
        readContext(&context, inputs[2]);
    }
    hashUpdate(&context, mxGetUint8s(inputs[0]),
        (size_t)mxGetNumberOfElements(inputs[0]));
    outputs[0] = mxCreateNumericMatrix(1,
        finalize ? context.digestLength : contextLength(&context), mxUINT8_CLASS, mxREAL);
    result = mxGetUint8s(outputs[0]);
    if (finalize) {
        hashFinalize(&context, result);
    } else {
        writeContext(&context, result);
    }
}
