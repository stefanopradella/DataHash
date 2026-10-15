function digest = sha512DigestFile(fileName)
    %sha512DigestFile - Return a native SHA-512 file digest using bounded memory
    %   DIGEST = sha512DigestFile(FILENAME) uses the shared file reader with the
    %   native core and returns a uint8 row vector.
    %
    %   See also DataHash, digestFile

    [~, fileDigestFunction] = getHashFunctions("SHA-512", false);
    digest = fileDigestFunction(fileName);
end
