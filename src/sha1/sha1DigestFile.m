function digest = sha1DigestFile(fileName)
%SHA1DIGESTFILE Return the SHA-1 digest of a file using bounded memory.

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
    state = uint32([1732584193; 4023233417; 2562383102; ...
        271733878; 3285377520]);
    tail = zeros(0, 1, 'uint8');
    totalLength = uint64(0);

    while true
        [chunk, count] = fread(fileId, chunkLength, '*uint8');
        totalLength = totalLength + uint64(count);
        fullLength = count - rem(count, 64);
        if fullLength > 0
            state = sha1Compress(state, reshape(chunk(1:fullLength), 64, []));
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

    digest = sha1Finalize(state, tail, totalLength);
end
