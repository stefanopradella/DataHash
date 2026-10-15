function digest = sha384DigestFile(fileName)
    %sha384DigestFile - Return a native SHA-384 file digest using bounded memory
    %   DIGEST = sha384DigestFile(FILENAME) uses the shared file reader with the
    %   native core and returns a uint8 row vector.
    %
    %   See also DataHash, digestFile

    [~, fileDigestFunction] = getHashFunctions("SHA-384", false);
    digest = fileDigestFunction(fileName);
end
