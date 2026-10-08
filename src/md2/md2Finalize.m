function digest = md2Finalize(state, checksum, tail)
%MD2FINALIZE Add MD2 padding and the checksum, then return the digest.

    arguments
        state (48, 1) uint8
        checksum (16, 1) uint8
        tail (:, 1) uint8
    end

    paddingLength = 16 - numel(tail);
    finalBlock = [tail; repmat(uint8(paddingLength), paddingLength, 1)];
    [state, checksum] = md2Compress(state, checksum, finalBlock);
    [state, ~] = md2Compress(state, checksum, checksum);
    digest = state(1:16).';
end
