function digest = sha512Digest(data)
%SHA512DIGEST Return the SHA-512 digest of a uint8 column vector.

    arguments
        data (:, 1) uint8
    end

    persistent initialState
    if isempty(initialState)
        initialHex = [ ...
            '6a09e667f3bcc908'; 'bb67ae8584caa73b'; ...
            '3c6ef372fe94f82b'; 'a54ff53a5f1d36f1'; ...
            '510e527fade682d1'; '9b05688c2b3e6c1f'; ...
            '1f83d9abfb41bd6b'; '5be0cd19137e2179'];
        initialState = bitor(bitshift(uint64(hex2dec( ...
            initialHex(:, 1:8))), 32), uint64(hex2dec(initialHex(:, 9:16))));
    end
    state = initialState;

    fullLength = numel(data) - rem(numel(data), 128);
    if fullLength > 0
        blocks = reshape(data(1:fullLength), 128, []);
        state = sha512Compress(state, blocks);
    end

    digest = sha512Finalize(state, data(fullLength + 1:end), ...
        uint64(numel(data)));
end
