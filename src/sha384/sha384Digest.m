function digest = sha384Digest(data)
%SHA384DIGEST Return the SHA-384 digest of a uint8 column vector.

    arguments
        data (:, 1) uint8
    end

    persistent initialState
    if isempty(initialState)
        initialHex = [ ...
            'cbbb9d5dc1059ed8'; '629a292a367cd507'; ...
            '9159015a3070dd17'; '152fecd8f70e5939'; ...
            '67332667ffc00b31'; '8eb44a8768581511'; ...
            'db0c2e0d64f98fa7'; '47b5481dbefa4fa4'];
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
        uint64(numel(data)), 48);
end
