function result = nativeDigestCore(bytes, context, finalize)
    %nativeDigestCore - Process a chunk using a native hashing context
    %   RESULT = nativeDigestCore(BYTES,CONTEXT,false) returns an updated
    %   context. Nonfinal chunks must contain complete algorithm blocks.
    %   nativeDigestCore(BYTES,CONTEXT,true) also pads the final tail and
    %   returns the digest as a uint8 row vector. CONTEXT supplies the
    %   algorithm's state, block length, and compression/finalization handles.
    %
    %   See also digestFile, getHashFunctions

    % Copyright (c) 2026, Stefano Pradella. See ../license.txt.

    % Nonfinal calls contain complete 1 MiB chunks, aligned for every method.
    byteCount = numel(bytes);
    context.totalLength = context.totalLength + uint64(byteCount);
    fullLength = byteCount - rem(byteCount, context.blockLength);
    if fullLength > 0
        context.state = context.compress(context.state, ...
            reshape(bytes(1:fullLength), context.blockLength, []));
    end
    if finalize
        result = context.finalize(context.state, bytes(fullLength + 1:end), ...
            context.totalLength);
    else
        result = context;
    end
end
