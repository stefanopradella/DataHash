function digest = md5Digest(data)
%MD5DIGEST Return the MD5 digest of a uint8 column vector.

    arguments
        data (:, 1) uint8
    end

    state = uint32([1732584193; 4023233417; 2562383102; 271733878]);
    fullLength = numel(data) - rem(numel(data), 64);
    if fullLength > 0
        blocks = reshape(data(1:fullLength), 64, []);
        state = md5Compress(state, blocks);
    end

    digest = md5Finalize(state, data(fullLength + 1:end), ...
        uint64(numel(data)));
end
