function available = hasDataHashCore(methodId, nativeDigestFunction)
    %hasDataHashCore - Check MEX compatibility for a hashing method
    %   AVAILABLE = hasDataHashCore(METHODID,NATIVEDIGESTFUNCTION) checks
    %   memory and streaming support against the native empty-input digest.
    %   METHODID is the uint8 selector assigned by getHashFunctions.
    %   A missing, unloadable, or incompatible binary returns false without
    %   a warning. Results are cached per method until the binary changes.
    %   Hashing errors after a successful check propagate normally.
    %
    %   AVAILABLE = hasDataHashCore() checks MD5 support.
    %
    %   See also DataHash, EXIST

    % Copyright (c) 2026, Stefano Pradella. See ../license.txt.

    arguments
        methodId (1, 1) uint8 {mustBeGreaterThanOrEqual(methodId, 1), ...
            mustBeLessThanOrEqual(methodId, 6)} = uint8(5)
        nativeDigestFunction (1, 1) function_handle = @md5Digest
    end

    persistent checkedHandle checkedFile checkedStamp checkedMethods checkedAvailable
    available = false;
    coreHandle = @DataHashCore;
    if isempty(checkedFile) || ~isequal(coreHandle, checkedHandle)
        if exist('DataHashCore', 'file') ~= 3
            return;
        end
        coreFile = which('DataHashCore');
    else
        coreFile = checkedFile;
    end
    if isempty(coreFile)
        return;
    end
    coreInfo = dir(coreFile);
    if isempty(coreInfo)
        checkedHandle = [];
        checkedFile = [];
        return;
    end
    stamp = [coreInfo.datenum, coreInfo.bytes];
    if ~isequal(coreFile, checkedFile) || ~isequal(stamp, checkedStamp)
        checkedHandle = coreHandle;
        checkedFile = coreFile;
        checkedStamp = stamp;
        checkedMethods = false(1, 6);
        checkedAvailable = false(1, 6);
    end
    if ~checkedMethods(methodId)
        checkedMethods(methodId) = true;
        try
            bytes = zeros(0, 1, 'uint8');
            expected = nativeDigestFunction(bytes);
            digest = DataHashCore(bytes, methodId);
            context = DataHashCore(bytes, methodId, ...
                zeros(0, 1, 'uint8'), uint8(0));
            finalDigest = DataHashCore(bytes, methodId, ...
                context, uint8(1));
            checkedAvailable(methodId) = isequal(digest, expected) && ...
                isequal(finalDigest, expected);
        catch
            % Availability probes may fail for a different platform or API.
        end
    end
    available = checkedAvailable(methodId);
end
