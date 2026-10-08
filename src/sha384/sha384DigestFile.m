function digest = sha384DigestFile(fileName)
%SHA384DIGESTFILE Return the SHA-384 digest of a file using bounded memory.

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
            'cbbb9d5dc1059ed8'; '629a292a367cd507'; ...
            '9159015a3070dd17'; '152fecd8f70e5939'; ...
            '67332667ffc00b31'; '8eb44a8768581511'; ...
            'db0c2e0d64f98fa7'; '47b5481dbefa4fa4'];
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

    digest = sha512Finalize(state, tail, totalLength, 48);
end
