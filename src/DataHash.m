function result = DataHash(data, method, inputType, outputFormat)
%DATAHASH Calculate a hash for MATLAB data or a file.
%   RESULT = DATAHASH(DATA, METHOD, INPUTTYPE, OUTPUTFORMAT) calculates the
%   requested digest. The optional arguments default to "MD5", "array",
%   and "hex", respectively.
%
%   DATAHASH() returns version information and the supported methods.

    arguments
        data = []
        method = "MD5"
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

    if isstruct(method)
        if nargin > 2
            error("DataHash:InvalidOptions", ...
                "An options structure cannot be combined with positional options.");
        end
        [method, inputType, outputFormat] = parseOptionsStruct(method);
    end

    [method, inputType, outputFormat] = parseFunctionInputs(data, method, inputType, outputFormat);

    switch method
        case "MD2"
            digestFunction = @md2Digest;
            fileDigestFunction = @md2DigestFile;
        case "MD5"
            digestFunction = @md5Digest;
            fileDigestFunction = @md5DigestFile;
        case "SHA-1"
            digestFunction = @sha1Digest;
            fileDigestFunction = @sha1DigestFile;
        case "SHA-256"
            digestFunction = @sha256Digest;
            fileDigestFunction = @sha256DigestFile;
        case "SHA-384"
            digestFunction = @sha384Digest;
            fileDigestFunction = @sha384DigestFile;
        case "SHA-512"
            digestFunction = @sha512Digest;
            fileDigestFunction = @sha512DigestFile;
    end

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

    method = string(method);
    if ~isscalar(method)
        error("DataHash:InvalidOption", "Method must be a scalar string.");
    end
    method = upper(method);
    mustBeOneOf(method, ...
        ["MD2", "MD5", "SHA-1", "SHA-256", "SHA-384", "SHA-512"]);
    inputType = lower(string(inputType));
    if ~isscalar(inputType)
        error("DataHash:InvalidOption", ...
            "Input type must be a scalar string.");
    end
    if inputType == "binary"
        inputType = "bin";
    elseif inputType == "asc"
        inputType = "ascii";
    end
    mustBeOneOf(inputType, ["array", "file", "bin", "ascii"]);

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

    outputFormat = string(outputFormat);
    if ~isscalar(outputFormat)
        error("DataHash:InvalidOption", ...
            "Output format must be a scalar string.");
    end
    mustBeOneOf(outputFormat, ...
        ["hex", "double", "uint8", "base64", "short"]);
    if lower(outputFormat) == "hex" && startsWith(outputFormat, "H")
        outputFormat = "HEX";
    else
        outputFormat = lower(outputFormat);
    end
end

function [method, inputType, outputFormat] = parseOptionsStruct(options)
% Parse the named options structure accepted by earlier DataHash versions.

    if ~isscalar(options)
        error("DataHash:InvalidOptions", ...
            "The options structure must be scalar.");
    end

    method = "MD5";
    inputType = "array";
    outputFormat = "hex";
    names = fieldnames(options);
    for fieldIndex = 1:numel(names)
        name = lower(string(names{fieldIndex}));
        value = options.(names{fieldIndex});
        if name == "method"
            method = value;
        elseif name == "input"
            inputType = value;
        elseif ismember(name, ["format", "outformat"])
            outputFormat = value;
        else
            error("DataHash:InvalidOptions", ...
                "Unknown option field '%s'.", names{fieldIndex});
        end
    end

    inputType = string(inputType);
    outputFormat = string(outputFormat);
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
