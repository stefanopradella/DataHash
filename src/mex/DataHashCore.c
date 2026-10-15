/* Optional MD5 hashing core, adapted from src/md5's round schedule.
 * Algorithm: RFC 1321, section 3. No external hashing library is used.
 * Copyright (c) 2026, Stefano Pradella. See ../../license.txt.
 *
 * digest = DataHashCore(bytes, uint8(5))
 * context = DataHashCore(bytes, uint8(5), contextOrEmpty, uint8(0))
 * digest = DataHashCore(bytes, uint8(5), contextOrEmpty, uint8(1))
 *
 * All arguments/results are real, full uint8 vectors; controls are scalars.
 * Digests are 1-by-16, contexts 1-by-96. Contexts contain no native pointers
 * or padding: 8-byte version/method header, four little-endian state words,
 * little-endian uint64 byte count, and 64 tail bytes (unused bytes zeroed).
 * Contexts are private to this ABI, copied on update, and may be branched.
 */

#include "mex.h"
#include <stdint.h>
#include <string.h>

typedef struct {
    uint32_t state[4];
    uint64_t length;
    uint8_t tail[64];
} Md5Context;

static const uint8_t contextHeader[8] = {'D', 'H', 'C', 1, 5, 0, 0, 0};

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

static void md5Update(Md5Context *context, const uint8_t *bytes, size_t length)
{
    size_t tailLength = (size_t)(context->length & 63);
    size_t copyLength;
    context->length += (uint64_t)length; /* MD5 counts bits modulo 2^64. */
    if (length == 0) {
        return;
    }
    if (tailLength != 0) {
        copyLength = 64 - tailLength;
        if (copyLength > length) {
            copyLength = length;
        }
        memcpy(context->tail + tailLength, bytes, copyLength);
        bytes += copyLength;
        length -= copyLength;
        if (tailLength + copyLength < 64) {
            return;
        }
        md5Compress(context->state, context->tail);
    }
    while (length >= 64) {
        md5Compress(context->state, bytes);
        bytes += 64;
        length -= 64;
    }
    if (length != 0) {
        memcpy(context->tail, bytes, length);
    }
}

static void md5Finalize(Md5Context *context, uint8_t *digest)
{
    uint8_t padding[128] = {0};
    uint64_t bitLength = context->length << 3;
    size_t tailLength = (size_t)(context->length & 63);
    size_t finalLength = tailLength < 56 ? 64 : 128;
    unsigned int byteIndex;
    memcpy(padding, context->tail, tailLength);
    padding[tailLength] = 128;
    for (byteIndex = 0; byteIndex < 8; ++byteIndex) {
        padding[finalLength - 8 + byteIndex] =
            (uint8_t)(bitLength >> (8 * byteIndex));
    }
    md5Compress(context->state, padding);
    if (finalLength == 128) {
        md5Compress(context->state, padding + 64);
    }
    for (byteIndex = 0; byteIndex < 4; ++byteIndex) {
        store32(digest + 4 * byteIndex, context->state[byteIndex]);
    }
}

static int isByteVector(const mxArray *value)
{
    return mxIsUint8(value) && !mxIsComplex(value) && !mxIsSparse(value) &&
        mxGetNumberOfDimensions(value) == 2 &&
        (mxGetM(value) == 1 || mxGetN(value) == 1 ||
         mxGetNumberOfElements(value) == 0);
}

static void readContext(Md5Context *context, const mxArray *value)
{
    const uint8_t *bytes;
    unsigned int wordIndex;
    if (!isByteVector(value)) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidContext", "Context must be a uint8 vector.");
    }
    if (mxGetNumberOfElements(value) == 0) {
        return;
    }
    if (mxGetNumberOfElements(value) != 96) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidContext", "Context must contain 96 bytes.");
    }
    bytes = mxGetUint8s(value);
    if (memcmp(bytes, contextHeader, 8) != 0) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidContext", "Incompatible context version or method.");
    }
    for (wordIndex = 0; wordIndex < 4; ++wordIndex) {
        context->state[wordIndex] = load32(bytes + 8 + 4 * wordIndex);
    }
    context->length = (uint64_t)load32(bytes + 24) |
        ((uint64_t)load32(bytes + 28) << 32);
    memcpy(context->tail, bytes + 32, 64);
}

void mexFunction(int outputCount, mxArray *outputs[], int inputCount,
                 const mxArray *inputs[])
{
    Md5Context context = {{UINT32_C(1732584193), UINT32_C(4023233417),
        UINT32_C(2562383102), UINT32_C(271733878)}, 0, {0}};
    uint8_t *result;
    int finalize = 1;
    unsigned int wordIndex;
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
        mxGetUint8s(inputs[1])[0] != 5) {
        mexErrMsgIdAndTxt("DataHashCore:InvalidMethod", "Only uint8(5), MD5, is supported.");
    }
    if (inputCount == 4) {
        if (!isByteVector(inputs[3]) || mxGetNumberOfElements(inputs[3]) != 1 ||
            mxGetUint8s(inputs[3])[0] > 1) {
            mexErrMsgIdAndTxt("DataHashCore:InvalidOperation", "Finalize must be uint8(0) or uint8(1).");
        }
        finalize = mxGetUint8s(inputs[3])[0];
        readContext(&context, inputs[2]);
    }
    md5Update(&context, mxGetUint8s(inputs[0]),
        (size_t)mxGetNumberOfElements(inputs[0]));
    outputs[0] = mxCreateNumericMatrix(1, finalize ? 16 : 96, mxUINT8_CLASS, mxREAL);
    result = mxGetUint8s(outputs[0]);
    if (finalize) {
        md5Finalize(&context, result);
    } else {
        memcpy(result, contextHeader, 8);
        for (wordIndex = 0; wordIndex < 4; ++wordIndex) {
            store32(result + 8 + 4 * wordIndex, context.state[wordIndex]);
        }
        store32(result + 24, (uint32_t)context.length);
        store32(result + 28, (uint32_t)(context.length >> 32));
        memcpy(result + 32, context.tail, (size_t)(context.length & 63));
    }
}
