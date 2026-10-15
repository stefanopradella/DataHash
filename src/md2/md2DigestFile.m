function digest = md2DigestFile(fileName)
    %md2DigestFile - Return a native MD2 file digest using bounded memory
    %   DIGEST = md2DigestFile(FILENAME) uses the shared file reader with the
    %   native core and returns a uint8 row vector.
    %
    %   See also DataHash, digestFile

    [~, fileDigestFunction] = getHashFunctions("MD2", false);
    digest = fileDigestFunction(fileName);
end
