function [digestFunction, fileDigestFunction] = getHashFunctions(method, useAccelerator)
    %getHashFunctions - Select memory and file hashing functions
    %   [DIGESTFUNCTION,FILEDIGESTFUNCTION] = getHashFunctions(METHOD) binds
    %   the requested algorithm to a compatible MEX or native backend.
    %   Both backends use the same file reader with an incremental core.
    %   File contexts are initialized only when FILEDIGESTFUNCTION is called.
    %
    %   getHashFunctions(METHOD,false) selects native functions explicitly
    %   for the native file entry points and performance comparisons.
    %
    %   See also DataHash, digestFile, hasDataHashCore

    % Copyright (c) 2026, Stefano Pradella. See ../license.txt.

    arguments
        method (1, 1) string
        useAccelerator (1, 1) logical = true
    end

    % Stable byte selectors: SHA-1=1, MD2=2, SHA-256=3, SHA-384=4,
    % MD5=5, SHA-512=6. MD5 retains the original MEX selector.
    switch method
        case "MD2"
            methodId = uint8(2);
            digestFunction = @md2Digest;
            initializeFunction = @md2Initialize;
        case "MD5"
            methodId = uint8(5);
            digestFunction = @md5Digest;
            initializeFunction = @md5Initialize;
        case "SHA-1"
            methodId = uint8(1);
            digestFunction = @sha1Digest;
            initializeFunction = @sha1Initialize;
        case "SHA-256"
            methodId = uint8(3);
            digestFunction = @sha256Digest;
            initializeFunction = @sha256Initialize;
        case "SHA-384"
            methodId = uint8(4);
            digestFunction = @sha384Digest;
            initializeFunction = @sha384Initialize;
        case "SHA-512"
            methodId = uint8(6);
            digestFunction = @sha512Digest;
            initializeFunction = @sha512Initialize;
        otherwise
            error('DataHash:InvalidOption', 'Unsupported hashing method: %s.', method);
    end

    if useAccelerator && hasDataHashCore(methodId, digestFunction)
        digestFunction = @(bytes) DataHashCore(bytes, methodId);
        coreFunction = @(bytes, context, finalize) ...
            DataHashCore(bytes, methodId, context, uint8(finalize));
        initializeFunction = @() zeros(0, 1, 'uint8');
    else
        coreFunction = @nativeDigestCore;
    end
    fileDigestFunction = @(fileName) ...
        digestFile(fileName, coreFunction, initializeFunction());
end
