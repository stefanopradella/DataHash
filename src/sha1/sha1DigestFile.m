function digest = sha1DigestFile(fileName)
    %sha1DigestFile - Return a native SHA-1 file digest using bounded memory
    %   DIGEST = sha1DigestFile(FILENAME) uses the shared file reader with the
    %   native core and returns a uint8 row vector.
    %
    %   See also DataHash, digestFile

    [~, fileDigestFunction] = getHashFunctions("SHA-1", false);
    digest = fileDigestFunction(fileName);
end
