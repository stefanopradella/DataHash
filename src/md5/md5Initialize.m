function context = md5Initialize()
    %md5Initialize - Create a native MD5 streaming context
    %   CONTEXT = md5Initialize() supplies the initial state, block length,
    %   and native compression/finalization handles.
    %
    %   See also md5Digest, md5DigestFile, nativeDigestCore

    % Copyright (c) 2026, Stefano Pradella. See ../../license.txt.

    state = uint32([1732584193; 4023233417; 2562383102; 271733878]);
    context = struct('state', state, 'totalLength', uint64(0), ...
        'compress', @md5Compress, 'finalize', @md5Finalize, 'blockLength', 64);
end
