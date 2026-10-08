function digest = sha512DigestFile(fileName)
%SHA512DIGESTFILE Return the SHA-512 digest of a file using bounded memory.

    arguments
        fileName (1, 1) string
    end

    [fileId, message] = fopen(char(fileName), 'rb');
    if fileId < 0
        error("DataHash:FileOpen", "Cannot open file '%s': %s", ...
            fileName, message);
    end
    fileGuard = onCleanup(@() fclose(fileId));

    persistent initialState
    if isempty(initialState)
        initialHex = [ ...
            '6a09e667f3bcc908'; 'bb67ae8584caa73b'; ...
            '3c6ef372fe94f82b'; 'a54ff53a5f1d36f1'; ...
            '510e527fade682d1'; '9b05688c2b3e6c1f'; ...
            '1f83d9abfb41bd6b'; '5be0cd19137e2179'];
        initialState = bitor(bitshift(uint64(hex2dec( ...
            initialHex(:, 1:8))), 32), uint64(hex2dec(initialHex(:, 9:16))));
    end

    chunkLength = 2^20;
    state = initialState;
    tail = zeros(0, 1, 'uint8');
    totalLength = uint64(0);

    while true
        [chunk, count] = fread(fileId, chunkLength, '*uint8');
        totalLength = totalLength + uint64(count);
        fullLength = count - rem(count, 128);
        if fullLength > 0
            state = sha512Compress(state, ...
                reshape(chunk(1:fullLength), 128, []));
        end
        tail = chunk(fullLength + 1:end);
        if count < chunkLength
            break;
        end
    end

    [message, errorNumber] = ferror(fileId);
    if errorNumber > 0
        error("DataHash:FileRead", "Cannot read file '%s': %s", ...
            fileName, message);
    end

    digest = sha512Finalize(state, tail, totalLength);
end
