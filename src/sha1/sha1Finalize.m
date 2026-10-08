function digest = sha1Finalize(state, tail, totalLength)
%SHA1FINALIZE Add SHA-1 padding and return the digest bytes.

    arguments
        state (5, 1) uint32
        tail (:, 1) uint8
        totalLength (1, 1) uint64
    end

    zeroCount = mod(55 - double(bitand(totalLength, uint64(63))), 64);
    bitLength = bitshift(totalLength, 3);
    lengthBytes = uint8(bitand(bitshift(bitLength, ...
        -8 * (7:-1:0)), uint64(255))).';
    finalBlocks = [tail; uint8(128); zeros(zeroCount, 1, 'uint8'); ...
        lengthBytes];
    state = sha1Compress(state, reshape(finalBlocks, 64, []));

    digestBytes = uint8([bitshift(state, -24), ...
        bitand(bitshift(state, -16), uint32(255)), ...
        bitand(bitshift(state, -8), uint32(255)), ...
        bitand(state, uint32(255))]);
    digest = reshape(digestBytes.', 1, []);
end
