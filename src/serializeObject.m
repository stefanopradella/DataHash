function data = serializeObject(value)
%SERIALIZEOBJECT Serialize MATLAB data in the DataHash version 5 format.
%   DATA is a uint8 column vector containing class and dimension metadata
%   followed by the serialized value. Supported inputs include numeric,
%   logical, char, string, cell, struct, function-handle, and fi values.

    % Include class and dimensions so equal payloads with different types or
    % shapes have different representations.
    header = [uint8(class(value)).'; ...
        typecast(uint64([ndims(value), size(value)]), 'uint8').'];

    % Represent sparse arrays by their indices and nonzero values.
    if issparse(value)
        [sparseValue.Index1, sparseValue.Index2, sparseValue.Value] = ...
            find(value);
        data = [header; serializeObject(sparseValue)];
        return;
    end

    if isstruct(value)
        % Ignore field declaration order and preserve the legacy field-major
        % traversal of struct arrays.
        fieldNames = sort(fieldnames(value));
        parts = cell(1 + numel(fieldNames) * (numel(value) + 1), 1);
        parts{1} = header;
        partIndex = 2;
        for fieldIndex = 1:numel(fieldNames)
            fieldName = fieldNames{fieldIndex};
            parts{partIndex} = uint8(fieldName(:));
            partIndex = partIndex + 1;
            for valueIndex = 1:numel(value)
                parts{partIndex} = serializeObject(value(valueIndex).(fieldName));
                partIndex = partIndex + 1;
            end
        end
        data = vertcat(parts{:});
        return;
    end

    if iscell(value)
        parts = cell(numel(value) + 1, 1);
        parts{1} = header;
        for valueIndex = 1:numel(value)
            parts{valueIndex + 1} = serializeObject(value{valueIndex});
        end
        data = vertcat(parts{:});
        return;
    end

    if isa(value, 'embedded.fi')
        data = [header; serializeFixedPoint(value)];
    elseif isempty(value)
        data = header;
    elseif isnumeric(value)
        if isreal(value)
            payload = typecast(value(:), 'uint8');
        else
            % Store all real-component bytes before all imaginary bytes.
            payload = [typecast(real(value(:)), 'uint8'); ...
                typecast(imag(value(:)), 'uint8')];
        end
        data = [header; payload(:)];
    elseif islogical(value)
        % TYPECAST does not accept logical values.
        data = [header; uint8(value(:))];
    elseif ischar(value)
        % TYPECAST does not accept character arrays.
        payload = typecast(uint16(value(:)), 'uint8');
        data = [header; payload(:)];
    elseif isstring(value)
        % Preserve the legacy representation of each string as uint16 data.
        parts = cell(numel(value) + 1, 1);
        parts{1} = header;
        for valueIndex = 1:numel(value)
            parts{valueIndex + 1} = serializeObject(uint16(value{valueIndex}));
        end
        data = vertcat(parts{:});
    elseif isa(value, 'function_handle')
        data = [header; serializeObject(functionHandleKey(value))];
    elseif isobject(value) && ismethod(class(value), 'hashCode')
        data = [header; serializeObject(char(value.hashCode))];
    else
        try
            data = [header; serializeObject(convertObject(value))];
        catch exception
            if strcmp(exception.identifier, 'MATLAB:recursionLimit')
                error('DataHash:RecursiveType', ...
                    "Cannot serialize recursive value of class '%s'.", ...
                    class(value));
            end
            rethrow(exception);
        end
    end
end

function data = serializeFixedPoint(value)
% Serialize fixed-point arrays by type, local fimath, and stored bits.

    hasLocalFimath = isfimathlocal(value);
    if hasLocalFimath
        fimathText = tostring(fimath(value));
    else
        fimathText = '';
    end

    configuration = serializeObject({tostring(numerictype(value)), ...
        hasLocalFimath, fimathText});
    if isreal(value)
        parts = cell(2, 1);
        parts{2} = serializeFixedPointValue(value);
    else
        parts = cell(3, 1);
        parts{2} = serializeFixedPointValue(real(value));
        parts{3} = serializeFixedPointValue(imag(value));
    end
    parts{1} = configuration;
    data = vertcat(parts{:});
end

function data = serializeFixedPointValue(value)
    if value.WordLength <= 64
        data = serializeObject(storedInteger(value));
    else
        % STOREDINTEGER does not support word lengths above 64 bits. HEX
        % provides a compact documented representation of the stored bits.
        payload = hex(value(:)).';
        data = uint8(payload(:));
    end
end

function key = functionHandleKey(value)
% Convert a function handle to metadata returned by FUNCTIONS. This metadata
% and toolbox paths can change between MATLAB releases, so the resulting
% serialization is not guaranteed to be release-independent.

    key = functions(value);
    if isempty(key.file)
        return;
    end

    % Include the modification time and size of file-backed functions.
    fileInfo = dir(key.file);
    if ~isempty(fileInfo)
        key.filebytes = fileInfo.bytes;
        key.filedate = fileInfo.datenum;
    end
end

function converted = convertObject(value)
% User-defined objects have no unique byte representation. Prefer an explicit
% uint8 conversion supplied by the class and otherwise use its public state.

    try
        converted = uint8(value);
    catch
        warningState = warning('off', 'MATLAB:structOnObject');
        warningGuard = onCleanup(@() warning(warningState));
        try
            converted = struct(value);
        catch exception
            error('DataHash:UnsupportedType', ...
                "Cannot serialize value of class '%s': %s", ...
                class(value), exception.message);
        end
    end
end
