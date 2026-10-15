function context = md2Initialize()
    %md2Initialize - Create a native MD2 streaming context
    %   CONTEXT = md2Initialize() supplies initial state/checksum bytes,
    %   the block length, and the native compression/finalization handles.
    %
    %   See also md2Digest, md2DigestFile, nativeDigestCore

    % Copyright (c) 2026, Stefano Pradella. See ../../license.txt.

    context = struct('state', zeros(64, 1, 'uint8'), ...
        'totalLength', uint64(0), 'compress', @compressMd2State, ...
        'finalize', @finalizeMd2State, 'blockLength', 16);
end

function state = compressMd2State(state, blocks)
    % Pack MD2's 48 state bytes and 16 checksum bytes into one native state.
    [hashState, checksum] = md2Compress(state(1:48), state(49:64), blocks);
    state = [hashState; checksum];
end

function digest = finalizeMd2State(state, tail, ~)
    digest = md2Finalize(state(1:48), state(49:64), tail);
end
