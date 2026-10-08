function digest = md2DigestFile(fileName)
%MD2DIGESTFILE Return the MD2 digest of a file using bounded memory.

    arguments
        fileName (1, 1) string
    end

    [fileId, message] = fopen(char(fileName), 'rb');
    if fileId < 0
        error("DataHash:FileOpen", "Cannot open file '%s': %s", ...
            fileName, message);
    end
    fileGuard = onCleanup(@() fclose(fileId));

    chunkLength = 2^20;
    state = zeros(48, 1, 'uint8');
    checksum = zeros(16, 1, 'uint8');
    tail = zeros(0, 1, 'uint8');

    while true
        [chunk, count] = fread(fileId, chunkLength, '*uint8');
        fullLength = count - rem(count, 16);
        if fullLength > 0
            [state, checksum] = md2Compress(state, checksum, ...
                reshape(chunk(1:fullLength), 16, []));
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

    digest = md2Finalize(state, checksum, tail);
end
