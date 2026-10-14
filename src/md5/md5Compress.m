function state = md5Compress(state, blocks)
%MD5COMPRESS Update an MD5 state with complete 64-byte blocks.

    arguments
        state (4, 1) uint32
        blocks (64, :) uint8
    end

    persistent isBigEndian
    if isempty(isBigEndian)
        [~, ~, endianness] = computer;
        isBigEndian = endianness == 'B';
    end

    % MD5 interprets each group of four bytes as a little-endian word.
    words = reshape(typecast(blocks(:), 'uint32'), 16, []);
    if isBigEndian
        words = swapbytes(words);
    end

    % Unroll all 64 steps to fix word indices, rotations, and constants.
    % Four uint32 operands sum to less than 2^34, exactly representable in
    % double. Subtract multiples of 2^32 before casting to avoid MATLAB's
    % saturating integer conversion. Round sums are nonnegative, so FIX
    % gives the integer quotient. Two-word sums need at most one wrap.
    % Constants are floor(2^32 * abs(sin(step))) for steps 1 through 64.
    a = state(1);
    b = state(2);
    c = state(3);
    d = state(4);
    for blockIndex = 1:size(words, 2)
        startA = a;
        startB = b;
        startC = c;
        startD = d;
        word1 = double(words(1, blockIndex));
        word2 = double(words(2, blockIndex));
        word3 = double(words(3, blockIndex));
        word4 = double(words(4, blockIndex));
        word5 = double(words(5, blockIndex));
        word6 = double(words(6, blockIndex));
        word7 = double(words(7, blockIndex));
        word8 = double(words(8, blockIndex));
        word9 = double(words(9, blockIndex));
        word10 = double(words(10, blockIndex));
        word11 = double(words(11, blockIndex));
        word12 = double(words(12, blockIndex));
        word13 = double(words(13, blockIndex));
        word14 = double(words(14, blockIndex));
        word15 = double(words(15, blockIndex));
        word16 = double(words(16, blockIndex));

        % Round 1.
        f = bitxor(d, bitand(b, bitxor(c, d)));
        sumRound = double(a) + double(f) + 3614090360 + word1;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 7), bitshift(value, -25));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(c, bitand(a, bitxor(b, c)));
        sumRound = double(d) + double(f) + 3905402710 + word2;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 12), bitshift(value, -20));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(b, bitand(d, bitxor(a, b)));
        sumRound = double(c) + double(f) + 606105819 + word3;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 17), bitshift(value, -15));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(a, bitand(c, bitxor(d, a)));
        sumRound = double(b) + double(f) + 3250441966 + word4;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 22), bitshift(value, -10));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(d, bitand(b, bitxor(c, d)));
        sumRound = double(a) + double(f) + 4118548399 + word5;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 7), bitshift(value, -25));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(c, bitand(a, bitxor(b, c)));
        sumRound = double(d) + double(f) + 1200080426 + word6;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 12), bitshift(value, -20));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(b, bitand(d, bitxor(a, b)));
        sumRound = double(c) + double(f) + 2821735955 + word7;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 17), bitshift(value, -15));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(a, bitand(c, bitxor(d, a)));
        sumRound = double(b) + double(f) + 4249261313 + word8;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 22), bitshift(value, -10));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(d, bitand(b, bitxor(c, d)));
        sumRound = double(a) + double(f) + 1770035416 + word9;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 7), bitshift(value, -25));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(c, bitand(a, bitxor(b, c)));
        sumRound = double(d) + double(f) + 2336552879 + word10;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 12), bitshift(value, -20));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(b, bitand(d, bitxor(a, b)));
        sumRound = double(c) + double(f) + 4294925233 + word11;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 17), bitshift(value, -15));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(a, bitand(c, bitxor(d, a)));
        sumRound = double(b) + double(f) + 2304563134 + word12;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 22), bitshift(value, -10));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(d, bitand(b, bitxor(c, d)));
        sumRound = double(a) + double(f) + 1804603682 + word13;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 7), bitshift(value, -25));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(c, bitand(a, bitxor(b, c)));
        sumRound = double(d) + double(f) + 4254626195 + word14;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 12), bitshift(value, -20));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(b, bitand(d, bitxor(a, b)));
        sumRound = double(c) + double(f) + 2792965006 + word15;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 17), bitshift(value, -15));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(a, bitand(c, bitxor(d, a)));
        sumRound = double(b) + double(f) + 1236535329 + word16;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 22), bitshift(value, -10));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        % Round 2.
        f = bitxor(c, bitand(d, bitxor(b, c)));
        sumRound = double(a) + double(f) + 4129170786 + word2;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 5), bitshift(value, -27));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(b, bitand(c, bitxor(a, b)));
        sumRound = double(d) + double(f) + 3225465664 + word7;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 9), bitshift(value, -23));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(a, bitand(b, bitxor(d, a)));
        sumRound = double(c) + double(f) + 643717713 + word12;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 14), bitshift(value, -18));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(d, bitand(a, bitxor(c, d)));
        sumRound = double(b) + double(f) + 3921069994 + word1;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 20), bitshift(value, -12));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(c, bitand(d, bitxor(b, c)));
        sumRound = double(a) + double(f) + 3593408605 + word6;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 5), bitshift(value, -27));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(b, bitand(c, bitxor(a, b)));
        sumRound = double(d) + double(f) + 38016083 + word11;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 9), bitshift(value, -23));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(a, bitand(b, bitxor(d, a)));
        sumRound = double(c) + double(f) + 3634488961 + word16;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 14), bitshift(value, -18));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(d, bitand(a, bitxor(c, d)));
        sumRound = double(b) + double(f) + 3889429448 + word5;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 20), bitshift(value, -12));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(c, bitand(d, bitxor(b, c)));
        sumRound = double(a) + double(f) + 568446438 + word10;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 5), bitshift(value, -27));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(b, bitand(c, bitxor(a, b)));
        sumRound = double(d) + double(f) + 3275163606 + word15;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 9), bitshift(value, -23));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(a, bitand(b, bitxor(d, a)));
        sumRound = double(c) + double(f) + 4107603335 + word4;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 14), bitshift(value, -18));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(d, bitand(a, bitxor(c, d)));
        sumRound = double(b) + double(f) + 1163531501 + word9;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 20), bitshift(value, -12));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(c, bitand(d, bitxor(b, c)));
        sumRound = double(a) + double(f) + 2850285829 + word14;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 5), bitshift(value, -27));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(b, bitand(c, bitxor(a, b)));
        sumRound = double(d) + double(f) + 4243563512 + word3;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 9), bitshift(value, -23));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(a, bitand(b, bitxor(d, a)));
        sumRound = double(c) + double(f) + 1735328473 + word8;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 14), bitshift(value, -18));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(d, bitand(a, bitxor(c, d)));
        sumRound = double(b) + double(f) + 2368359562 + word13;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 20), bitshift(value, -12));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        % Round 3.
        f = bitxor(b, bitxor(c, d));
        sumRound = double(a) + double(f) + 4294588738 + word6;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 4), bitshift(value, -28));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(a, bitxor(b, c));
        sumRound = double(d) + double(f) + 2272392833 + word9;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 11), bitshift(value, -21));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(d, bitxor(a, b));
        sumRound = double(c) + double(f) + 1839030562 + word12;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 16), bitshift(value, -16));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(c, bitxor(d, a));
        sumRound = double(b) + double(f) + 4259657740 + word15;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 23), bitshift(value, -9));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(b, bitxor(c, d));
        sumRound = double(a) + double(f) + 2763975236 + word2;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 4), bitshift(value, -28));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(a, bitxor(b, c));
        sumRound = double(d) + double(f) + 1272893353 + word5;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 11), bitshift(value, -21));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(d, bitxor(a, b));
        sumRound = double(c) + double(f) + 4139469664 + word8;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 16), bitshift(value, -16));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(c, bitxor(d, a));
        sumRound = double(b) + double(f) + 3200236656 + word11;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 23), bitshift(value, -9));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(b, bitxor(c, d));
        sumRound = double(a) + double(f) + 681279174 + word14;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 4), bitshift(value, -28));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(a, bitxor(b, c));
        sumRound = double(d) + double(f) + 3936430074 + word1;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 11), bitshift(value, -21));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(d, bitxor(a, b));
        sumRound = double(c) + double(f) + 3572445317 + word4;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 16), bitshift(value, -16));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(c, bitxor(d, a));
        sumRound = double(b) + double(f) + 76029189 + word7;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 23), bitshift(value, -9));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(b, bitxor(c, d));
        sumRound = double(a) + double(f) + 3654602809 + word10;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 4), bitshift(value, -28));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(a, bitxor(b, c));
        sumRound = double(d) + double(f) + 3873151461 + word13;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 11), bitshift(value, -21));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(d, bitxor(a, b));
        sumRound = double(c) + double(f) + 530742520 + word16;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 16), bitshift(value, -16));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(c, bitxor(d, a));
        sumRound = double(b) + double(f) + 3299628645 + word3;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 23), bitshift(value, -9));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        % Round 4.
        f = bitxor(c, bitor(b, bitcmp(d)));
        sumRound = double(a) + double(f) + 4096336452 + word1;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 6), bitshift(value, -26));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(b, bitor(a, bitcmp(c)));
        sumRound = double(d) + double(f) + 1126891415 + word8;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 10), bitshift(value, -22));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(a, bitor(d, bitcmp(b)));
        sumRound = double(c) + double(f) + 2878612391 + word15;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 15), bitshift(value, -17));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(d, bitor(c, bitcmp(a)));
        sumRound = double(b) + double(f) + 4237533241 + word6;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 21), bitshift(value, -11));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(c, bitor(b, bitcmp(d)));
        sumRound = double(a) + double(f) + 1700485571 + word13;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 6), bitshift(value, -26));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(b, bitor(a, bitcmp(c)));
        sumRound = double(d) + double(f) + 2399980690 + word4;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 10), bitshift(value, -22));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(a, bitor(d, bitcmp(b)));
        sumRound = double(c) + double(f) + 4293915773 + word11;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 15), bitshift(value, -17));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(d, bitor(c, bitcmp(a)));
        sumRound = double(b) + double(f) + 2240044497 + word2;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 21), bitshift(value, -11));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(c, bitor(b, bitcmp(d)));
        sumRound = double(a) + double(f) + 1873313359 + word9;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 6), bitshift(value, -26));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(b, bitor(a, bitcmp(c)));
        sumRound = double(d) + double(f) + 4264355552 + word16;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 10), bitshift(value, -22));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(a, bitor(d, bitcmp(b)));
        sumRound = double(c) + double(f) + 2734768916 + word7;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 15), bitshift(value, -17));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(d, bitor(c, bitcmp(a)));
        sumRound = double(b) + double(f) + 1309151649 + word14;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 21), bitshift(value, -11));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        f = bitxor(c, bitor(b, bitcmp(d)));
        sumRound = double(a) + double(f) + 4149444226 + word5;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 6), bitshift(value, -26));
        sumValue = double(b) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        a = uint32(sumValue);

        f = bitxor(b, bitor(a, bitcmp(c)));
        sumRound = double(d) + double(f) + 3174756917 + word12;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 10), bitshift(value, -22));
        sumValue = double(a) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        d = uint32(sumValue);

        f = bitxor(a, bitor(d, bitcmp(b)));
        sumRound = double(c) + double(f) + 718787259 + word3;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 15), bitshift(value, -17));
        sumValue = double(d) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        c = uint32(sumValue);

        f = bitxor(d, bitor(c, bitcmp(a)));
        sumRound = double(b) + double(f) + 3951481745 + word10;
        value = uint32(sumRound - 4294967296 * fix(sumRound * 2^-32));
        rotated = bitor(bitshift(value, 21), bitshift(value, -11));
        sumValue = double(c) + double(rotated);
        sumValue = sumValue - 4294967296 * (sumValue >= 4294967296);
        b = uint32(sumValue);

        sumValue = double(a) + double(startA);
        a = uint32(sumValue - 4294967296 * (sumValue >= 4294967296));
        sumValue = double(b) + double(startB);
        b = uint32(sumValue - 4294967296 * (sumValue >= 4294967296));
        sumValue = double(c) + double(startC);
        c = uint32(sumValue - 4294967296 * (sumValue >= 4294967296));
        sumValue = double(d) + double(startD);
        d = uint32(sumValue - 4294967296 * (sumValue >= 4294967296));
    end
    state = [a; b; c; d];
end
