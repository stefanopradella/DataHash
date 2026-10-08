function digest = sha256Digest(data)
%SHA256DIGEST Return the SHA-256 digest of a uint8 column vector.

    arguments
        data (:, 1) uint8
    end

    state = uint32([1779033703; 3144134277; 1013904242; 2773480762; ...
        1359893119; 2600822924; 528734635; 1541459225]);
    fullLength = numel(data) - rem(numel(data), 64);
    if fullLength > 0
        blocks = reshape(data(1:fullLength), 64, []);
        state = sha256Compress(state, blocks);
    end

    digest = sha256Finalize(state, data(fullLength + 1:end), ...
        uint64(numel(data)));
end
