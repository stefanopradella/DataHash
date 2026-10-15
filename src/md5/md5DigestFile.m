function digest = md5DigestFile(fileName)
    %md5DigestFile - Return a native MD5 file digest using bounded memory
    %   DIGEST = md5DigestFile(FILENAME) uses the shared file reader with the
    %   native core and returns a uint8 row vector.
    %
    %   See also DataHash, digestFile

    [~, fileDigestFunction] = getHashFunctions("MD5", false);
    digest = fileDigestFunction(fileName);
end
