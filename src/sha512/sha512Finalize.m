function digest = sha512Finalize(state, tail, totalLength, digestLength)
%SHA512FINALIZE Add SHA-512-family padding and return the digest bytes.

    arguments
        state (8, 1) uint64
        tail (:, 1) uint8
        totalLength (1, 1) uint64
        digestLength (1, 1) double = 64
    end

    zeroCount = mod(111 - double(bitand(totalLength, uint64(127))), 128);
    highBitLength = bitshift(totalLength, -61);
    lowBitLength = bitshift(totalLength, 3);
    shifts = -8 * (7:-1:0);
    lengthBytes = [uint8(bitand(bitshift(highBitLength, shifts), ...
        uint64(255))).'; uint8(bitand(bitshift(lowBitLength, shifts), ...
        uint64(255))).'];
    finalBlocks = [tail; uint8(128); zeros(zeroCount, 1, 'uint8'); ...
        lengthBytes];
    state = sha512Compress(state, reshape(finalBlocks, 128, []));

    digestBytes = zeros(8, 8, 'uint8');
    for byteIndex = 1:8
        digestBytes(:, byteIndex) = uint8(bitand(bitshift(state, ...
            shifts(byteIndex)), uint64(255)));
    end
    digest = reshape(digestBytes.', 1, []);
    digest = digest(1:digestLength);
end
