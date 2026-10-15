function digest = sha256DigestFile(fileName)
    %sha256DigestFile - Return a native SHA-256 file digest using bounded memory
    %   DIGEST = sha256DigestFile(FILENAME) uses the shared file reader with the
    %   native core and returns a uint8 row vector.
    %
    %   See also DataHash, digestFile

    [~, fileDigestFunction] = getHashFunctions("SHA-256", false);
    digest = fileDigestFunction(fileName);
end
