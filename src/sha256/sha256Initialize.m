function context = sha256Initialize()
    %sha256Initialize - Create a native SHA-256 streaming context
    %   CONTEXT = sha256Initialize() supplies the initial state, block length,
    %   and native compression/finalization handles.
    %
    %   See also sha256Digest, sha256DigestFile, nativeDigestCore

    % Copyright (c) 2026, Stefano Pradella. See ../../license.txt.

    state = uint32([1779033703; 3144134277; 1013904242; 2773480762; ...
        1359893119; 2600822924; 528734635; 1541459225]);
    context = struct('state', state, 'totalLength', uint64(0), ...
        'compress', @sha256Compress, 'finalize', @sha256Finalize, ...
        'blockLength', 64);
end
