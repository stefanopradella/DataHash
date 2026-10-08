function digest = md2Digest(data)
%MD2DIGEST Return the MD2 digest of a uint8 column vector.

    arguments
        data (:, 1) uint8
    end

    state = zeros(48, 1, 'uint8');
    checksum = zeros(16, 1, 'uint8');
    fullLength = numel(data) - rem(numel(data), 16);
    if fullLength > 0
        blocks = reshape(data(1:fullLength), 16, []);
        [state, checksum] = md2Compress(state, checksum, blocks);
    end

    digest = md2Finalize(state, checksum, data(fullLength + 1:end));
end
