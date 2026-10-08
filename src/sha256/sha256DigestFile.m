function digest = sha256DigestFile(fileName)
%SHA256DIGESTFILE Return the SHA-256 digest of a file using bounded memory.

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
    state = uint32([1779033703; 3144134277; 1013904242; 2773480762; ...
        1359893119; 2600822924; 528734635; 1541459225]);
    tail = zeros(0, 1, 'uint8');
    totalLength = uint64(0);

    while true
        [chunk, count] = fread(fileId, chunkLength, '*uint8');
        totalLength = totalLength + uint64(count);
        fullLength = count - rem(count, 64);
        if fullLength > 0
            state = sha256Compress(state, ...
                reshape(chunk(1:fullLength), 64, []));
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

    digest = sha256Finalize(state, tail, totalLength);
end
