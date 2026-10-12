classdef DataHashLegacyCompatibilityTest < matlab.unittest.TestCase
    % Frozen compatibility checks for DataHash v1.8.0.
    % Preserve these historical cases; add new coverage to DataHashTest.
    % See README.md in this folder for suite coverage and reference versions.
    % Copyright (c) 2009-2019, Jan Simon.
    % Modifications copyright (c) 2026, Stefano Pradella. See ../license.txt.

    properties (TestParameter)
        knownAnswerCase = knownAnswerCases()
        fileCase = fileCases()
        fixedPointCase = fixedPointCases()
        randomInput = randomInputs(false)
        evenRandomInput = randomInputs(true)
    end

    methods (TestClassSetup)
        function addSourceFolder(testCase)
            repositoryFolder = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repositoryFolder, 'src'), 'IncludingSubfolders', true));
        end
    end

    methods (Test)
        function knownAnswer(testCase, knownAnswerCase)
            actual = DataHash(knownAnswerCase.data, ...
                knownAnswerCase.options{:});
            testCase.verifyEqual(actual, knownAnswerCase.expected);
        end

        function fileHash(testCase, fileCase)
            fileName = testCase.writeTemporaryFile(fileCase.data);
            actual = DataHash(fileName, 'MD5', 'File');
            memoryHash = DataHash(fileCase.data, 'MD5', fileCase.memoryInput);

            testCase.verifyEqual(actual, fileCase.expected);
            testCase.verifyEqual(memoryHash, fileCase.expected);
            testCase.verifyEqual(actual, memoryHash);
        end

        function outputTypes(testCase, randomInput)
            lowHex = DataHash(randomInput, 'MD5', 'bin', 'hex');
            upHex = DataHash(randomInput, 'MD5', 'bin', 'HEX');
            doubleBytes = DataHash(randomInput, 'MD5', 'bin', 'Double');
            base64 = DataHash(randomInput, 'MD5', 'bin', 'Base64');
            short = DataHash(randomInput, 'MD5', 'bin', 'short');
            uint8Bytes = DataHash(randomInput, 'MD5', 'bin', 'Uint8');
            expectedBase64 = encodeBase64Reference(uint8(doubleBytes));

            testCase.verifyEqual(lowHex, lower(upHex));
            testCase.verifyEqual(lowHex, lower(lowHex));
            testCase.verifyEqual(upHex, upper(upHex));
            testCase.verifyEqual(sscanf(lowHex, '%2x'), doubleBytes(:));
            testCase.verifyEqual(uint8Bytes, uint8(doubleBytes));
            testCase.verifyEqual(base64, expectedBase64);
            testCase.verifyEqual(short, strrep(expectedBase64, '=', ''));
            testCase.verifyClass(doubleBytes, 'double');
            testCase.verifyClass(uint8Bytes, 'uint8');
            testCase.verifyClass(lowHex, 'char');
            testCase.verifyClass(upHex, 'char');
            testCase.verifyClass(base64, 'char');
            testCase.verifyClass(short, 'char');
            testCase.verifySize(doubleBytes, [1, 16]);
            testCase.verifySize(uint8Bytes, [1, 16]);
            testCase.verifySize(lowHex, [1, 32]);
            testCase.verifySize(upHex, [1, 32]);
            testCase.verifySize(base64, [1, 24]);
            testCase.verifySize(short, [1, 22]);
        end

        function charBinaryCompatibility(testCase, evenRandomInput)
            charData = char(uint16(evenRandomInput(1:2:end)) + ...
                bitshift(uint16(evenRandomInput(2:2:end)), 8));
            expected = DataHash(evenRandomInput, 'MD5', 'bin', 'double');
            actual = DataHash(charData, 'MD5', 'binary', 'double');

            testCase.verifyEqual(actual, expected);
        end

        function fixedPointKnownAnswer(testCase, fixedPointCase)
            testCase.assumeTrue(hasFixedPointDesigner(), ...
                'Fixed-Point Designer must be installed and licensed.');
            data = fixedPointCase.createData();
            actual = DataHash(data, 'MD5', fixedPointCase.inputType);

            testCase.verifyEqual(actual, fixedPointCase.expected);
        end

        function fixedPointStoredIntegerBinary(testCase)
            testCase.assumeTrue(hasFixedPointDesigner(), ...
                'Fixed-Point Designer must be installed and licensed.');
            data = fi([1.5, -2], 1, 16, 12);
            actual = DataHash(data, 'MD5', 'bin');
            payloadHash = DataHash(storedInteger(data), 'MD5', 'bin');

            testCase.verifyEqual(actual, '6df751e7d678185345abfcb4ec152e96');
            testCase.verifyEqual(actual, payloadHash);
        end

        function wideFixedPointHexBinary(testCase)
            testCase.assumeTrue(hasFixedPointDesigner(), ...
                'Fixed-Point Designer must be installed and licensed.');
            data = fi(1, 1, 65, 0);
            payload = uint8(reshape(hex(data(:)).', 1, []));
            actual = DataHash(data, 'MD5', 'bin');
            payloadHash = DataHash(payload, 'MD5', 'bin');

            testCase.verifyEqual(actual, '23d6c62be6c5a327666e97b286c8a99a');
            testCase.verifyEqual(actual, payloadHash);
        end

        function emptyFixedPointTypes(testCase)
            testCase.assumeTrue(hasFixedPointDesigner(), ...
                'Fixed-Point Designer must be installed and licensed.');
            eightBitHash = DataHash(fi([], 1, 8, 3), 'MD5', 'Array');
            sixteenBitHash = DataHash(fi([], 1, 16, 12), 'MD5', 'Array');

            testCase.verifyEqual(eightBitHash, 'bcfb3334f76d5720b6d584fe2e647acd');
            testCase.verifyEqual(sixteenBitHash, 'c0255d257f60f67cf02277fc68257ae1');
            testCase.verifyNotEqual(eightBitHash, sixteenBitHash);
        end
    end

    methods (Access = private)
        function fileName = writeTemporaryFile(testCase, data)
            folder = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            fileName = fullfile(folder.Folder, 'input.bin');
            [fileId, message] = fopen(fileName, 'wb');
            testCase.assertNotEqual(fileId, -1, message);
            fileGuard = onCleanup(@() fclose(fileId));
            count = fwrite(fileId, data, 'uint8');
            testCase.assertEqual(count, numel(data));
            clear fileGuard;
        end
    end
end

function namedCases = knownAnswerCases()
% Known answers for numeric, char, string, cell, struct, and sparse inputs.

    nested.a = uint8([]);
    nested.b = {{1:10}, struct('q', uint64(415))};
    recursive = struct('Field1', 'string', ...
        'Field2', {{'Cell string', '2nd string'}});
    recursive.Field3 = recursive;

    cases = { ...
        'emptyDoubleDefault', [], {}, '5b302b7b2099a97ba2a276640a192485'; ...
        'int32ShortMd5', int32(1:10), {'MD5', 'array', 'short'}, ...
            '+tJN9yeF89h3jOFNN55XLg'; ...
        'nestedStructSha1UpperHex', nested, {'SHA-1', 'array', 'HEX'}, ...
            '18672BE876463B25214CA9241B3C79CC926F3093'; ...
        'binarySha1', 1:8, {'SHA-1', 'bin'}, ...
            '826cf9d3a5d74bbe415e97d4cecf03f445f69225'; ...
        'charAbcSha256Ascii', 'abc', {'SHA-256', 'ascii'}, ...
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'; ...
        'uint8AbcSha256Binary', uint8('abc'), {'SHA-256', 'bin'}, ...
            'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'; ...
        'messageDigestMd5Ascii', 'message digest', {'MD5', 'ascii'}, ...
            'f96b697d7cb7938d525a2f31aaf161d0'; ...
        'allCharCodesMd5Ascii', char(0:255), {'MD5', 'ascii'}, ...
            'e2c865db4162bed963bfaa9ef6ac18f0'; ...
        'allCharCodesMd5Array', char(0:255), {'MD5', 'Array'}, ...
            '1e4558b49c05611cdb280a79cb2dbe34'; ...
        'sha256Base64', 1:33, {'SHA-256', 'array', 'base64'}, ...
            'SuuPZKpce2KetxeIClt1EXz/mCztEuYiawG9vaxKcfc='; ...
        'sha512Base64', 1:33, {'SHA-512', 'array', 'base64'}, ...
            ['V9Yp/ZBUbfmzQZ7WRzRvqNYLbb6Kzgrc3iaqPH7ta8MS/bMPKc7j', ...
             '+FRV5Oexu3OCOQ1+2p/E+ZcgKyRHheq0kQ==']; ...
        'md5Short', 1:33, {'MD5', 'array', 'short'}, ...
            'RoNguVVzgq6s7ll9xoCSSg'; ...
        'sha512Short', 1:33, {'SHA-512', 'array', 'short'}, ...
            ['V9Yp/ZBUbfmzQZ7WRzRvqNYLbb6Kzgrc3iaqPH7ta8MS/bMPKc7j', ...
             '+FRV5Oexu3OCOQ1+2p/E+ZcgKyRHheq0kQ']; ...
        'emptyStringArray', "", {'MD5', 'Array'}, ...
            '061bdd545213c6a236e0f3d655e38ff4'; ...
        'helloStringArray', "hello", {'MD5', 'Array'}, ...
            '2614526bcbd4af5a8e7bf79d1d0d92ab'; ...
        'stringRowArray', ["hello", "world"], {'MD5', 'Array'}, ...
            'a1bdbbe9a15c249764847ead9bf47326'; ...
        'stringColumnArray', ["hello"; ""; "world"], {'MD5', 'Array'}, ...
            'a6df2dc811d4e8dab214c01ce0dfc4b9'; ...
        'emptyStringAscii', "", {'MD5', 'ascii'}, ...
            'd41d8cd98f00b204e9800998ecf8427e'; ...
        'helloStringAscii', "hello", {'MD5', 'ascii'}, ...
            '5d41402abc4b2a76b9719d911017c592'; ...
        'emptyUint8Array', uint8([]), {'MD5', 'Array'}, ...
            'cb8a2273d1168a72b70833bb0d79be13'; ...
        'emptyInt8Array', int8([]), {'MD5', 'Array'}, ...
            '0160dd4473fe1a952572be239e077ed3'; ...
        'recursiveStructArray', recursive, {'MD5', 'Array'}, ...
            '4fe320b06e3aaaf4ba712980d649e274'; ...
        'sparseArray', sparse([1, 0, 2; 0, 3, 0; 4, 0, 0]), ...
            {'MD5', 'Array'}, 'f157bdc9173dff169c782dd639984c82'; ...
        'uninitializedCellArray', cell(1, 2), {'MD5', 'Array'}, ...
            '161842037bc65b9f3bceffdeb4a8d3bd'; ...
    };

    namedCases = nameCases(cases, {'data', 'options', 'expected'});
end

function namedCases = fileCases()
% Known-answer file contents with their ASCII or binary memory input mode.

    cases = { ...
        'emptyFile', '', 'ascii', 'd41d8cd98f00b204e9800998ecf8427e'; ...
        'lowercaseAlphabet', 'abcdefghijklmnopqrstuvwxyz', 'ascii', ...
            'c3fcd3d76192e4007dfb496cca67e13b'; ...
        'alphanumeric', ...
            'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', ...
            'ascii', 'd174ab98d277d9f5a5611c2c9f419d9f'; ...
        'eightyDigits', ...
            ['123456789012345678901234567890123456789012345678901234567890123456', ...
             '78901234567890'], 'ascii', '57edf4a22be3c955ac49da2e2107b67a'; ...
        'allByteValues', uint8(0:255), 'bin', ...
            'e2c865db4162bed963bfaa9ef6ac18f0'; ...
    };

    namedCases = nameCases(cases, {'data', 'memoryInput', 'expected'});
end

function namedCases = fixedPointCases()
% Defer FI construction so missing licenses produce explicit skipped tests.

    cases = { ...
        'fixedPointArray', @() fi([1.5, -2], 1, 16, 12), 'Array', ...
            'c90c55f07c2d42fe0817e36171660da9'; ...
        'fixedPointBinary', @() fi([1.5, -2], 1, 16, 12), 'bin', ...
            '6df751e7d678185345abfcb4ec152e96'; ...
        'fixedPointNumerictype', @() fi(1.5, 1, 16, 10), 'Array', ...
            '46f358631ae55d8ba810701b54613d95'; ...
        'fixedPointFimath', @() fi(1.5, 1, 16, 12, ...
            'RoundingMethod', 'Floor', 'OverflowAction', 'Wrap'), 'Array', ...
            '37747e91f02c884f77c6d010596e3295'; ...
        'complexFixedPoint', @() complex(fi(1, 1, 8, 4), fi(2, 1, 8, 4)), ...
            'Array', '34ba124f88c626cef7b9821aaceb2f75'; ...
        'wideFixedPointArray', @() fi(1, 1, 65, 0), 'Array', ...
            'f18e644a6e75e5acd61c3031439aaf7d'; ...
        'wideFixedPointBinary', @() fi(1, 1, 65, 0), 'bin', ...
            '23d6c62be6c5a327666e97b286c8a99a'; ...
        'emptyEightBitFixedPoint', @() fi([], 1, 8, 3), 'Array', ...
            'bcfb3334f76d5720b6d584fe2e647acd'; ...
        'emptySixteenBitFixedPoint', @() fi([], 1, 16, 12), 'Array', ...
            'c0255d257f60f67cf02277fc68257ae1'; ...
    };

    namedCases = nameCases(cases, {'createData', 'inputType', 'expected'});
end

function namedInputs = randomInputs(evenOnly)
% Generate 1,000 seeded byte arrays without changing the global RNG state.
% The even-length cases are the exact subset used for binary CHAR comparisons.

    stream = RandStream('mt19937ar', 'Seed', 0);
    caseCount = 1000;
    caseNames = cell(1, caseCount);
    inputs = cell(1, caseCount);
    isEven = false(1, caseCount);
    for caseIndex = 1:caseCount
        dataLength = 1 + fix(rand(stream) * 100);
        inputs{caseIndex} = uint8(fix(rand(stream, 1, dataLength) * 256));
        caseNames{caseIndex} = sprintf('seed0Case%04d', caseIndex);
        isEven(caseIndex) = rem(dataLength, 2) == 0;
    end

    if evenOnly
        inputs = inputs(isEven);
        caseNames = caseNames(isEven);
    end
    namedInputs = cell2struct(inputs, caseNames, 2);
end

function encoded = encodeBase64Reference(bytes)
% Independent test oracle: map three bytes to four six-bit alphabet indices.
% Do not call the production encoder or a Java encoder from this helper.

    alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    padCount = mod(-numel(bytes), 3);
    groups = reshape([bytes(:); zeros(padCount, 1, 'uint8')], 3, []);
    indices = zeros(4, size(groups, 2), 'uint8');
    indices(1, :) = bitshift(groups(1, :), -2);
    indices(2, :) = bitor(bitshift(bitand(groups(1, :), uint8(3)), 4), ...
        bitshift(groups(2, :), -4));
    indices(3, :) = bitor(bitshift(bitand(groups(2, :), uint8(15)), 2), ...
        bitshift(groups(3, :), -6));
    indices(4, :) = bitand(groups(3, :), uint8(63));
    encoded = reshape(alphabet(double(indices(:)) + 1), 1, []);
    if padCount > 0
        encoded(end - padCount + 1:end) = '=';
    end
end

function namedCases = nameCases(cases, fieldNames)
    values = cell(size(cases, 1), 1);
    for caseIndex = 1:size(cases, 1)
        values{caseIndex} = cell2struct(cases(caseIndex, 2:end), fieldNames, 2);
    end
    namedCases = cell2struct(values, cases(:, 1), 1);
end

function available = hasFixedPointDesigner()
    available = exist('fi', 'file') == 2;
    if available
        try
            fi(0, 1, 8, 0);
        catch
            available = false;
        end
    end
end
