function result = DataHash(data, method, inputType, outputFormat)
%DATAHASH Calculate a hash for MATLAB data or a file.
%   RESULT = DATAHASH(DATA, METHOD, INPUTTYPE, OUTPUTFORMAT) calculates the
%   requested digest. The optional arguments default to "MD5", "array",
%   and "hex", respectively.
%   Options are positional; only trailing arguments can be omitted.
%
%   DATAHASH() returns version information and the supported methods.

    arguments
        data = []
        method (1, 1) string {mustBeOneOf(method, ...
            ["MD2", "MD5", "SHA-1", "SHA-256", "SHA-384", "SHA-512"])} = "MD5"
        inputType (1, 1) string {mustBeOneOf(inputType, ...
            ["array", "file", "bin", "binary", "asc", "ascii"])} = "array"
        outputFormat (1, 1) string {mustBeOneOf(outputFormat, ...
            ["hex", "double", "uint8", "base64", "short"])} = "hex"
    end

    if nargin == 0
        % If called without arguments, DataHash returns a structure
        % containing informations about the version.
        % The output differs between versions of this function.
        result = struct('HashVersion', 5, ...
                        'Date', [2026, 9, 16], ...
                        'HashMethod', {{'MD2', 'MD5', 'SHA-1', 'SHA-256', 'SHA-384', 'SHA-512'}});
        return;
    end

    [method, inputType, outputFormat] = parseFunctionInputs(data, method, inputType, outputFormat);

    [digestFunction, fileDigestFunction] = getHashFunctions(method);

    if inputType == "file"
        digest = fileDigestFunction(data);
    else
        if inputType == "array"
            bytes = serializeObject(data);
        elseif inputType == "bin"
            bytes = serializeBinary(data);
        else
            bytes = uint8(char(data));
            bytes = bytes(:);
        end
        digest = digestFunction(bytes);
    end

    % Encode output
    switch outputFormat
        case "hex"
            result = sprintf('%.2x', double(digest));
        case "HEX"
            result = sprintf('%.2X', double(digest));
        case "double"
            result = double(digest);
        case "uint8"
            result = digest;
        case "base64"
            result = matlab.net.base64encode(digest);
        case "short"
            result = matlab.net.base64encode(digest);
            result(result == '=') = [];
    end
end

function [method, inputType, outputFormat] = parseFunctionInputs( ...
        data, method, inputType, outputFormat)
% Handle abbrevations, uppercase/lowercase conversions and input-dependant
% data format limitations

    method = upper(method);
    inputType = lower(inputType);
    if inputType == "binary"
        inputType = "bin";
    elseif inputType == "asc"
        inputType = "ascii";
    end
    if inputType == "bin"
        if ~(isnumeric(data) || ischar(data) || islogical(data) || ...
                (isstring(data) && isscalar(data))) || issparse(data)
            error("DataHash:InvalidBinaryData", ...
                "Binary input requires nonsparse numeric, char, logical, or scalar string data.");
        end
    elseif inputType == "ascii"
        if ~(ischar(data) || (isstring(data) && isscalar(data)))
            error("DataHash:InvalidAsciiData", ...
                "ASCII input requires a char array or scalar string.");
        end
    end

    if lower(outputFormat) == "hex" && startsWith(outputFormat, "H")
        outputFormat = "HEX";
    else
        outputFormat = lower(outputFormat);
    end
end

function bytes = serializeBinary(value)
% Serialize only the binary contents of an elementary array.

    if isempty(value)
        bytes = zeros(0, 1, 'uint8');
    elseif isa(value, 'embedded.fi')
        bytes = serializeFixedPointBinary(value);
    elseif isnumeric(value)
        if isreal(value)
            bytes = typecast(value(:), 'uint8');
        else
            bytes = [typecast(real(value(:)), 'uint8'); ...
                typecast(imag(value(:)), 'uint8')];
        end
        bytes = bytes(:);
    elseif islogical(value)
        bytes = uint8(value(:));
    elseif ischar(value)
        bytes = typecast(uint16(value(:)), 'uint8');
        bytes = bytes(:);
    else
        bytes = typecast(uint16(value{1}), 'uint8');
        bytes = bytes(:);
    end
end

function bytes = serializeFixedPointBinary(value)
    if isreal(value)
        bytes = serializeFixedPointBinaryValue(value);
    else
        bytes = [serializeFixedPointBinaryValue(real(value)); ...
            serializeFixedPointBinaryValue(imag(value))];
    end
end

function bytes = serializeFixedPointBinaryValue(value)
    if value.WordLength <= 64
        payload = storedInteger(value);
        bytes = typecast(payload(:), 'uint8');
        bytes = bytes(:);
    else
        payload = hex(value(:)).';
        bytes = uint8(payload(:));
    end
end

function mustBeOneOf(value, validValues)
    if ~ismember(lower(value), lower(validValues))
        error("DataHash:InvalidOption", ...
            "Value must be one of: %s.", join(validValues, ", "));
    end
end
