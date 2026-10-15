function context = sha1Initialize()
    %sha1Initialize - Create a native SHA-1 streaming context
    %   CONTEXT = sha1Initialize() supplies the initial state, block length,
    %   and native compression/finalization handles.
    %
    %   See also sha1Digest, sha1DigestFile, nativeDigestCore

    % Copyright (c) 2026, Stefano Pradella. See ../../license.txt.

    state = uint32([1732584193; 4023233417; 2562383102; ...
        271733878; 3285377520]);
    context = struct('state', state, 'totalLength', uint64(0), ...
        'compress', @sha1Compress, 'finalize', @sha1Finalize, 'blockLength', 64);
end
