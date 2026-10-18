function digest = digestNumericArray(value, methodId)
    %digestNumericArray - Hash numeric array metadata and payload with MEX
    %   DIGEST = digestNumericArray(VALUE,methodId) returns a uint8 row digest
    %   of the DataHash version 5 serialization of a real, full built-in
    %   numeric array. methodId selects an already verified MEX algorithm.
    %   Metadata and column-major payload bytes enter one incremental hash
    %   without allocating their concatenation. VALUE keeps its class and
    %   shape; the caller excludes objects, sparse and complex arrays.
    %
    %   See also DataHash, serializeObject, DataHashCore

    % Copyright (c) 2026, Stefano Pradella. See ../license.txt.

    arguments
        value {mustBeNumeric, mustBeReal}
        methodId (1, 1) uint8
    end

    header = [uint8(class(value)).'; ...
        typecast(uint64([ndims(value), size(value)]), 'uint8').'];
    context = DataHashCore(header, methodId, zeros(0, 1, 'uint8'), uint8(0));
    digest = DataHashCore(typecast(value(:), 'uint8'), methodId, context, uint8(1));
end
