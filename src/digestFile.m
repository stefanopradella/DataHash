function digest = digestFile(fileName, coreFunction, context)
    %digestFile - Hash a file with a supplied incremental hashing core
    %   DIGEST = digestFile(FILENAME,COREFUNCTION,CONTEXT) reads at most
    %   1 MiB at a time. COREFUNCTION(BYTES,CONTEXT,false) returns an updated
    %   context; COREFUNCTION(BYTES,CONTEXT,true) returns digest bytes.
    %   Nonfinal calls receive complete 1 MiB chunks. The final call receives
    %   fewer bytes, including an empty vector for an exact chunk multiple.
    %
    %   See also DataHash, getHashFunctions

    % Copyright (c) 2026, Stefano Pradella. See ../license.txt.

    arguments
        fileName (1, 1) string
        coreFunction (1, 1) function_handle
        context
    end

    [fileId, message] = fopen(char(fileName), 'rb');
    if fileId < 0
        error("DataHash:FileOpen", "Cannot open file '%s': %s", ...
            fileName, message);
    end
    fileGuard = onCleanup(@() fclose(fileId));

    chunkLength = 2^20;
    while true
        [chunk, count] = fread(fileId, chunkLength, '*uint8');
        if count < chunkLength
            break;
        end
        context = coreFunction(chunk, context, false);
    end

    [message, errorNumber] = ferror(fileId);
    if errorNumber > 0
        error("DataHash:FileRead", "Cannot read file '%s': %s", ...
            fileName, message);
    end
    digest = coreFunction(chunk, context, true);
end
