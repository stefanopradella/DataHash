function allPassed = verifySha256Sums(fileName, fileDigestFunction)
%verifySha256Sums Verify ordinary untagged SHA-256 checksum lines.
%   Print each file's status and return a logical scalar. Relative paths use
%   the current folder. Blank lines and # comments are ignored; malformed
%   lines and manifests without entries are errors.

    % Copyright (c) 2026, Stefano Pradella. See ../license.txt.

    arguments
        fileName (1, 1) string
        fileDigestFunction (1, 1) function_handle
    end

    lines = regexp(fileread(fileName), '\r\n|\n|\r', 'split');
    allPassed = true;
    hasEntries = false;
    baseFolder = pwd;
    for lineIndex = 1:numel(lines)
        line = lines{lineIndex};
        if isempty(line) || startsWith(line, '#')
            continue;
        end
        entry = regexp(line, '^([0-9a-fA-F]{64}) [ *](.+)$', 'tokens', 'once');
        if isempty(entry)
            error('DataHash:InvalidChecksumFile', ...
                'Invalid SHA-256 checksum line %d in "%s".', lineIndex, fileName);
        end
        hasEntries = true;
        targetFile = entry{2};
        if ~startsWith(targetFile, filesep) && ...
                ~(ispc && ~isempty(regexp(targetFile, '^(?:[A-Za-z]:|/)', 'once')))
            targetFile = fullfile(baseFolder, targetFile);
        end
        status = 'FAILED';
        try
            digest = fileDigestFunction(targetFile);
            matches = strcmpi(sprintf('%.2x', double(digest)), entry{1});
            if matches
                status = 'OK';
            end
        catch exception
            if ~ismember(exception.identifier, {'DataHash:FileOpen', 'DataHash:FileRead'})
                rethrow(exception);
            end
            matches = false;
            status = 'FAILED open or read';
            fprintf(2, '%s\n', exception.message);
        end
        fprintf('%s: %s\n', entry{2}, status);
        allPassed = allPassed && matches;
    end
    if ~hasEntries
        error('DataHash:InvalidChecksumFile', ...
            'No SHA-256 checksum entries in "%s".', fileName);
    end
end
